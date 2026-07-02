import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'debug/agent_log.dart';
import 'presentation/screens/dashboard.dart';
import 'presentation/state/ml_state.dart';

void main() {
  // #region agent log
  agentLog(
    location: 'main.dart:main',
    message: 'App main() reached',
    hypothesisId: 'B',
    data: {'kIsWeb': kIsWeb},
  );
  // #endregion

  runApp(const NeuralEmbeddingApp());
}

class NeuralEmbeddingApp extends StatefulWidget {
  const NeuralEmbeddingApp({super.key});

  @override
  State<NeuralEmbeddingApp> createState() => _NeuralEmbeddingAppState();
}

class _DashboardController {
  final MlState state = MlState();
}

class _NeuralEmbeddingAppState extends State<NeuralEmbeddingApp> {
  final _DashboardController _controller = _DashboardController();

  @override
  void dispose() {
    _controller.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neural Embedding Isolate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryText,
          surface: AppColors.cardBackground,
          error: AppColors.error,
        ),
        useMaterial3: true,
      ),
      home: DashboardScreen(state: _controller.state),
    );
  }
}
