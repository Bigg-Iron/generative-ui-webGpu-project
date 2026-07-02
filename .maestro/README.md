# Maestro E2E Tests

End-to-end UI tests for the Neural Embedding Isolate demo.

## Prerequisites

- [Maestro CLI](https://maestro.mobile.dev/) installed
- iOS Simulator or Android emulator running with the app built for that target

## iOS (default)

```bash
flutter build ios --simulator --debug
flutter install -d <simulator-id>

maestro test .maestro/suite.yaml
```

## Android

Override the bundle id when running:

```bash
flutter build apk --debug
flutter install -d <device-id>

maestro test -e APP_ID=com.example.generative_ui_webgpu .maestro/suite.yaml
```

For individual flows:

```bash
maestro test .maestro/flows/03_single_inference.yaml
```

## Suite coverage

| Flow | What it verifies |
|------|------------------|
| `01_smoke_launch` | App shell, dashboard sections, input controls |
| `02_worker_initialization` | Background isolate reaches ready state |
| `03_single_inference` | Text projection pipeline and catalog entry |
| `04_compare_vectors` | Multi-vector catalog and compare lane |
| `05_catalog_views` | LIST / MAP / MATRIX / GEN catalog modes |
| `06_catalog_minimize` | Catalog minimize and restore rail |
| `07_generative_intent` | Generative intent hydration |
| `08_vector_detail_expand` | Catalog vector detail expand/collapse |
| `09_clear_catalog` | Catalog clear action |
| `10_layout_intent_inference` | Optional layout intent on infer |

Semantic identifiers are defined on dashboard controls for stable selectors across locales.

## Notes

- Rebuild and reinstall after changing semantics identifiers: `flutter build ios --simulator --debug && flutter install -d <sim-id>`
- Ready-state regex: use `".*READY.*"` (fallback mock and ONNX modes differ).
- Dismiss keyboard with `tapOn: id: status_panel` (`hideKeyboard` is unreliable here).
- `run_single_inference` waits for `catalog_history_item` and `CLEAR` so it does not false-pass on text still sitting in the input field.
- If Maestro cannot connect to the iOS driver, increase `MAESTRO_DRIVER_STARTUP_TIMEOUT` (e.g. `180000`) and ensure the simulator is booted.
