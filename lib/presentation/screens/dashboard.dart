import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/inference_result.dart';
import '../../domain/isolate_message.dart';
import '../../domain/vector_math.dart';
import '../generative/layout_engine.dart';
import '../state/ml_state.dart';
import '../widgets/embedding_space_map.dart';
import '../widgets/isolate_lane_monitor.dart';
import '../widgets/minimal_animations.dart';
import '../widgets/pipeline_theater.dart';
import '../widgets/similarity_challenge.dart';
import '../widgets/similarity_matrix.dart';
import '../widgets/similarity_tree_graph.dart';
import '../widgets/vector_detail_panel.dart';

enum _CatalogViewMode { list, tree, map, matrix, challenge, generative }

class DashboardScreen extends StatefulWidget {
  final MlState state;

  const DashboardScreen({super.key, required this.state});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _compareController = TextEditingController();
  final TextEditingController _intentController = TextEditingController();
  bool _activeDetailExpanded = false;
  final Set<int> _expandedHistoryIds = {};
  _CatalogViewMode _catalogViewMode = _CatalogViewMode.list;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.initialize();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _compareController.dispose();
    _intentController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _inputController.text;
    if (text.trim().isNotEmpty) {
      setState(() => _activeDetailExpanded = false);
      widget.state.processText(text);
      _inputController.clear();
    }
  }

  void _handleCompareSubmit() {
    final text = _compareController.text;
    if (text.trim().isEmpty) return;
    widget.state.processText(text);
    _compareController.clear();
  }

  void _handleIntentSubmit() {
    final intent = _intentController.text;
    if (intent.trim().isEmpty) return;
    widget.state.matchGenerativeIntent(intent);
    setState(() => _catalogViewMode = _CatalogViewMode.generative);
  }

  void _toggleHistoryExpanded(int id) {
    setState(() {
      if (_expandedHistoryIds.contains(id)) {
        _expandedHistoryIds.remove(id);
      } else {
        _expandedHistoryIds.add(id);
      }
    });
  }

  static const double _wideLayoutBreakpoint = 800;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.state,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
                final workspace = _buildWorkspacePanel(isWide: isWide);
                final catalog = _buildCatalogPanel();

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(flex: 3, child: workspace),
                      Expanded(flex: 2, child: catalog),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(flex: 3, child: workspace),
                    Expanded(flex: 2, child: catalog),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildWorkspacePanel({required bool isWide}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: isWide
            ? const Border(right: AppBorders.thinSide)
            : const Border(bottom: AppBorders.thinSide),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.md),
                  _buildStatusPanel(),
                  const SizedBox(height: AppSpacing.md),
                  IsolateLaneMonitor(
                    timeline: widget.state.laneTimeline,
                    isProcessing: widget.state.isProcessing,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PipelineTheater(
                    isProcessing: widget.state.isProcessing,
                    activeStage: widget.state.activePipelineStage,
                    tokens: widget.state.pipelineTokens,
                    stageDetail: widget.state.pipelineDetail,
                    l2Norm: widget.state.pipelineL2Norm,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildInputArea(),
                  const SizedBox(height: AppSpacing.sm),
                  _buildCompareInputArea(),
                  if (widget.state.isProcessing) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const MinimalLoadingIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildActiveResult()),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel() {
    final history = widget.state.history;

    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'VECTOR CATALOG & LEARNING',
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(
                child: _CatalogViewToggle(
                  mode: _catalogViewMode,
                  onChanged: (mode) => setState(() => _catalogViewMode = mode),
                ),
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _expandedHistoryIds.clear();
                      _catalogViewMode = _CatalogViewMode.list;
                    });
                    widget.state.clearHistory();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'CLEAR',
                    style: TextStyle(
                      color: AppColors.error,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_catalogViewMode == _CatalogViewMode.generative) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildIntentInput(),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildCatalogContent(history)),
        ],
      ),
    );
  }

  Widget _buildCatalogContent(List<InferenceResult> history) {
    switch (_catalogViewMode) {
      case _CatalogViewMode.list:
        if (history.isEmpty) return _emptyCatalog();
        return _buildHistoryList();
      case _CatalogViewMode.tree:
        if (history.isEmpty) return _emptyCatalog();
        return SimilarityTreeGraph(
          history: history,
          activeResult: widget.state.activeResult,
        );
      case _CatalogViewMode.map:
        return EmbeddingSpaceMap(
          history: history,
          activeResult: widget.state.activeResult,
        );
      case _CatalogViewMode.matrix:
        return SimilarityMatrix(history: history);
      case _CatalogViewMode.challenge:
        return SimilarityChallenge(
          pool: history,
          onRequestInference: (r) => widget.state.processText(r.text),
        );
      case _CatalogViewMode.generative:
        return GenerativeHydrationInspector(
          schema: widget.state.generativeSchema,
          intentText: _intentController.text,
        );
    }
  }

  Widget _emptyCatalog() {
    return const Center(
      child: Text(
        'CATALOG EMPTY',
        style: TextStyle(
          color: AppColors.mutedText,
          fontFamily: 'monospace',
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildIntentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _intentController,
            style: const TextStyle(color: AppColors.primaryText, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'DESCRIBE INTENT (e.g. compare similarity)...',
              hintStyle: const TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 8,
              ),
              filled: true,
              fillColor: AppColors.background,
              enabledBorder: AppBorders.inputBorder,
              focusedBorder: AppBorders.inputFocusedBorder,
            ),
            onSubmitted: (_) => _handleIntentSubmit(),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(
          onPressed: _handleIntentSubmit,
          child: const Text(
            'HYDRATE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEURAL EMBEDDING ISOLATE',
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'On-device tensor projection with background Dart Isolate threads.',
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    final status = widget.state.status;
    final message = widget.state.statusMessage;

    final Color dotColor = switch (status) {
      WorkerState.uninitialized => AppColors.mutedText,
      WorkerState.initializing => Colors.amber,
      WorkerState.ready => AppColors.success,
      WorkerState.error => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppBorders.radiusSm),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: Row(
        children: [
          PulsingStatusIndicator(color: dotColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message.toUpperCase(),
              style: TextStyle(
                color: dotColor,
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (status == WorkerState.error ||
              status == WorkerState.uninitialized)
            TextButton(
              onPressed: widget.state.initialize,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'RETRY',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isReady =
        widget.state.status == WorkerState.ready && !widget.state.isProcessing;

    final textField = TextField(
      controller: _inputController,
      enabled: isReady,
      maxLines: 1,
      style: const TextStyle(color: AppColors.primaryText, fontSize: 14),
      decoration: InputDecoration(
        hintText: isReady ? 'ENTER TEXT TO PROJECT...' : 'ISOLATE BUSY...',
        hintStyle: const TextStyle(
          color: AppColors.mutedText,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12.0,
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        enabledBorder: AppBorders.inputBorder,
        focusedBorder: AppBorders.inputFocusedBorder,
        disabledBorder: AppBorders.inputBorder,
      ),
      onSubmitted: (_) => _handleSubmit(),
    );

    final inferButton = SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: isReady ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryText,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.mutedText,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorders.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        child: const Text(
          'INFER',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textField,
              const SizedBox(height: AppSpacing.sm),
              inferButton,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: textField),
            const SizedBox(width: AppSpacing.sm),
            inferButton,
          ],
        );
      },
    );
  }

  Widget _buildCompareInputArea() {
    final isReady =
        widget.state.status == WorkerState.ready && !widget.state.isProcessing;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _compareController,
            enabled: isReady,
            style: const TextStyle(color: AppColors.primaryText, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'COMPARE: SECOND TEXT...',
              hintStyle: const TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              filled: true,
              fillColor: AppColors.background,
              enabledBorder: AppBorders.inputBorder,
              focusedBorder: AppBorders.inputFocusedBorder,
              disabledBorder: AppBorders.inputBorder,
            ),
            onSubmitted: (_) => _handleCompareSubmit(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: isReady ? _handleCompareSubmit : null,
          child: const Text(
            'COMPARE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveResult() {
    final active = widget.state.activeResult;
    if (active == null) {
      return const Align(
        alignment: Alignment.center,
        child: Text(
          'AWAITING INPUT SEQUENCE',
          style: TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 1.0,
          ),
        ),
      );
    }

    final history = widget.state.history;
    List<double>? compareEmbedding;
    if (history.length > 1) {
      final other = history.firstWhere(
        (h) => h != active && h.embedding.isNotEmpty,
        orElse: () => active,
      );
      if (other != active) compareEmbedding = other.embedding;
    }

    return SingleChildScrollView(
      child: VectorDetailPanel(
        result: active,
        expanded: _activeDetailExpanded,
        headerLabel: 'ACTIVE PROJECTION METRICS',
        similarityToActive: active.hasError ? null : 1.0,
        compareEmbedding: compareEmbedding,
        onToggle: () =>
            setState(() => _activeDetailExpanded = !_activeDetailExpanded),
      ),
    );
  }

  Widget _buildHistoryList() {
    final history = widget.state.history;
    final active = widget.state.activeResult;

    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = history[index];
        final itemId = identityHashCode(item);

        return VectorDetailPanel(
          result: item,
          expanded: _expandedHistoryIds.contains(itemId),
          headerLabel: 'VECTOR #${history.length - index}',
          similarityToActive: similarityToActive(
            item,
            active,
            widget.state.similarities,
          ),
          onToggle: () => _toggleHistoryExpanded(itemId),
        );
      },
    );
  }
}

class _CatalogViewToggle extends StatelessWidget {
  final _CatalogViewMode mode;
  final ValueChanged<_CatalogViewMode> onChanged;

  const _CatalogViewToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.borderDark),
          borderRadius: BorderRadius.circular(AppBorders.radiusSm / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              (_CatalogViewMode.list, 'LIST'),
              (_CatalogViewMode.tree, 'TREE'),
              (_CatalogViewMode.map, 'MAP'),
              (_CatalogViewMode.matrix, 'MATRIX'),
              (_CatalogViewMode.challenge, 'QUIZ'),
              (_CatalogViewMode.generative, 'GEN'),
            ])
              _ToggleChip(
                label: entry.$2,
                selected: mode == entry.$1,
                onTap: () => onChanged(entry.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryText : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorders.radiusSm / 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
