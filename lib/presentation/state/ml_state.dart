import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../../data/ml_isolate_worker.dart';
import '../../domain/inference_result.dart';
import '../../domain/isolate_message.dart';
import '../../domain/ui_schema.dart';

enum LaneEventType {
  commandSent,
  pipelineStage,
  inferenceStart,
  inferenceComplete,
}

class LaneEvent {
  final LaneEventType type;
  final String label;
  final double offsetMs;

  const LaneEvent({
    required this.type,
    required this.label,
    required this.offsetMs,
  });
}

class LaneTimeline {
  final List<LaneEvent> events;
  final double totalDurationMs;
  final int uiFramePulses;

  const LaneTimeline({
    this.events = const [],
    this.totalDurationMs = 1000,
    this.uiFramePulses = 0,
  });

  LaneTimeline copyWith({
    List<LaneEvent>? events,
    double? totalDurationMs,
    int? uiFramePulses,
  }) {
    return LaneTimeline(
      events: events ?? this.events,
      totalDurationMs: totalDurationMs ?? this.totalDurationMs,
      uiFramePulses: uiFramePulses ?? this.uiFramePulses,
    );
  }
}

class MlState extends ChangeNotifier {
  final MlIsolateWorker _worker = MlIsolateWorker();

  WorkerState _status = WorkerState.uninitialized;
  WorkerState get status => _status;

  String _statusMessage = 'Uninitialized';
  String get statusMessage => _statusMessage;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  final List<InferenceResult> _history = [];
  List<InferenceResult> get history => List.unmodifiable(_history);

  InferenceResult? _activeResult;
  InferenceResult? get activeResult => _activeResult;

  final Map<int, double> _similarities = {};
  Map<int, double> get similarities => Map.unmodifiable(_similarities);

  PipelineStage? _activePipelineStage;
  PipelineStage? get activePipelineStage => _activePipelineStage;

  String? _pipelineDetail;
  String? get pipelineDetail => _pipelineDetail;

  List<String>? _pipelineTokens;
  List<String>? get pipelineTokens => _pipelineTokens;

  double? _pipelineL2Norm;
  double? get pipelineL2Norm => _pipelineL2Norm;

  LaneTimeline _laneTimeline = const LaneTimeline();
  LaneTimeline get laneTimeline => _laneTimeline;

  UiLayoutSchema? _generativeSchema;
  UiLayoutSchema? get generativeSchema => _generativeSchema;

  DateTime? _inferenceStartTime;
  int _uiFramePulses = 0;
  TimingsCallback? _timingsCallback;

  Future<void> initialize() async {
    if (_status == WorkerState.initializing || _status == WorkerState.ready) {
      return;
    }

    _status = WorkerState.initializing;
    _statusMessage = 'Starting background isolate worker...';
    notifyListeners();

    try {
      await _worker.start();
      _worker.responseStream.listen(_handleIsolateResponse);

      final tempDir = await getTemporaryDirectory();
      final modelFile = File('${tempDir.path}/model.onnx');
      final vocabFile = File('${tempDir.path}/vocab.txt');

      try {
        final modelBytes =
            await rootBundle.load('assets/models/bge-small-en-v1.5/onnx/model.onnx');
        await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
      } catch (_) {}

      try {
        final vocabBytes = await rootBundle.load('assets/vocab.txt');
        await vocabFile.writeAsBytes(vocabBytes.buffer.asUint8List());
      } catch (_) {}

      _worker.initializeModel(modelFile.path, vocabFile.path);
      _attachFrameMonitor();
    } catch (e) {
      _status = WorkerState.error;
      _statusMessage = 'Initialization failed: $e';
      notifyListeners();
    }
  }

  void _attachFrameMonitor() {
    if (_timingsCallback != null) return;
    _timingsCallback = (_) {
      if (_isProcessing) {
        _uiFramePulses++;
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  Future<void> processText(String text) async {
    if (text.trim().isEmpty || _status != WorkerState.ready || _isProcessing) {
      return;
    }

    _isProcessing = true;
    _activePipelineStage = null;
    _pipelineDetail = null;
    _pipelineTokens = null;
    _pipelineL2Norm = null;
    _inferenceStartTime = DateTime.now();
    _uiFramePulses = 0;
    _laneTimeline = LaneTimeline(
      events: [
        LaneEvent(
          type: LaneEventType.commandSent,
          label: 'CMD',
          offsetMs: 0,
        ),
        LaneEvent(
          type: LaneEventType.inferenceStart,
          label: 'INFER',
          offsetMs: 2,
        ),
      ],
    );
    notifyListeners();

    try {
      _worker.runInference(text);
    } catch (e) {
      _isProcessing = false;
      _activeResult = InferenceResult.error(e.toString(), text);
      notifyListeners();
    }
  }

  void matchGenerativeIntent(String intent) {
    final sim = _activeResult != null && _history.length > 1
        ? _similarities.values.fold<double>(0, (a, b) => a > b ? a : b)
        : null;
    _generativeSchema = IntentMatcher.match(
      intent,
      similarity: sim,
      dim: _activeResult?.embedding.length,
    );
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _activeResult = null;
    _similarities.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
    }
    _worker.stop();
    super.dispose();
  }

  void _handleIsolateResponse(IsolateResponse response) {
    switch (response) {
      case IsolateStatusUpdate():
        _status = response.state;
        _statusMessage =
            response.message ?? _getStateDefaultMessage(response.state);
        notifyListeners();
      case IsolatePipelineStage():
        _activePipelineStage = response.stage;
        _pipelineDetail = response.detail;
        if (response.tokens != null) _pipelineTokens = response.tokens;
        if (response.l2Norm != null) _pipelineL2Norm = response.l2Norm;

        final offset = _inferenceStartTime == null
            ? 0.0
            : DateTime.now()
                .difference(_inferenceStartTime!)
                .inMicroseconds /
                1000.0;
        final events = List<LaneEvent>.from(_laneTimeline.events)
          ..add(
            LaneEvent(
              type: LaneEventType.pipelineStage,
              label: response.stage.name.toUpperCase(),
              offsetMs: offset,
            ),
          );
        _laneTimeline = _laneTimeline.copyWith(events: events);
        notifyListeners();
      case IsolateInferenceSuccess():
        _isProcessing = false;
        _activePipelineStage = null;

        final result = InferenceResult(
          embedding: response.embedding,
          inferenceTimeMs: response.inferenceTimeMs,
          text: response.text,
        );

        _activeResult = result;
        _history.insert(0, result);
        _recalculateSimilarities(result);

        final elapsed = _inferenceStartTime == null
            ? response.inferenceTimeMs
            : DateTime.now()
                .difference(_inferenceStartTime!)
                .inMicroseconds /
                1000.0;
        final events = List<LaneEvent>.from(_laneTimeline.events)
          ..add(
            LaneEvent(
              type: LaneEventType.inferenceComplete,
              label: 'OK',
              offsetMs: elapsed,
            ),
          );
        _laneTimeline = LaneTimeline(
          events: events,
          totalDurationMs: max(elapsed * 1.2, 200),
          uiFramePulses: _uiFramePulses,
        );
        notifyListeners();
      case IsolateErrorResponse():
        _isProcessing = false;
        _activePipelineStage = null;
        _activeResult =
            InferenceResult.error(response.message, response.originalText ?? '');
        notifyListeners();
    }
  }

  String _getStateDefaultMessage(WorkerState state) {
    return switch (state) {
      WorkerState.uninitialized => 'Uninitialized',
      WorkerState.initializing => 'Initializing model environment...',
      WorkerState.ready => 'Ready for inference',
      WorkerState.error => 'Worker encountered an error',
    };
  }

  void _recalculateSimilarities(InferenceResult active) {
    _similarities.clear();
    if (active.embedding.isEmpty) return;

    for (final item in _history) {
      if (item.embedding.isEmpty) continue;

      var dot = 0.0;
      final len = active.embedding.length < item.embedding.length
          ? active.embedding.length
          : item.embedding.length;
      for (var d = 0; d < len; d++) {
        dot += active.embedding[d] * item.embedding[d];
      }
      _similarities[identityHashCode(item)] = dot;
    }
  }
}