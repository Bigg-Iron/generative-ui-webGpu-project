import 'ui_schema.dart';

/// Metadata for a curated generative layout template.
class SchemaTemplate {
  final String id;
  final String description;
  final List<String> keywords;
  final int requiredHistoryCount;
  final UiLayoutSchema schema;

  const SchemaTemplate({
    required this.id,
    required this.description,
    this.keywords = const [],
    this.requiredHistoryCount = 0,
    required this.schema,
  });

  UiLayoutSchema instantiate({double confidence = 0.0}) {
    return schema.copyWith(templateId: id, confidence: confidence);
  }
}

/// Frozen catalog of layout patterns ranked by embedding intent router.
class SchemaTemplateCatalog {
  SchemaTemplateCatalog._();

  static const double matchThreshold = 0.55;

  static final List<SchemaTemplate> all = [
    SchemaTemplate(
      id: 'compare_split',
      description: 'Compare semantic similarity between vectors side by side',
      keywords: ['compare', 'similar', 'match', 'contrast', 'diff'],
      requiredHistoryCount: 2,
      schema: const UiLayoutSchema(
        layout: 'split_pane',
        components: [
          UiComponentSchema(
            type: 'SplitPane',
            props: {'ratio': 0.4},
            children: [
              UiComponentSchema(
                type: 'SimilarityBar',
                props: {'score': '\$bestSimilarity'},
              ),
              UiComponentSchema(
                type: 'SimilarityMatrix',
                props: {'compact': true},
              ),
            ],
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'vector_detail',
      description: 'Inspect embedding fingerprint vector dimensions and norms',
      keywords: ['vector', 'detail', 'fingerprint', 'dimensions', 'inspect'],
      requiredHistoryCount: 1,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'VectorHeatmap',
            props: {'dataRef': 'activeEmbedding'},
          ),
          UiComponentSchema(
            type: 'MetricCard',
            props: {'label': 'L2 NORM', 'value': '\$l2Norm'},
          ),
          UiComponentSchema(
            type: 'MetricCard',
            props: {'label': 'DIM', 'value': '\$dim'},
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'explore_map',
      description: 'Explore semantic embedding space map with PCA projection',
      keywords: ['explore', 'map', 'space', 'embedding', 'cluster', 'navigate'],
      requiredHistoryCount: 1,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'MetricCard',
            props: {'label': 'VECTORS', 'value': '\$dim', 'unit': 'd'},
          ),
          UiComponentSchema(
            type: 'EmbeddingMap',
            props: {'compact': true, 'height': 180},
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'benchmark_latency',
      description: 'Benchmark inference latency and pipeline performance',
      keywords: ['benchmark', 'latency', 'speed', 'performance', 'timing'],
      requiredHistoryCount: 0,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'MetricCard',
            props: {
              'label': 'LATENCY',
              'value': '\$inferenceTimeMs',
              'unit': 'ms',
            },
          ),
          UiComponentSchema(
            type: 'PipelineTheater',
            props: {'dataRef': 'pipeline'},
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'history_catalog',
      description: 'Browse inference history with similarity chips',
      keywords: ['history', 'catalog', 'list', 'previous', 'archive'],
      requiredHistoryCount: 1,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(type: 'HistoryList', props: {'compact': true}),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'compare_picker',
      description: 'Pick a vector to compare against the active embedding',
      keywords: ['picker', 'select', 'choose', 'compare target'],
      requiredHistoryCount: 2,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(type: 'ComparePicker', props: {}),
          UiComponentSchema(
            type: 'SimilarityBar',
            props: {'score': '\$bestSimilarity'},
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'pipeline_focus',
      description: 'Focus on the ONNX inference pipeline stages',
      keywords: ['pipeline', 'stages', 'tokenize', 'tensor', 'onnx'],
      requiredHistoryCount: 0,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'PipelineTheater',
            props: {'dataRef': 'pipeline', 'expanded': true},
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'matrix_full',
      description: 'Full pairwise similarity matrix heatmap',
      keywords: ['matrix', 'pairwise', 'grid', 'heatmap'],
      requiredHistoryCount: 2,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'SimilarityMatrix',
            props: {'compact': false},
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'dashboard_overview',
      description: 'Overview dashboard with map metrics and history',
      keywords: ['overview', 'dashboard', 'summary', 'all'],
      requiredHistoryCount: 1,
      schema: const UiLayoutSchema(
        layout: 'accordion',
        components: [
          UiComponentSchema(
            type: 'Accordion',
            props: {},
            children: [
              UiComponentSchema(
                type: 'EmbeddingMap',
                props: {'compact': true, 'height': 140},
              ),
              UiComponentSchema(
                type: 'HistoryList',
                props: {'compact': true},
              ),
            ],
          ),
        ],
      ),
    ),
    SchemaTemplate(
      id: 'similarity_bar_only',
      description: 'Show best similarity score bar',
      keywords: ['score', 'similarity', 'bar', 'metric'],
      requiredHistoryCount: 2,
      schema: const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'SimilarityBar',
            props: {'score': '\$bestSimilarity'},
          ),
        ],
      ),
    ),
  ];

  static SchemaTemplate? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static SchemaTemplate? keywordFallback(String intent) {
    final lower = intent.toLowerCase();
    for (final template in all) {
      for (final kw in template.keywords) {
        if (lower.contains(kw)) return template;
      }
    }
    return null;
  }
}
