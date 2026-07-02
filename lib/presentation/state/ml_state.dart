import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../../data/embedding_intent_router.dart';
import '../../data/ml_isolate_worker.dart';
import '../../domain/generative_context.dart';
import '../../domain/inference_result.dart';
import '../../domain/isolate_message.dart';
import '../../domain/ui_schema.dart';
import '../generative/schema_stream_controller.dart';

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
  late final EmbeddingIntentRouter _intentRouter = EmbeddingIntentRouter(
    worker: _worker,
  );
  final SchemaStreamController schemaStream = SchemaStreamController();
  bool _isDisposed = false;

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

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
  UiLayoutSchema? get generativeSchema =>
      schemaStream.partialSchema ?? _generativeSchema;

  List<String> _schemaValidationErrors = [];
  List<String> get schemaValidationErrors =>
      List.unmodifiable(_schemaValidationErrors);

  List<RouterSuggestion> _routerSuggestions = [];
  List<RouterSuggestion> get routerSuggestions =>
      List.unmodifiable(_routerSuggestions);

  RouterSuggestion? _suggestedLayout;
  RouterSuggestion? get suggestedLayout => _suggestedLayout;

  bool _autoHydrate = false;
  bool get autoHydrate => _autoHydrate;

  String? _lastIntentText;
  String? get lastIntentText => _lastIntentText;

  List<RouterSuggestion> _intentPreview = [];
  List<RouterSuggestion> get intentPreview => List.unmodifiable(_intentPreview);

  bool _isRoutingIntent = false;
  bool get isRoutingIntent => _isRoutingIntent;

  Timer? _intentPreviewDebounce;

  DateTime? _inferenceStartTime;
  int _uiFramePulses = 0;
  TimingsCallback? _timingsCallback;

  GenerativeContext buildGenerativeContext({
    void Function(InferenceResult)? onSelectResult,
  }) {
    return GenerativeContext(
      activeResult: _activeResult,
      history: history,
      similarities: similarities,
      inferenceTimeMs: _activeResult?.inferenceTimeMs,
      pipelineStage: _activePipelineStage,
      pipelineDetail: _pipelineDetail,
      pipelineTokens: _pipelineTokens,
      pipelineL2Norm: _pipelineL2Norm,
      isProcessing: _isProcessing,
      onSelectResult: onSelectResult ?? selectActiveResult,
    );
  }

  void setAutoHydrate(bool value) {
    _autoHydrate = value;
    notifyListeners();
  }

  void dismissSuggestedLayout() {
    _suggestedLayout = null;
    notifyListeners();
  }

  void applySuggestedLayout() {
    final suggestion = _suggestedLayout;
    if (suggestion == null || _lastIntentText == null) return;
    matchGenerativeIntent(_lastIntentText!);
    _suggestedLayout = null;
  }

  void rehydratePreviousSchema([int indexFromEnd = 1]) {
    schemaStream.rehydratePrevious(indexFromEnd);
    _generativeSchema = schemaStream.fullSchema;
    _schemaValidationErrors =
        _generativeSchema?.validate(context: buildGenerativeContext()) ?? [];
    notifyListeners();
  }

  void previewIntent(String intent) {
    _intentPreviewDebounce?.cancel();
    if (intent.trim().isEmpty) {
      _intentPreview = [];
      notifyListeners();
      return;
    }

    _intentPreviewDebounce = Timer(const Duration(milliseconds: 400), () async {
      _isRoutingIntent = true;
      notifyListeners();
      try {
        _intentPreview = await _intentRouter.rankIntent(intent);
      } finally {
        _isRoutingIntent = false;
        notifyListeners();
      }
    });
  }

  Future<void> initialize() async {
    if (_isDisposed ||
        _status == WorkerState.initializing ||
        _status == WorkerState.ready) {
      return;
    }

    schemaStream.addListener(notifyListeners);

    _status = WorkerState.initializing;
    _statusMessage = 'Starting background isolate worker...';
    _safeNotify();

    try {
      await _worker.start();
      if (_isDisposed) return;
      _intentRouter.attachToResponseStream(_worker.responseStream);
      _worker.responseStream.listen(_handleIsolateResponse);

      final tempDir = await getTemporaryDirectory();
      if (_isDisposed) return;
      final modelFile = File('${tempDir.path}/model.onnx');
      final vocabFile = File('${tempDir.path}/vocab.txt');

      try {
        final modelBytes = await rootBundle.load(
          'assets/models/bge-small-en-v1.5/onnx/model.onnx',
        );
        await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
      } catch (_) {}

      try {
        final vocabBytes = await rootBundle.load('assets/vocab.txt');
        await vocabFile.writeAsBytes(vocabBytes.buffer.asUint8List());
      } catch (_) {}

      _worker.initializeModel(modelFile.path, vocabFile.path);
      _attachFrameMonitor();
    } catch (e) {
      if (_isDisposed) return;
      _status = WorkerState.error;
      _statusMessage = 'Initialization failed: $e';
      _safeNotify();
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

  Future<void> processText(String text, {String? layoutIntent}) async {
    if (text.trim().isEmpty || _status != WorkerState.ready || _isProcessing) {
      return;
    }

    if (layoutIntent != null && layoutIntent.trim().isNotEmpty) {
      _lastIntentText = layoutIntent.trim();
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
        LaneEvent(type: LaneEventType.commandSent, label: 'CMD', offsetMs: 0),
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

  Future<void> matchGenerativeIntent(String intent) async {
    _lastIntentText = intent;
    _isRoutingIntent = true;
    notifyListeners();

    UiLayoutSchema? schema;
    try {
      schema = await _intentRouter.route(intent, historyCount: _history.length);
      schema ??= IntentMatcher.match(
        intent,
        similarity: bestNonSelfSimilarity,
        dim: _activeResult?.embedding.length,
        inferenceTimeMs: _activeResult?.inferenceTimeMs,
        l2Norm: buildGenerativeContext().activeL2Norm,
      );

      _routerSuggestions = await _intentRouter.rankIntent(intent);
    } finally {
      _isRoutingIntent = false;
    }

    if (schema != null) {
      final ctx = buildGenerativeContext();
      _schemaValidationErrors = schema.validate(context: ctx);
      _generativeSchema = schema;
      schemaStream.beginStream(schema);
      unawaited(schemaStream.streamComponents());
    } else {
      _generativeSchema = null;
      _schemaValidationErrors = [];
      schemaStream.reset();
    }

    notifyListeners();
  }

  double? get bestNonSelfSimilarity =>
      buildGenerativeContext().bestNonSelfSimilarity;

  void clearHistory() {
    _history.clear();
    _activeResult = null;
    _similarities.clear();
    _suggestedLayout = null;
    notifyListeners();
  }

  void selectActiveResult(InferenceResult result) {
    final match = _history.cast<InferenceResult?>().firstWhere(
      (item) => identical(item, result),
      orElse: () => null,
    );
    if (match == null || match.embedding.isEmpty) return;
    _activeResult = match;
    _recalculateSimilarities(match);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _intentPreviewDebounce?.cancel();
    schemaStream.removeListener(notifyListeners);
    _intentRouter.dispose();
    schemaStream.dispose();
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
        if (response.state == WorkerState.ready) {
          unawaited(_intentRouter.initializeTemplates());
        }
        notifyListeners();
      case IsolatePipelineStage():
        _activePipelineStage = response.stage;
        _pipelineDetail = response.detail;
        if (response.tokens != null) _pipelineTokens = response.tokens;
        if (response.l2Norm != null) _pipelineL2Norm = response.l2Norm;

        final offset = _inferenceStartTime == null
            ? 0.0
            : DateTime.now().difference(_inferenceStartTime!).inMicroseconds /
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
            : DateTime.now().difference(_inferenceStartTime!).inMicroseconds /
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

        unawaited(_onInferenceComplete());
        notifyListeners();
      case IsolateErrorResponse():
        _isProcessing = false;
        _activePipelineStage = null;
        _activeResult = InferenceResult.error(
          response.message,
          response.originalText ?? '',
        );
        notifyListeners();
      case IsolateIntentEmbedSuccess():
        break;
    }
  }

  Future<void> _onInferenceComplete() async {
    if (_lastIntentText != null && _lastIntentText!.trim().isNotEmpty) {
      final suggestions = await _intentRouter.rankIntent(_lastIntentText!);
      if (suggestions.isNotEmpty) {
        _suggestedLayout = suggestions.first;
      }
    } else {
      final defaultIntent = _history.length >= 2
          ? 'compare similarity'
          : 'vector detail';
      final suggestions = await _intentRouter.rankIntent(defaultIntent);
      if (suggestions.isNotEmpty) {
        _suggestedLayout = suggestions.first;
        _routerSuggestions = suggestions;
      }
    }

    if (_autoHydrate && _suggestedLayout != null) {
      final intent =
          _lastIntentText ??
          (_history.length >= 2 ? 'compare similarity' : 'vector detail');
      await matchGenerativeIntent(intent);
      _suggestedLayout = null;
    }

    notifyListeners();
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
