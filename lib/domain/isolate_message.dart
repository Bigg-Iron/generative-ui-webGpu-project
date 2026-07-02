import 'dart:isolate';

/// Base class for all commands sent from the Main UI thread to the Isolate.
sealed class IsolateCommand {
  const IsolateCommand();
}

/// Commands the Isolate to load the ONNX model and tokenizer vocabulary.
class InitCommand extends IsolateCommand {
  final SendPort replyTo;
  final String modelPath;
  final String vocabPath;

  const InitCommand({
    required this.replyTo,
    required this.modelPath,
    required this.vocabPath,
  });
}

/// Commands the Isolate to perform text embedding inference on the input string.
class InferenceCommand extends IsolateCommand {
  final String text;

  const InferenceCommand({required this.text});
}

/// Lightweight intent embedding for generative routing (no pipeline stages).
class IntentEmbedCommand extends IsolateCommand {
  final String text;
  final int requestId;

  const IntentEmbedCommand({required this.text, required this.requestId});
}

/// Commands the Isolate to close sessions and release memory.
class ShutdownCommand extends IsolateCommand {
  const ShutdownCommand();
}

/// Base class for all responses sent from the Isolate back to the Main UI thread.
sealed class IsolateResponse {
  const IsolateResponse();
}

enum WorkerState { uninitialized, initializing, ready, error }

/// Communicates state transitions of the background worker.
class IsolateStatusUpdate extends IsolateResponse {
  final WorkerState state;
  final String? message;

  const IsolateStatusUpdate({required this.state, this.message});
}

/// Communicates successful completion of an inference request.
class IsolateInferenceSuccess extends IsolateResponse {
  final List<double> embedding;
  final double inferenceTimeMs;
  final String text;

  const IsolateInferenceSuccess({
    required this.embedding,
    required this.inferenceTimeMs,
    required this.text,
  });
}

/// Intent embedding result for generative routing.
class IsolateIntentEmbedSuccess extends IsolateResponse {
  final int requestId;
  final List<double> embedding;
  final String text;

  const IsolateIntentEmbedSuccess({
    required this.requestId,
    required this.embedding,
    required this.text,
  });
}

/// Communicates an error that occurred inside the Isolate thread.
class IsolateErrorResponse extends IsolateResponse {
  final String message;
  final String? originalText;

  const IsolateErrorResponse({required this.message, this.originalText});
}

/// Stages of the inference pipeline for visualization.
enum PipelineStage {
  tokenize,
  tensor,
  infer,
  pool,
  normalize,
}

/// Emitted during inference to drive pipeline theater UI.
class IsolatePipelineStage extends IsolateResponse {
  final PipelineStage stage;
  final String? detail;
  final List<String>? tokens;
  final int? seqLen;
  final double? l2Norm;

  const IsolatePipelineStage({
    required this.stage,
    this.detail,
    this.tokens,
    this.seqLen,
    this.l2Norm,
  });
}
