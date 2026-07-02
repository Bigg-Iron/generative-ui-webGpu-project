import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generative_ui_webgpu/domain/generative_context.dart';
import 'package:generative_ui_webgpu/domain/inference_result.dart';
import 'package:generative_ui_webgpu/domain/ui_schema.dart';
import 'package:generative_ui_webgpu/presentation/generative/layout_engine.dart';
import 'package:generative_ui_webgpu/presentation/widgets/embedding_space_map.dart';
import 'package:generative_ui_webgpu/presentation/widgets/similarity_matrix.dart';

InferenceResult _fakeResult(String text, {int dim = 32}) {
  return InferenceResult(
    embedding: List.generate(dim, (i) => (i % 7 - 3) * 0.1),
    inferenceTimeMs: 12.5,
    text: text,
  );
}

void main() {
  final overflowErrors = <String>[];

  setUp(() {
    overflowErrors.clear();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') ||
          text.contains('RenderFlex') ||
          text.contains('unbounded')) {
        overflowErrors.add(text);
      }
      previous?.call(details);
    };
  });

  final history = [
    _fakeResult('hello world'),
    _fakeResult('goodbye moon'),
    _fakeResult('neural embedding'),
  ];

  final context = GenerativeContext(
    history: history,
    activeResult: history.first,
    similarities: const {},
    isProcessing: false,
    onSelectResult: (_) {},
  );

  testWidgets('EmbeddingSpaceMap fits in fixed-height generative slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 160,
            width: 320,
            child: EmbeddingSpaceMap(
              history: history,
              activeResult: history.first,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(overflowErrors, isEmpty, reason: overflowErrors.join('\n'));
  });

  testWidgets('SimilarityMatrix fits in fixed-height generative slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 180,
            width: 320,
            child: SimilarityMatrix(history: history),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(overflowErrors, isEmpty, reason: overflowErrors.join('\n'));
  });

  testWidgets('Generative layout engine hydrates compare template', (
    tester,
  ) async {
    const schema = UiLayoutSchema(
      layout: 'split_pane',
      components: [
        UiComponentSchema(
          type: 'SplitPane',
          props: {'ratio': 0.4},
          children: [
            UiComponentSchema(type: 'SimilarityBar', props: {'score': 0.82}),
            UiComponentSchema(
              type: 'SimilarityMatrix',
              props: {'compact': true},
            ),
          ],
        ),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(402, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            width: 402,
            child: SingleChildScrollView(
              child: LayoutEngine(
                schema: schema,
                generativeContext: context,
                hydrationStep: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(overflowErrors, isEmpty, reason: overflowErrors.join('\n'));
  });

  testWidgets('GenerativeHydrationInspector renders hydrated schema', (
    tester,
  ) async {
    const schema = UiLayoutSchema(
      layout: 'stack',
      templateId: 'vector_detail',
      components: [
        UiComponentSchema(
          type: 'VectorHeatmap',
          props: {'dataRef': 'activeEmbedding'},
        ),
        UiComponentSchema(
          type: 'MetricCard',
          props: {'label': 'L2 NORM', 'value': '1.0'},
        ),
        UiComponentSchema(type: 'EmbeddingMap', props: {'height': 140}),
      ],
    );

    await tester.binding.setSurfaceSize(const Size(402, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GenerativeHydrationInspector(
            schema: schema,
            intentText: 'vector detail',
            generativeContext: context,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(overflowErrors, isEmpty, reason: overflowErrors.join('\n'));
  });
}
