import 'dart:async';

import '../domain/schema_templates.dart';
import '../domain/ui_schema.dart';
import '../domain/vector_math.dart';
import 'ml_isolate_worker.dart';
import '../domain/isolate_message.dart';

/// Ranked template suggestion from embedding intent router.
class RouterSuggestion {
  final String templateId;
  final String description;
  final double score;

  const RouterSuggestion({
    required this.templateId,
    required this.description,
    required this.score,
  });
}

/// Routes user intent to schema templates via BGE embeddings in the isolate.
class EmbeddingIntentRouter {
  final MlIsolateWorker worker;
  final Map<String, List<double>> _templateEmbeddings = {};
  StreamSubscription<IsolateResponse>? _subscription;
  int _nextRequestId = 1;
  final Map<int, Completer<List<double>>> _pending = {};
  bool _templatesInitialized = false;

  EmbeddingIntentRouter({required this.worker});

  bool get isReady => _templatesInitialized;

  void attachToResponseStream(Stream<IsolateResponse> stream) {
    _subscription?.cancel();
    _subscription = stream.listen(_handleResponse);
  }

  void dispose() {
    _subscription?.cancel();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.complete(const []);
    }
    _pending.clear();
  }

  Future<void> initializeTemplates() async {
    if (_templatesInitialized || !worker.isReady) return;

    for (final template in SchemaTemplateCatalog.all) {
      final embedding = await _embedText(template.description);
      if (embedding.isNotEmpty) {
        _templateEmbeddings[template.id] = embedding;
      }
    }
    _templatesInitialized = _templateEmbeddings.isNotEmpty;
  }

  Future<List<RouterSuggestion>> rankIntent(String intent) async {
    if (intent.trim().isEmpty) return [];

    final intentEmbedding = await _embedText(intent);
    if (intentEmbedding.isEmpty) {
      return _keywordSuggestions(intent);
    }

    final scored = <RouterSuggestion>[];
    for (final template in SchemaTemplateCatalog.all) {
      final templateEmb = _templateEmbeddings[template.id];
      if (templateEmb == null || templateEmb.isEmpty) continue;
      final score = cosineSimilarity(intentEmbedding, templateEmb);
      scored.add(RouterSuggestion(
        templateId: template.id,
        description: template.description,
        score: score,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).toList();
  }

  List<RouterSuggestion> _keywordSuggestions(String intent) {
    final template = SchemaTemplateCatalog.keywordFallback(intent);
    if (template == null) return [];
    return [
      RouterSuggestion(
        templateId: template.id,
        description: template.description,
        score: 0.4,
      ),
    ];
  }

  Future<UiLayoutSchema?> route(
    String intent, {
    int historyCount = 0,
  }) async {
    final suggestions = await rankIntent(intent);
    if (suggestions.isEmpty) {
      return _keywordSchema(intent);
    }

    final best = suggestions.first;
    if (best.score < SchemaTemplateCatalog.matchThreshold) {
      return _keywordSchema(intent) ??
          _instantiateIfEligible(best.templateId, best.score, historyCount);
    }

    return _instantiateIfEligible(best.templateId, best.score, historyCount);
  }

  UiLayoutSchema? _instantiateIfEligible(
    String templateId,
    double score,
    int historyCount,
  ) {
    final template = SchemaTemplateCatalog.byId(templateId);
    if (template == null) return null;
    if (historyCount < template.requiredHistoryCount) return null;
    return template.instantiate(confidence: score);
  }

  UiLayoutSchema? _keywordSchema(String intent) {
    final template = SchemaTemplateCatalog.keywordFallback(intent);
    return template?.instantiate(confidence: 0.4);
  }

  Future<List<double>> _embedText(String text) async {
    if (!worker.isReady) return [];

    final requestId = _nextRequestId++;
    final completer = Completer<List<double>>();
    _pending[requestId] = completer;

    try {
      worker.embedIntent(text, requestId: requestId);
    } catch (_) {
      _pending.remove(requestId);
      return [];
    }

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        _pending.remove(requestId);
        return <double>[];
      },
    );
  }

  void _handleResponse(IsolateResponse response) {
    if (response is IsolateIntentEmbedSuccess) {
      final completer = _pending.remove(response.requestId);
      completer?.complete(response.embedding);
    } else if (response is IsolateErrorResponse) {
      for (final entry in _pending.entries.toList()) {
        if (!entry.value.isCompleted) {
          entry.value.complete(const []);
        }
        _pending.remove(entry.key);
      }
    }
  }
}
