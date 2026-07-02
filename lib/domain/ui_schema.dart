import 'generative_context.dart';

/// Declarative UI schema for generative layout hydration.
class UiLayoutSchema {
  final String layout;
  final List<UiComponentSchema> components;
  final String? templateId;
  final double? confidence;

  const UiLayoutSchema({
    required this.layout,
    required this.components,
    this.templateId,
    this.confidence,
  });

  factory UiLayoutSchema.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'] as List<dynamic>? ?? [];
    return UiLayoutSchema(
      layout: json['layout'] as String? ?? 'stack',
      components: rawComponents
          .map((c) => UiComponentSchema.fromJson(c as Map<String, dynamic>))
          .toList(),
      templateId: json['templateId'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'layout': layout,
        'components': components.map((c) => c.toJson()).toList(),
        if (templateId != null) 'templateId': templateId,
        if (confidence != null) 'confidence': confidence,
      };

  UiLayoutSchema copyWith({
    String? layout,
    List<UiComponentSchema>? components,
    String? templateId,
    double? confidence,
  }) {
    return UiLayoutSchema(
      layout: layout ?? this.layout,
      components: components ?? this.components,
      templateId: templateId ?? this.templateId,
      confidence: confidence ?? this.confidence,
    );
  }

  List<String> validate({GenerativeContext? context}) {
    final errors = <String>[];
    const knownLayouts = {'stack', 'split_pane', 'accordion'};
    if (!knownLayouts.contains(layout)) {
      errors.add('Unknown layout: $layout');
    }

    if (components.isEmpty) {
      errors.add('Schema has no components');
    }

    for (var i = 0; i < components.length; i++) {
      errors.addAll(components[i].validate(indexPath: '[$i]', context: context));
    }

    if (context != null) {
      final requiredHistory = _requiredHistoryCount();
      if (context.history.length < requiredHistory) {
        errors.add(
          'Requires $requiredHistory history item(s), have ${context.history.length}',
        );
      }
    }

    return errors;
  }

  int _requiredHistoryCount() {
    var max = 0;
    for (final c in components) {
      max = max > c.requiredHistoryCount ? max : c.requiredHistoryCount;
    }
    return max;
  }
}

class UiComponentSchema {
  final String type;
  final Map<String, dynamic> props;
  final List<UiComponentSchema>? children;

  const UiComponentSchema({
    required this.type,
    required this.props,
    this.children,
  });

  factory UiComponentSchema.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>?;
    return UiComponentSchema(
      type: json['type'] as String? ?? 'MetricCard',
      props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
      children: rawChildren
          ?.map((c) => UiComponentSchema.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'props': props,
        if (children != null)
          'children': children!.map((c) => c.toJson()).toList(),
      };

  bool get isContainer =>
      type == 'Stack' || type == 'SplitPane' || type == 'Accordion';

  int get requiredHistoryCount {
    switch (type) {
      case 'SimilarityMatrix':
        return 2;
      case 'EmbeddingMap':
        return 1;
      case 'ComparePicker':
        return 2;
      default:
        return 0;
    }
  }

  List<String> validate({required String indexPath, GenerativeContext? context}) {
    final errors = <String>[];
    const knownTypes = {
      'MetricCard',
      'SimilarityBar',
      'VectorHeatmap',
      'EmbeddingMap',
      'SimilarityMatrix',
      'PipelineTheater',
      'HistoryList',
      'ComparePicker',
      'IntentSuggestions',
      'Stack',
      'SplitPane',
      'Accordion',
      'DendrogramMini',
    };

    if (!knownTypes.contains(type)) {
      errors.add('$indexPath unknown type: $type');
    }

    if (isContainer && (children == null || children!.isEmpty)) {
      errors.add('$indexPath container $type has no children');
    }

    if (children != null) {
      for (var i = 0; i < children!.length; i++) {
        errors.addAll(
          children![i].validate(indexPath: '$indexPath/$type[$i]', context: context),
        );
      }
    }

    if (context != null && context.history.length < requiredHistoryCount) {
      errors.add(
        '$indexPath $type needs $requiredHistoryCount history items',
      );
    }

    return errors;
  }

  Map<String, dynamic> resolvedProps(GenerativeContext context) {
    return PropInterpolator.resolve(props, context);
  }
}

/// Resolves `$variable` placeholders in schema props at hydration time.
class PropInterpolator {
  static Map<String, dynamic> resolve(
    Map<String, dynamic> props,
    GenerativeContext context,
  ) {
    final resolved = <String, dynamic>{};
    for (final entry in props.entries) {
      resolved[entry.key] = _resolveValue(entry.value, context);
    }
    return resolved;
  }

  static dynamic _resolveValue(dynamic value, GenerativeContext context) {
    if (value is String && value.startsWith('\$')) {
      return switch (value) {
        '\$bestSimilarity' => context.bestNonSelfSimilarity ?? 0.0,
        '\$inferenceTimeMs' => context.inferenceTimeMs ?? 0.0,
        '\$dim' => context.activeDim ?? 0,
        '\$l2Norm' => context.activeL2Norm ?? 0.0,
        _ => value,
      };
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k, _resolveValue(v, context)));
    }
    return value;
  }
}

/// Rule-based intent matcher that maps user phrases to UI schemas.
class IntentMatcher {
  static UiLayoutSchema? match(
    String input, {
    double? similarity,
    int? dim,
    double? inferenceTimeMs,
    double? l2Norm,
  }) {
    final lower = input.toLowerCase();

    if (lower.contains('similar') ||
        lower.contains('compare') ||
        lower.contains('match')) {
      return UiLayoutSchema(
        layout: 'split_pane',
        templateId: 'keyword_compare',
        confidence: 0.5,
        components: [
          UiComponentSchema(
            type: 'SplitPane',
            props: {'ratio': 0.45},
            children: [
              const UiComponentSchema(
                type: 'SimilarityBar',
                props: {'score': '\$bestSimilarity'},
              ),
              const UiComponentSchema(
                type: 'SimilarityMatrix',
                props: {'compact': true},
              ),
            ],
          ),
        ],
      );
    }

    if (lower.contains('benchmark') ||
        lower.contains('latency') ||
        lower.contains('speed') ||
        lower.contains('performance')) {
      return UiLayoutSchema(
        layout: 'stack',
        templateId: 'keyword_benchmark',
        confidence: 0.5,
        components: [
          UiComponentSchema(
            type: 'MetricCard',
            props: {
              'label': 'LATENCY',
              'value': inferenceTimeMs != null
                  ? inferenceTimeMs.toStringAsFixed(1)
                  : '\$inferenceTimeMs',
              'unit': 'ms',
            },
          ),
          const UiComponentSchema(
            type: 'PipelineTheater',
            props: {'dataRef': 'pipeline'},
          ),
        ],
      );
    }

    if (lower.contains('explore') ||
        lower.contains('map') ||
        lower.contains('space') ||
        lower.contains('embedding')) {
      return const UiLayoutSchema(
        layout: 'stack',
        templateId: 'keyword_explore',
        confidence: 0.5,
        components: [
          UiComponentSchema(
            type: 'MetricCard',
            props: {'label': 'VECTORS', 'value': '\$dim', 'unit': 'd'},
          ),
          UiComponentSchema(
            type: 'EmbeddingMap',
            props: {'compact': true, 'height': 160},
          ),
        ],
      );
    }

    if (lower.contains('vector') || lower.contains('detail')) {
      return UiLayoutSchema(
        layout: 'stack',
        templateId: 'keyword_vector_detail',
        confidence: 0.5,
        components: [
          const UiComponentSchema(
            type: 'VectorHeatmap',
            props: {'dataRef': 'activeEmbedding'},
          ),
          UiComponentSchema(
            type: 'MetricCard',
            props: {
              'label': 'L2 NORM',
              'value': l2Norm != null
                  ? l2Norm.toStringAsFixed(4)
                  : '\$l2Norm',
            },
          ),
          UiComponentSchema(
            type: 'MetricCard',
            props: {
              'label': 'DIM',
              'value': dim?.toString() ?? '\$dim',
            },
          ),
        ],
      );
    }

    if (lower.contains('history') || lower.contains('catalog')) {
      return const UiLayoutSchema(
        layout: 'stack',
        templateId: 'keyword_history',
        confidence: 0.5,
        components: [
          UiComponentSchema(type: 'HistoryList', props: {}),
        ],
      );
    }

    return null;
  }
}
