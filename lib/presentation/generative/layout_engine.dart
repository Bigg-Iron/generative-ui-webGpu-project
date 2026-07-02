import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/generative_context.dart';
import '../../domain/ui_schema.dart';
import '../../data/embedding_intent_router.dart';
import 'primitive_registry.dart';

class LayoutEngine extends StatelessWidget {
  final UiLayoutSchema schema;
  final GenerativeContext generativeContext;
  final int hydrationStep;

  const LayoutEngine({
    super.key,
    required this.schema,
    required this.generativeContext,
    this.hydrationStep = 0,
  });

  @override
  Widget build(BuildContext context) {
    final visible = schema.components
        .take(hydrationStep.clamp(0, schema.components.length))
        .toList();

    return _buildLayout(schema.layout, visible);
  }

  Widget _buildLayout(String layout, List<UiComponentSchema> components) {
    if (layout == 'split_pane' && components.length >= 2) {
      const ratio = 0.5;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: (ratio * 100).round().clamp(1, 99),
            child: _buildComponent(components[0]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: ((1 - ratio) * 100).round().clamp(1, 99),
            child: _buildComponent(components[1]),
          ),
        ],
      );
    }

    if (layout == 'accordion') {
      return _AccordionLayout(
        components: components,
        generativeContext: generativeContext,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: components
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildComponent(c),
            ),
          )
          .toList(),
    );
  }

  Widget _buildComponent(UiComponentSchema component) {
    final resolved = component.resolvedProps(generativeContext);

    if (component.isContainer && component.children != null) {
      return _buildContainer(component, resolved);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
        milliseconds: 280 + ((resolved['priority'] as num?)?.toInt() ?? 0) * 40,
      ),
      curve: Curves.easeOutCubic,
      builder: (ctx, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: PrimitiveRegistry.build(
        component.type,
        resolved,
        generativeContext,
      ),
    );
  }

  Widget _buildContainer(
    UiComponentSchema component,
    Map<String, dynamic> resolved,
  ) {
    final children = component.children ?? [];
    if (component.type == 'SplitPane' && children.length >= 2) {
      final ratio = (resolved['ratio'] as num?)?.toDouble() ?? 0.5;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: (ratio * 100).round().clamp(1, 99),
            child: _buildComponent(children[0]),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: ((1 - ratio) * 100).round().clamp(1, 99),
            child: _buildComponent(children[1]),
          ),
        ],
      );
    }

    if (component.type == 'Accordion') {
      return _AccordionLayout(
        components: children,
        generativeContext: generativeContext,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildComponent(c),
            ),
          )
          .toList(),
    );
  }
}

class _AccordionLayout extends StatefulWidget {
  final List<UiComponentSchema> components;
  final GenerativeContext generativeContext;

  const _AccordionLayout({
    required this.components,
    required this.generativeContext,
  });

  @override
  State<_AccordionLayout> createState() => _AccordionLayoutState();
}

class _AccordionLayoutState extends State<_AccordionLayout> {
  int _expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.components.length, (i) {
        final component = widget.components[i];
        final expanded = _expandedIndex == i;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderDark),
              borderRadius: BorderRadius.circular(AppBorders.radiusSm),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _expandedIndex = expanded ? -1 : i),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          size: 14,
                          color: AppColors.mutedText,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          component.type.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.mutedText,
                            fontFamily: 'monospace',
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      0,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    child: LayoutEngine(
                      schema: UiLayoutSchema(
                        layout: 'stack',
                        components: [component],
                      ),
                      generativeContext: widget.generativeContext,
                      hydrationStep: 1,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class GenerativeHydrationInspector extends StatefulWidget {
  final UiLayoutSchema? schema;
  final String? intentText;
  final GenerativeContext generativeContext;
  final List<RouterSuggestion> suggestions;
  final List<String>? validationErrors;
  final void Function(String description)? onSuggestionTap;

  const GenerativeHydrationInspector({
    super.key,
    this.schema,
    this.intentText,
    required this.generativeContext,
    this.suggestions = const [],
    this.validationErrors,
    this.onSuggestionTap,
  });

  @override
  State<GenerativeHydrationInspector> createState() =>
      _GenerativeHydrationInspectorState();
}

class _GenerativeHydrationInspectorState
    extends State<GenerativeHydrationInspector> {
  int _hydrationStep = 0;

  @override
  void initState() {
    super.initState();
    if (widget.schema != null) _animateHydration();
  }

  @override
  void didUpdateWidget(covariant GenerativeHydrationInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.schema != oldWidget.schema) {
      _hydrationStep = 0;
      _animateHydration();
    }
  }

  void _animateHydration() {
    final count = widget.schema?.components.length ?? 0;
    if (count == 0) return;
    Future<void> step(int i) async {
      if (!mounted || i > count) return;
      setState(() => _hydrationStep = i);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await step(i + 1);
    }

    step(1);
  }

  @override
  Widget build(BuildContext context) {
    final schema = widget.schema;
    if (schema == null) {
      return _buildEmptyState();
    }

    final json = formatSchemaJson(schema);
    final visibleChars = (_hydrationStep * 24).clamp(0, json.length);
    final streamingJson = json.substring(0, visibleChars);
    final header = _buildHeader(schema);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520;
        final preview = Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.borderDark),
              borderRadius: BorderRadius.circular(AppBorders.radiusSm),
            ),
            child: SingleChildScrollView(
              child: Text(
                streamingJson,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
        final layout = Expanded(
          child: SingleChildScrollView(
            child: LayoutEngine(
              schema: schema,
              generativeContext: widget.generativeContext,
              hydrationStep: _hydrationStep,
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (header != null) ...[
              header,
              const SizedBox(height: AppSpacing.sm),
            ],
            if (widget.validationErrors != null &&
                widget.validationErrors!.isNotEmpty)
              _ValidationBanner(errors: widget.validationErrors!),
            Expanded(
              child: stacked
                  ? Column(
                      children: [
                        preview,
                        const SizedBox(height: AppSpacing.sm),
                        layout,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        preview,
                        const SizedBox(width: AppSpacing.sm),
                        layout,
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final suggestions = widget.suggestions;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'TYPE AN INTENT TO HYDRATE PRIMITIVES',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.mutedText,
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'SUGGESTED INTENTS',
              style: TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 9,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: suggestions.map((s) {
                return ActionChip(
                  label: Text(
                    s.description.length > 40
                        ? '${s.description.substring(0, 40)}…'
                        : s.description,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                    ),
                  ),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.borderDark),
                  onPressed: widget.onSuggestionTap == null
                      ? null
                      : () => widget.onSuggestionTap!(s.description),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildHeader(UiLayoutSchema schema) {
    final parts = <String>[];
    if (widget.intentText != null && widget.intentText!.trim().isNotEmpty) {
      parts.add('INTENT: ${widget.intentText!.trim()}');
    }
    if (schema.templateId != null) {
      parts.add('TEMPLATE: ${schema.templateId}');
    }
    if (schema.confidence != null) {
      parts.add('CONF: ${(schema.confidence! * 100).toStringAsFixed(0)}%');
    }
    if (parts.isEmpty) return null;

    return Text(
      parts.join(' · '),
      style: const TextStyle(
        color: AppColors.secondaryText,
        fontFamily: 'monospace',
        fontSize: 9,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  final List<String> errors;

  const _ValidationBanner({required this.errors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errors
            .map(
              (e) => Text(
                e,
                style: const TextStyle(
                  color: AppColors.error,
                  fontFamily: 'monospace',
                  fontSize: 9,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
