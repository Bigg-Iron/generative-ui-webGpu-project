import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

typedef ModelAssetPaths = ({String modelPath, String vocabPath});

Future<ModelAssetPaths> resolveModelAssetPaths() async {
  final tempDir = await getTemporaryDirectory();
  final modelFile = File('${tempDir.path}/model.onnx');
  final vocabFile = File('${tempDir.path}/vocab.txt');

  try {
    final modelBytes = await rootBundle.load(
      'assets/models/bge-small-en-v1.5/onnx/model.onnx',
    );
    await modelFile.writeAsBytes(modelBytes.buffer.asUint8List());
  } catch (_) {}

  try {
    final vocabBytes = await rootBundle.load('assets/vocab.txt');
    await vocabFile.writeAsBytes(vocabBytes.buffer.asUint8List());
  } catch (_) {}

  return (modelPath: modelFile.path, vocabPath: vocabFile.path);
}
