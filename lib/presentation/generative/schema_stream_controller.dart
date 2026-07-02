import 'package:flutter/foundation.dart';

import '../../domain/ui_schema.dart';

/// Emits partial schemas incrementally and caches recent layouts in memory.
class SchemaStreamController extends ChangeNotifier {
  static const int maxPersisted = 5;

  UiLayoutSchema? _fullSchema;
  UiLayoutSchema? _partialSchema;
  int _hydrationStep = 0;
  final List<UiLayoutSchema> _history = [];

  UiLayoutSchema? get fullSchema => _fullSchema;
  UiLayoutSchema? get partialSchema => _partialSchema;
  int get hydrationStep => _hydrationStep;
  List<UiLayoutSchema> get persistedSchemas => List.unmodifiable(_history);

  void reset() {
    _fullSchema = null;
    _partialSchema = null;
    _hydrationStep = 0;
    notifyListeners();
  }

  void beginStream(UiLayoutSchema schema) {
    _fullSchema = schema;
    _partialSchema = UiLayoutSchema(
      layout: schema.layout,
      components: const [],
      templateId: schema.templateId,
      confidence: schema.confidence,
    );
    _hydrationStep = 0;
    notifyListeners();
  }

  Future<void> streamComponents({
    Duration stepDelay = const Duration(milliseconds: 280),
  }) async {
    final schema = _fullSchema;
    if (schema == null) return;

    for (var i = 1; i <= schema.components.length; i++) {
      _hydrationStep = i;
      _partialSchema = UiLayoutSchema(
        layout: schema.layout,
        components: schema.components.take(i).toList(),
        templateId: schema.templateId,
        confidence: schema.confidence,
      );
      notifyListeners();
      await Future<void>.delayed(stepDelay);
    }

    _persist(schema);
  }

  void setSchemaImmediate(UiLayoutSchema schema) {
    _fullSchema = schema;
    _partialSchema = schema;
    _hydrationStep = schema.components.length;
    _persist(schema);
    notifyListeners();
  }

  void rehydratePrevious([int indexFromEnd = 1]) {
    if (_history.isEmpty) return;
    final idx = _history.length - indexFromEnd;
    if (idx < 0) return;
    setSchemaImmediate(_history[idx]);
  }

  void _persist(UiLayoutSchema schema) {
    _history.removeWhere(
      (s) => s.templateId == schema.templateId && s.layout == schema.layout,
    );
    _history.add(schema);
    while (_history.length > maxPersisted) {
      _history.removeAt(0);
    }
  }
}
