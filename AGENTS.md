# Role & Objective
You are an elite Flutter Architect and Machine Learning Engineer. Your objective is to build a high-performance, minimalist Flutter Demo Application that demonstrates zero-jank, on-device machine learning inference using a background Dart Isolate.

## Core Architecture Requirements
Zero-Blocking UI Thread: The main UI thread must remain entirely unburdened. All model initialization, tokenization, tensor manipulation, and inference logic must run inside a persistent background Dart Isolate.

## Tech Stack & Dependencies:

- Framework: Flutter (configured for high-performance rendering).

- ML Inference: Use a reliable, lightweight on-device package like onnxruntime or tflite_flutter.

## State Management:
- A simple, clean, native solution like ValueNotifier/InheritedWidget or a lightweight ChangeNotifier to keep overhead minimal.

## Design System (UI/UX):

- Theme: A sharp, ultra-minimalist grayscale palette (pure blacks, slate grays, bright whites).

- Visual Hierarchy: Clean typography, generous layout padding, and crisp structural borders.

- Performance: Implement subtle, smooth micro-animations (e.g., a fading/pulsing loading indicator using ImplicitlyAnimatedWidget or AnimationController) that do not drop frames during background processing.

## App Features & Lifecycle States
Your demo should implement a simple text classification model (EmbeddingGemma (308M) Natively supported by LiteRT (the evolution of TensorFlow Lite) and llama.cpp wrapper pipelines, making it trivial to run inside a Dart Isolate. It also allows you to truncate vector dimensions (from 768 down to 256 or 128) if you need faster lookups in your frontend state database.) -- or sentiment analysis: (e.g., parsing user text input and outputting a classification vector/score) handling the following explicit states:

- Uninitialized/Loading: Application checks for the local model asset binary, allocates memory, and spins up the background worker Isolate. Shows a clean, pulsing progress state.

- Ready/Idle: Model is cached in memory. The UI exposes a text input field and a submit mechanism.

- Processing: User triggers an inference request. The text string is packaged into a thread-safe message pipeline and shipped to the Isolate. The UI thread renders a fluid, non-blocking loading micro-animation.

- Success/Rendered: The Isolate finishes processing, ships the structured payload back to the main thread, and the UI immediately animates the resulting metric layer onto the screen.

## Expected Directory Structure
Create a modular, clean-cut project layout matching this scheme:

Plaintext
lib/
├── main.dart # App entry point, theme declaration
├── core/ └── constants.dart # Design tokens, asset paths
├── data/ ├── models/ # Local model binaries (.onnx or .tflite placeholders) └── ml_isolate_worker.dart # Isolated background thread lifecycle management
├── domain/ └── inference_result.dart # Immutable data model for model outputs
└── presentation/
 ├── state/ # State management layer
 ├── screens/ # Main dashboard layout
 └── widgets/ # Reusable minimalist UI components

## Execution Steps

- Scaffolding: Initialize the project and add the necessary ML runtime and performance dependencies to pubspec.yaml.

- Isolate Wireframe: Write the low-level bi-directional communication ports (ReceivePort / SendPort) for the ml_isolate_worker.dart. Ensure proper error boundaries are established so unexpected tensor mismatches don't crash the host process.

- UI Implementation: Build out the grayscale interface. Ensure all text boxes and input areas remain highly responsive to touch/keyboard events while the model worker computes in the background.

- Verification: Verify compilation and ensure no business logic or serialization steps are leaking onto the application's root UI thread. Do not output raw markdown code formatting inside arbitrary implementation files. Keep everything strictly encapsulated.

* Tips: If you want to test a specific model right out of the gate, swap out the text classification mention in the prompt with a specific target asset (e.g., "using a 15MB MobileNet V2 model for image feature vectors" or "a small 30MB BERT-mini model for embedding generation"), and place the corresponding file directly into the directory your agent scaffolds.

To successfully pull off on-device inference without ballooning your Flutter app's binary size or draining device batteries, you must look strictly at models specifically built or quantized for Edge Deployment.

When building the demo: configure the pipeline around ONNX (.onnx) or TFLite/LiteRT (.tflite) runtimes:

Use bge-small-en-v1.5 for the text embedding pipeline (converted to ONNX).

Use MobileNetV4 for the image vector pipeline (converted to TFLite).

This pair gives you highly stable, production-vetted C++ runtime bindings via the respective Flutter packages, ensuring your background thread isolate compiles perfectly without tricky dependencies.

## Cursor Cloud specific instructions

This is a **Flutter** app (`generative_ui_webgpu`), not a Python project (`main.py`/`pyproject.toml` are unused scaffolding). Despite the "WebGPU" README framing, the ML worker uses `dart:io`, so it does **not** run on Flutter web — the working target is the **Linux desktop** app. It embeds a background Dart Isolate that runs `onnxruntime` inference on the `bge-small-en-v1.5` model (384-dim embeddings).

Standard commands (run from repo root; `flutter` is on `PATH` via `~/.bashrc`, installed at `/opt/flutter`):
- Lint: `flutter analyze` (there is no `test/` directory, so `flutter test` reports "Test directory not found").
- Build: `flutter build linux --debug`.
- Run: `flutter run -d linux` (a GTK/X11 desktop is available on `DISPLAY=:1`).

Non-obvious caveats:
- The model binary `assets/models/bge-small-en-v1.5/onnx/model.onnx` (~133MB) is **declared in `pubspec.yaml` but not committed** (git-ignored). It is fetched by the environment update script from Hugging Face. If it is missing, `flutter build`/`run` fails with an asset-not-found error — re-run the update script or `curl` it from `https://huggingface.co/BAAI/bge-small-en-v1.5/resolve/main/onnx/model.onnx` into that path. If the model can't be loaded, the isolate degrades gracefully to a mock-embedding mode (status shows `READY (FALLBACK MODE...)` instead of `READY (ONNX MODEL LOADED)`).
- To view/interact with the GUI, launch the built bundle with `DISPLAY=:1` (e.g. `DISPLAY=:1 ./build/linux/x64/debug/bundle/generative_ui_webgpu`). Software GL emits harmless `libEGL warning: DRI3 ...` lines and falls back to Impeller OpenGLES; this is expected and not an error.
- Hello-world flow: type text → `INFER` produces a 384-d vector; a second sentence via `COMPARE` yields a cosine-similarity score in the Vector Catalog.

