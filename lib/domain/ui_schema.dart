/// Declarative UI schema for generative layout hydration.
class UiLayoutSchema {
  final String layout;
  final List<UiComponentSchema> components;

  const UiLayoutSchema({
    required this.layout,
    required this.components,
  });

  factory UiLayoutSchema.fromJson(Map<String, dynamic> json) {
    final rawComponents = json['components'] as List<dynamic>? ?? [];
    return UiLayoutSchema(
      layout: json['layout'] as String? ?? 'stack',
      components: rawComponents
          .map((c) => UiComponentSchema.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'layout': layout,
        'components': components.map((c) => c.toJson()).toList(),
      };
}

class UiComponentSchema {
  final String type;
  final Map<String, dynamic> props;

  const UiComponentSchema({
    required this.type,
    required this.props,
  });

  factory UiComponentSchema.fromJson(Map<String, dynamic> json) {
    return UiComponentSchema(
      type: json['type'] as String? ?? 'MetricCard',
      props: Map<String, dynamic>.from(json['props'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'props': props,
      };
}

/// Rule-based intent matcher that maps user phrases to UI schemas.
class IntentMatcher {
  static UiLayoutSchema? match(String input, {double? similarity, int? dim}) {
    final lower = input.toLowerCase();

    if (lower.contains('similar') ||
        lower.contains('compare') ||
        lower.contains('match')) {
      return UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'SimilarityBar',
            props: {'score': similarity ?? 0.0},
          ),
          if (dim != null)
            UiComponentSchema(
              type: 'MetricCard',
              props: {'label': 'DIM', 'value': dim},
            ),
        ],
      );
    }

    if (lower.contains('benchmark') ||
        lower.contains('latency') ||
        lower.contains('speed') ||
        lower.contains('performance')) {
      return const UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'MetricCard',
            props: {'label': 'MODE', 'value': 'BENCHMARK'},
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
        components: [
          UiComponentSchema(
            type: 'MetricCard',
            props: {'label': 'MODE', 'value': 'EXPLORE'},
          ),
          UiComponentSchema(
            type: 'DendrogramMini',
            props: {'label': 'SEMANTIC MAP'},
          ),
        ],
      );
    }

    if (lower.contains('vector') || lower.contains('detail')) {
      return UiLayoutSchema(
        layout: 'stack',
        components: [
          UiComponentSchema(
            type: 'VectorHeatmap',
            props: {'dim': dim ?? 384},
          ),
        ],
      );
    }

    return null;
  }
}
