import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import '../debug/agent_log.dart';
import '../domain/isolate_message.dart';
import 'tokenizer.dart';

/// Web-safe ML worker: no dart:io, no FFI/onnxruntime, no background isolates.
/// Uses mock embeddings so the UI and generative routing remain functional.
class MlIsolateWorker {
  StreamController<IsolateResponse>? _responseController;
  WordPieceTokenizer? _tokenizer;
  bool _isInitializing = false;
  bool _isReady = false;
  bool _isStopped = false;

  Stream<IsolateResponse> get responseStream => _responseController!.stream;

  bool get isReady => _isReady;

  Future<void> start() async {
    if (_isInitializing || _isReady || _isStopped) return;
    _isInitializing = true;
    _responseController = StreamController<IsolateResponse>.broadcast();

    // #region agent log
    agentLog(
      location: 'ml_isolate_worker_web.dart:start',
      message: 'Web worker starting',
      hypothesisId: 'A',
      data: const {'platform': 'web'},
    );
    // #endregion
  }

  void initializeModel(String modelPath, String vocabPath) {
    if (_responseController == null || _isStopped) {
      throw StateError('Worker is not started.');
    }

    unawaited(_initialize(modelPath, vocabPath));
  }

  Future<void> _initialize(String modelPath, String vocabPath) async {
    _emit(
      const IsolateStatusUpdate(
        state: WorkerState.initializing,
        message: 'Initializing web fallback worker...',
      ),
    );

    try {
      if (vocabPath.isNotEmpty) {
        _tokenizer = WordPieceTokenizer.fallback();
      } else {
        try {
          final vocabText = await rootBundle.loadString('assets/vocab.txt');
          _tokenizer = WordPieceTokenizer.fromString(vocabText);
        } catch (_) {
          _tokenizer = WordPieceTokenizer.fallback();
        }
      }

      _isReady = true;
      _isInitializing = false;

      // #region agent log
      agentLog(
        location: 'ml_isolate_worker_web.dart:_initialize',
        message: 'Web worker ready',
        hypothesisId: 'A',
        data: {
          'modelPathEmpty': modelPath.isEmpty,
          'vocabPathEmpty': vocabPath.isEmpty,
        },
      );
      // #endregion

      _emit(
        const IsolateStatusUpdate(
          state: WorkerState.ready,
          message: 'Ready (Web Fallback: Mock Embeddings)',
        ),
      );
    } catch (e) {
      _isReady = false;
      _isInitializing = false;
      _emit(IsolateErrorResponse(message: 'Web worker init failed: $e'));
      _emit(const IsolateStatusUpdate(state: WorkerState.error));
    }
  }

  void runInference(String text) {
    if (!_isReady || _isStopped) {
      throw StateError('Worker is not ready for inference.');
    }
    unawaited(_runInference(text));
  }

  void embedIntent(String text, {required int requestId}) {
    if (!_isReady || _isStopped) {
      throw StateError('Worker is not ready for intent embedding.');
    }
    unawaited(_runIntentEmbed(text, requestId));
  }

  Future<void> stop() async {
    _isStopped = true;
    _isReady = false;
    _isInitializing = false;
    await _responseController?.close();
    _responseController = null;
  }

  Future<void> _runInference(String text) async {
    final startTime = DateTime.now();
    final tokenizer = _tokenizer;
    if (tokenizer == null) {
      _emit(
        IsolateErrorResponse(
          message: 'Tokenizer not initialized',
          originalText: text,
        ),
      );
      return;
    }

    try {
      final embedding = await _runEmbedding(
        text: text,
        tokenizer: tokenizer,
        emitPipelineStages: true,
      );
      final elapsedMs =
          DateTime.now().difference(startTime).inMicroseconds / 1000.0;

      _emit(
        IsolateInferenceSuccess(
          embedding: embedding,
          inferenceTimeMs: elapsedMs,
          text: text,
        ),
      );
    } catch (e) {
      _emit(
        IsolateErrorResponse(
          message: 'Inference error: $e',
          originalText: text,
        ),
      );
    }
  }

  Future<void> _runIntentEmbed(String text, int requestId) async {
    final tokenizer = _tokenizer;
    if (tokenizer == null) {
      _emit(
        IsolateErrorResponse(
          message: 'Tokenizer not initialized',
          originalText: text,
        ),
      );
      return;
    }

    try {
      final embedding = await _runEmbedding(
        text: text,
        tokenizer: tokenizer,
        emitPipelineStages: false,
      );
      _emit(
        IsolateIntentEmbedSuccess(
          requestId: requestId,
          embedding: embedding,
          text: text,
        ),
      );
    } catch (e) {
      _emit(
        IsolateErrorResponse(
          message: 'Intent embed error: $e',
          originalText: text,
        ),
      );
    }
  }

  Future<List<double>> _runEmbedding({
    required String text,
    required WordPieceTokenizer tokenizer,
    required bool emitPipelineStages,
  }) async {
    final tokenStrings = tokenizer.tokenizeToStrings(text);
    final inputIds = tokenizer.encode(text);
    final inputLength = inputIds.where((id) => id != tokenizer.padId).length;

    if (emitPipelineStages) {
      _emit(
        IsolatePipelineStage(
          stage: PipelineStage.tokenize,
          detail: '${tokenStrings.length} tokens',
          tokens: tokenStrings,
          seqLen: inputLength,
        ),
      );
      _emit(
        IsolatePipelineStage(
          stage: PipelineStage.tensor,
          detail: '[1, $inputLength]',
          seqLen: inputLength,
        ),
      );
      _emit(
        const IsolatePipelineStage(
          stage: PipelineStage.infer,
          detail: 'Mock forward pass (web)',
        ),
      );
    }

    final embedding = _generateMockEmbedding(text);
    await Future<void>.delayed(const Duration(milliseconds: 45));

    if (emitPipelineStages) {
      _emit(
        IsolatePipelineStage(
          stage: PipelineStage.pool,
          detail: 'Mean pool → ${embedding.length}d',
          seqLen: embedding.length,
        ),
      );
      _emit(
        IsolatePipelineStage(
          stage: PipelineStage.normalize,
          detail: 'L2 normalize',
          l2Norm: _l2Norm(embedding),
        ),
      );
    }

    return embedding;
  }

  void _emit(IsolateResponse response) {
    _responseController?.add(response);
  }

  static List<double> _generateMockEmbedding(String text) {
    const dim = 384;
    final rand = Random(text.hashCode);
    final raw = List<double>.generate(dim, (_) => rand.nextDouble() * 2 - 1);

    var sumSq = 0.0;
    for (final val in raw) {
      sumSq += val * val;
    }
    final norm = sqrt(sumSq);
    if (norm > 0.0) {
      for (var i = 0; i < dim; i++) {
        raw[i] /= norm;
      }
    }
    return raw;
  }

  static double _l2Norm(List<double> v) {
    var sumSq = 0.0;
    for (final val in v) {
      sumSq += val * val;
    }
    return sqrt(sumSq);
  }
}
