import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import '../../domain/isolate_message.dart';
import 'tokenizer.dart';

class MlIsolateWorker {
  Isolate? _isolate;
  SendPort? _commandPort;
  final ReceivePort _responsePort = ReceivePort();
  
  StreamController<IsolateResponse>? _responseController;
  
  Stream<IsolateResponse> get responseStream => _responseController!.stream;
  
  bool _isInitializing = false;
  bool _isReady = false;
  
  bool get isReady => _isReady;
  
  Future<void> start() async {
    if (_isInitializing || _isReady) return;
    _isInitializing = true;
    
    _responseController = StreamController<IsolateResponse>.broadcast();
    
    // Spawn the background isolate
    _isolate = await Isolate.spawn(_isolateEntryPoint, _responsePort.sendPort);
    
    // Listen for responses from the isolate
    _responsePort.listen((message) {
      if (message is SendPort) {
        // Handshake: first message is the command port
        _commandPort = message;
      } else if (message is IsolateResponse) {
        if (message is IsolateStatusUpdate) {
          if (message.state == WorkerState.ready) {
            _isReady = true;
            _isInitializing = false;
          } else if (message.state == WorkerState.error) {
            _isReady = false;
            _isInitializing = false;
          }
        }
        _responseController?.add(message);
      }
    });
  }

  void initializeModel(String modelPath, String vocabPath) {
    final port = _commandPort;
    if (port == null) {
      throw StateError('Isolate is not started or port handshake not complete.');
    }
    port.send(InitCommand(
      replyTo: _responsePort.sendPort,
      modelPath: modelPath,
      vocabPath: vocabPath,
    ));
  }

  void runInference(String text) {
    final port = _commandPort;
    if (port == null || !_isReady) {
      throw StateError('Isolate is not ready for inference.');
    }
    port.send(InferenceCommand(text: text));
  }

  Future<void> stop() async {
    _commandPort?.send(const ShutdownCommand());
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _commandPort = null;
    _responsePort.close();
    _isReady = false;
    _isInitializing = false;
    await _responseController?.close();
    _responseController = null;
  }

  // The entry point for the background isolate
  static void _isolateEntryPoint(SendPort mainSendPort) async {
    final commandPort = ReceivePort();
    mainSendPort.send(commandPort.sendPort);
    
    OrtSession? session;
    WordPieceTokenizer? tokenizer;
    bool isFallbackMock = false;

    await for (final command in commandPort) {
      if (command is InitCommand) {
        try {
          mainSendPort.send(const IsolateStatusUpdate(
            state: WorkerState.initializing,
            message: 'Initializing background environment...',
          ));

          // 1. Initialize Tokenizer
          try {
            if (command.vocabPath.isNotEmpty && await File(command.vocabPath).exists()) {
              final vocabText = await File(command.vocabPath).readAsString();
              tokenizer = WordPieceTokenizer.fromString(vocabText);
            } else {
              tokenizer = WordPieceTokenizer.fallback();
            }
          } catch (e) {
            tokenizer = WordPieceTokenizer.fallback();
          }

          // 2. Initialize ONNX Runtime
          final modelFile = File(command.modelPath);
          if (await modelFile.exists()) {
            try {
              // Initialize environment
              OrtEnv.instance.init();
              
              final sessionOptions = OrtSessionOptions()
                ..setIntraOpNumThreads(2)
                ..setInterOpNumThreads(2);
                
              session = OrtSession.fromFile(modelFile, sessionOptions);
              isFallbackMock = false;
            } catch (e) {
              // Fallback to mock if ONNX fails to load native library in local terminal/sim
              isFallbackMock = true;
            }
          } else {
            // Model file doesn't exist, we run in fallback mock mode
            isFallbackMock = true;
          }

          mainSendPort.send(IsolateStatusUpdate(
            state: WorkerState.ready,
            message: isFallbackMock
                ? 'Ready (Fallback Mode: Mock Embeddings - Model Asset Missing)'
                : 'Ready (ONNX Model Loaded)',
          ));
        } catch (e) {
          mainSendPort.send(IsolateErrorResponse(
            message: 'Failed to initialize ML session: $e',
          ));
          mainSendPort.send(const IsolateStatusUpdate(
            state: WorkerState.error,
          ));
        }
      } else if (command is InferenceCommand) {
        final text = command.text;
        final startTime = DateTime.now();

        try {
          if (tokenizer == null) {
            throw StateError('Tokenizer not initialized');
          }

          // Tokenize
          final tokenStrings = tokenizer.tokenizeToStrings(text);
          final inputIds = tokenizer.encode(text);
          final inputLength = inputIds.where((id) => id != tokenizer!.padId).length;

          mainSendPort.send(IsolatePipelineStage(
            stage: PipelineStage.tokenize,
            detail: '${tokenStrings.length} tokens',
            tokens: tokenStrings,
            seqLen: inputLength,
          ));

          mainSendPort.send(IsolatePipelineStage(
            stage: PipelineStage.tensor,
            detail: '[1, $inputLength]',
            seqLen: inputLength,
          ));

          List<double> embedding;

          if (isFallbackMock || session == null) {
            mainSendPort.send(const IsolatePipelineStage(
              stage: PipelineStage.infer,
              detail: 'Mock forward pass',
            ));

            embedding = _generateMockEmbedding(text);
            await Future.delayed(const Duration(milliseconds: 45));
          } else {
            mainSendPort.send(const IsolatePipelineStage(
              stage: PipelineStage.infer,
              detail: 'ONNX session.run',
            ));

            // Run real ONNX inference
            // BGE-small expects: input_ids [batch, seq_len], attention_mask [batch, seq_len], token_type_ids [batch, seq_len]
            final shape = [1, inputLength];
            
            final attentionMask = List<int>.generate(inputLength, (i) => inputIds[i] == tokenizer!.padId ? 0 : 1);
            final tokenTypeIds = List<int>.filled(inputLength, 0);

            final ortInputIds = OrtValueTensor.createTensorWithDataList(Int64List.fromList(inputIds), shape);
            final ortAttentionMask = OrtValueTensor.createTensorWithDataList(Int64List.fromList(attentionMask), shape);
            final ortTokenTypeIds = OrtValueTensor.createTensorWithDataList(Int64List.fromList(tokenTypeIds), shape);

            final inputs = {
              'input_ids': ortInputIds,
              'attention_mask': ortAttentionMask,
              'token_type_ids': ortTokenTypeIds,
            };

            final runOptions = OrtRunOptions();
            final outputs = await session.runAsync(runOptions, inputs);

            if (outputs != null && outputs.isNotEmpty) {
              // BGE output is usually 'last_hidden_state' or 'sentence_embedding' at index 0
              final outputValue = outputs[0];
              if (outputValue != null) {
                final rawData = outputValue.value as List;
                embedding = _parseEmbeddingFromOnnxOutput(rawData, inputIds, tokenizer.padId);
              } else {
                throw StateError('ONNX model output at index 0 is null');
              }
            } else {
              throw StateError('ONNX model output list is null or empty');
            }

            // Dispose tensors
            ortInputIds.release();
            ortAttentionMask.release();
            ortTokenTypeIds.release();
            runOptions.release();
            for (final out in outputs) {
              out?.release();
            }
          }

          mainSendPort.send(IsolatePipelineStage(
            stage: PipelineStage.pool,
            detail: 'Mean pool → ${embedding.length}d',
            seqLen: embedding.length,
          ));

          final norm = _l2Norm(embedding);
          mainSendPort.send(IsolatePipelineStage(
            stage: PipelineStage.normalize,
            detail: 'L2 normalize',
            l2Norm: norm,
          ));

          final elapsedMs = DateTime.now().difference(startTime).inMicroseconds / 1000.0;

          mainSendPort.send(IsolateInferenceSuccess(
            embedding: embedding,
            inferenceTimeMs: elapsedMs,
            text: text,
          ));
        } catch (e) {
          mainSendPort.send(IsolateErrorResponse(
            message: 'Inference error: $e',
            originalText: text,
          ));
        }
      } else if (command is ShutdownCommand) {
        session?.release();
        OrtEnv.instance.release();
        Isolate.exit();
      }
    }
  }

  /// Generates a mock embedding based on the text hash, normalized so L2 norm is 1.0.
  static List<double> _generateMockEmbedding(String text) {
    const dim = 384;
    final rand = Random(text.hashCode);
    final raw = List<double>.generate(dim, (_) => rand.nextDouble() * 2 - 1);
    
    // Normalize to unit length (L2 norm = 1.0)
    var sumSq = 0.0;
    for (final val in raw) {
      sumSq += val * val;
    }
    final norm = sqrt(sumSq);
    if (norm > 0.0) {
      for (var i = 0; i < dim; i++) {
        raw[i] /= norm;
      }
    }
    return raw;
  }

  /// Helper to average pool ONNX output tensors of shape [1, seq_len, 384] to a single [384] vector.
  static List<double> _parseEmbeddingFromOnnxOutput(List rawData, List<int> inputIds, int padId) {
    if (rawData.isEmpty) return const [];
    
    // 1D tensor [dim] -> List<double>
    if (rawData[0] is! List) {
      return rawData.cast<double>();
    }
    
    // 2D tensor [batch, dim] -> List<List<double>>. Return first row.
    if (rawData[0][0] is! List) {
      return (rawData[0] as List).cast<double>();
    }
    
    // 3D tensor [batch, seq_len, dim] -> List<List<List<double>>>. Average pool seq_len.
    final seq = rawData[0] as List;
    final seqLen = seq.length;
    final dim = (seq[0] as List).length;
    
    final pooled = List<double>.filled(dim, 0.0);
    var validCount = 0;
    
    for (var i = 0; i < seqLen; i++) {
      if (i < inputIds.length && inputIds[i] == padId) continue;
      validCount++;
      final vec = seq[i] as List;
      for (var d = 0; d < dim; d++) {
        pooled[d] += (vec[d] as num).toDouble();
      }
    }
    
    if (validCount > 0) {
      for (var d = 0; d < dim; d++) {
        pooled[d] /= validCount;
      }
    }
    
    // Normalize pooled embedding
    var sumSq = 0.0;
    for (final val in pooled) {
      sumSq += val * val;
    }
    final norm = sqrt(sumSq);
    if (norm > 0.0) {
      for (var d = 0; d < dim; d++) {
        pooled[d] /= norm;
      }
    }
    
    return pooled;
  }

  static double _l2Norm(List<double> v) {
    var sumSq = 0.0;
    for (final val in v) {
      sumSq += val * val;
    }
    return sqrt(sumSq);
  }
}
