import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/ui_schema.dart';
import 'primitive_registry.dart';

class LayoutEngine extends StatelessWidget {
  final UiLayoutSchema schema;
  final int hydrationStep;

  const LayoutEngine({super.key, required this.schema, this.hydrationStep = 0});

  @override
  Widget build(BuildContext context) {
    final children = schema.components
        .take(hydrationStep.clamp(0, schema.components.length))
        .map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 12),
                    child: child,
                  ),
                );
              },
              child: PrimitiveRegistry.build(c.type, c.props),
            ),
          ),
        )
        .toList();

    if (schema.layout == 'split_pane' && children.length >= 2) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: children[1]),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class GenerativeHydrationInspector extends StatefulWidget {
  final UiLayoutSchema? schema;
  final String? intentText;

  const GenerativeHydrationInspector({super.key, this.schema, this.intentText});

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
      return const Center(
        child: Text(
          'TYPE AN INTENT TO HYDRATE PRIMITIVES',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    final json = formatSchemaJson(schema);
    final visibleChars = (_hydrationStep * 24).clamp(0, json.length);
    final streamingJson = json.substring(0, visibleChars);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            child: LayoutEngine(schema: schema, hydrationStep: _hydrationStep),
          ),
        ),
      ],
    );
  }
}
