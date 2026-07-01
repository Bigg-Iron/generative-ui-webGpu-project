class InferenceResult {
  final List<double> embedding;
  final double inferenceTimeMs;
  final String text;
  final String? error;

  const InferenceResult({
    required this.embedding,
    required this.inferenceTimeMs,
    required this.text,
    this.error,
  });

  factory InferenceResult.error(String message, String originalText) {
    return InferenceResult(
      embedding: const [],
      inferenceTimeMs: 0.0,
      text: originalText,
      error: message,
    );
  }

  bool get hasError => error != null;

  @override
  String toString() {
    return 'InferenceResult(embeddingLength: ${embedding.length}, time: ${inferenceTimeMs}ms, error: $error)';
  }
}
