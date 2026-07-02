import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:generative_ui_webgpu/presentation/screens/dashboard.dart';
import 'package:generative_ui_webgpu/presentation/state/ml_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final overflowErrors = <FlutterErrorDetails>[];

  setUp(() {
    overflowErrors.clear();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') ||
          text.contains('RenderFlex') ||
          text.contains('unbounded')) {
        overflowErrors.add(details);
      }
      previous?.call(details);
    };
  });

  Future<MlState> pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(402, 778),
  }) async {
    await tester.binding.setSurfaceSize(size);

    final state = MlState();
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(state: state)));
    await tester.pump();
    return state;
  }

  testWidgets('dashboard mobile layout has no render overflows', (
    tester,
  ) async {
    final state = await pumpDashboard(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(
      overflowErrors,
      isEmpty,
      reason: overflowErrors.map((e) => e.exceptionAsString()).join('\n'),
    );

    state.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('catalog view toggles do not overflow', (tester) async {
    final state = await pumpDashboard(tester);
    await tester.pump(const Duration(seconds: 1));

    for (final id in [
      'catalog_view_map',
      'catalog_view_matrix',
      'catalog_view_gen',
      'catalog_view_list',
    ]) {
      await tester.tap(find.bySemanticsIdentifier(id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        overflowErrors,
        isEmpty,
        reason:
            'After tapping $id: ${overflowErrors.map((e) => e.exceptionAsString()).join('\n')}',
      );
    }

    state.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('catalog minimize toggle does not overflow', (tester) async {
    final state = await pumpDashboard(tester);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.bySemanticsIdentifier('catalog_minimize_button'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.textContaining('CATALOG'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(overflowErrors, isEmpty);

    state.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
