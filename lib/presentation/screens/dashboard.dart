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
import '../widgets/similarity_matrix.dart';
import '../widgets/vector_detail_panel.dart';

enum _CatalogViewMode { list, map, matrix, generative }

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
  final TextEditingController _layoutIntentController = TextEditingController();
  final ScrollController _workspaceToolsScrollController = ScrollController();
  bool _activeDetailExpanded = false;
  bool _catalogMinimized = false;
  bool _dismissedSuggestion = false;
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
    _layoutIntentController.dispose();
    _workspaceToolsScrollController.dispose();
    super.dispose();
  }

  void _clearCatalog() {
    setState(() {
      _expandedHistoryIds.clear();
      _catalogViewMode = _CatalogViewMode.list;
    });
    widget.state.clearHistory();
  }

  void _toggleCatalogMinimized() {
    setState(() => _catalogMinimized = !_catalogMinimized);
  }

  void _handleSubmit() {
    final text = _inputController.text;
    if (text.trim().isNotEmpty) {
      setState(() {
        _activeDetailExpanded = false;
        _dismissedSuggestion = false;
      });
      final layoutIntent = _layoutIntentController.text.trim();
      widget.state.processText(
        text,
        layoutIntent: layoutIntent.isNotEmpty ? layoutIntent : null,
      );
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

  void _applySuggestion(String description) {
    _intentController.text = description;
    widget.state.matchGenerativeIntent(description);
    setState(() {
      _catalogViewMode = _CatalogViewMode.generative;
      _dismissedSuggestion = true;
    });
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
                final catalog = _buildCatalogPanel(isWide: isWide);

                if (_catalogMinimized) {
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(child: workspace),
                        _buildCatalogMinimizedRail(isWide: true),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: workspace),
                      _buildCatalogMinimizedRail(isWide: false),
                    ],
                  );
                }

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
    final hasActiveResult = widget.state.activeResult != null;
    final toolsFlex = hasActiveResult ? 2 : 3;
    final resultFlex = hasActiveResult ? 3 : 1;

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
          _buildHeader(),
          const SizedBox(height: AppSpacing.md),
          _buildStatusPanel(),
          const SizedBox(height: AppSpacing.md),
          _buildPrimaryInputFields(),
          const SizedBox(height: AppSpacing.sm),
          _buildInferButton(),
          const SizedBox(height: AppSpacing.sm),
          _buildCompareInputArea(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            flex: toolsFlex,
            child: Semantics(
              identifier: 'workspace_tools_scroll',
              child: SingleChildScrollView(
                controller: _workspaceToolsScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.state.isProcessing) ...[
                      const MinimalLoadingIndicator(),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _buildSuggestedLayoutChip(),
                    const SizedBox(height: AppSpacing.md),
                    PipelineTheater(
                      isProcessing: widget.state.isProcessing,
                      activeStage: widget.state.activePipelineStage,
                      tokens: widget.state.pipelineTokens,
                      stageDetail: widget.state.pipelineDetail,
                      l2Norm: widget.state.pipelineL2Norm,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    IsolateLaneMonitor(
                      timeline: widget.state.laneTimeline,
                      isProcessing: widget.state.isProcessing,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(flex: resultFlex, child: _buildActiveResult()),
        ],
      ),
    );
  }

  Widget _buildCatalogMinimizedRail({required bool isWide}) {
    final count = widget.state.history.length;

    return Material(
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: _toggleCatalogMinimized,
        child: Container(
          width: isWide ? 44 : double.infinity,
          height: isWide ? double.infinity : 44,
          decoration: BoxDecoration(
            border: isWide
                ? const Border(left: AppBorders.thinSide)
                : const Border(top: AppBorders.thinSide),
          ),
          alignment: Alignment.center,
          child: RotatedBox(
            quarterTurns: isWide ? 1 : 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWide ? Icons.chevron_left : Icons.expand_less,
                  color: AppColors.mutedText,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'CATALOG${count > 0 ? ' ($count)' : ''}',
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogPanel({required bool isWide}) {
    final history = widget.state.history;

    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCatalogHeader(history: history, isWide: isWide),
          if (_catalogViewMode == _CatalogViewMode.generative) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildIntentInput(),
            if (widget.state.schemaStream.persistedSchemas.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => widget.state.rehydratePreviousSchema(),
                  child: const Text(
                    'REHYDRATE PREVIOUS',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 9),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildCatalogContent(history)),
        ],
      ),
    );
  }

  Widget _buildCatalogHeader({
    required List<InferenceResult> history,
    required bool isWide,
  }) {
    final title = const Text(
      'VECTOR CATALOG & LEARNING',
      style: TextStyle(
        color: AppColors.primaryText,
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
      overflow: TextOverflow.ellipsis,
    );
    final minimize = _CatalogMinimizeButton(
      minimized: _catalogMinimized,
      isWide: isWide,
      onPressed: _toggleCatalogMinimized,
    );
    final toggle = _CatalogViewToggle(
      mode: _catalogViewMode,
      onChanged: (mode) => setState(() => _catalogViewMode = mode),
    );
    final clear = history.isEmpty
        ? null
        : TextButton(
            onPressed: _clearCatalog,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Semantics(
              identifier: 'catalog_clear_button',
              button: true,
              label: 'CLEAR',
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
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = !isWide || constraints.maxWidth < 520;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: title),
                  minimize,
                  ?clear,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              toggle,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            minimize,
            const SizedBox(width: AppSpacing.xs),
            Flexible(child: toggle),
            if (clear != null) ...[const SizedBox(width: AppSpacing.sm), clear],
          ],
        );
      },
    );
  }

  Widget _buildCatalogContent(List<InferenceResult> history) {
    switch (_catalogViewMode) {
      case _CatalogViewMode.list:
        if (history.isEmpty) return _emptyCatalog();
        return _buildHistoryList();
      case _CatalogViewMode.map:
        return EmbeddingSpaceMap(
          history: history,
          activeResult: widget.state.activeResult,
          onPointSelected: widget.state.selectActiveResult,
        );
      case _CatalogViewMode.matrix:
        return SimilarityMatrix(history: history);
      case _CatalogViewMode.generative:
        return GenerativeHydrationInspector(
          schema: widget.state.generativeSchema,
          intentText: _intentController.text.isNotEmpty
              ? _intentController.text
              : widget.state.lastIntentText,
          generativeContext: widget.state.buildGenerativeContext(
            onSelectResult: widget.state.selectActiveResult,
          ),
          suggestions: widget.state.generativeSchema == null
              ? widget.state.routerSuggestions
              : widget.state.intentPreview,
          validationErrors: widget.state.schemaValidationErrors,
          onSuggestionTap: widget.state.routerSuggestions.isNotEmpty
              ? _applySuggestion
              : null,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                identifier: 'intent_input',
                textField: true,
                child: TextField(
                  controller: _intentController,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 12,
                  ),
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
                  onChanged: widget.state.previewIntent,
                  onSubmitted: (_) => _handleIntentSubmit(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: _handleIntentSubmit,
              child: Semantics(
                identifier: 'hydrate_button',
                button: true,
                label: 'HYDRATE',
                child: const Text(
                  'HYDRATE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.state.isRoutingIntent)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'ROUTING INTENT…',
              style: TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 9,
              ),
            ),
          )
        else if (widget.state.intentPreview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Wrap(
              spacing: AppSpacing.xs,
              children: widget.state.intentPreview.map((s) {
                return ActionChip(
                  label: Text(
                    '${s.templateId} (${(s.score * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 8,
                    ),
                  ),
                  backgroundColor: AppColors.background,
                  side: const BorderSide(color: AppColors.borderDark),
                  onPressed: () => _applySuggestion(s.description),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            SizedBox(
              height: 28,
              child: Switch(
                value: widget.state.autoHydrate,
                onChanged: widget.state.setAutoHydrate,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Text(
              'AUTO-HYDRATE AFTER INFER',
              style: TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuggestedLayoutChip() {
    final suggestion = widget.state.suggestedLayout;
    if (suggestion == null || _dismissedSuggestion) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppBorders.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderLight),
          borderRadius: BorderRadius.circular(AppBorders.radiusSm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'SUGGESTED: ${suggestion.templateId} (${(suggestion.score * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontFamily: 'monospace',
                  fontSize: 9,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => _applySuggestion(suggestion.description),
              child: const Text(
                'APPLY',
                style: TextStyle(fontFamily: 'monospace', fontSize: 9),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.close,
                size: 14,
                color: AppColors.mutedText,
              ),
              onPressed: () => setState(() => _dismissedSuggestion = true),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEURAL EMBEDDING ISOLATE',
          key: Key('dashboard_title'),
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

    return Semantics(
      identifier: 'status_panel',
      container: true,
      child: Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Semantics(
                  identifier: 'worker_retry_button',
                  button: true,
                  label: 'RETRY',
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryInputFields() {
    final isReady =
        widget.state.status == WorkerState.ready && !widget.state.isProcessing;

    final textField = Semantics(
      identifier: 'main_input',
      textField: true,
      child: TextField(
        controller: _inputController,
        enabled: isReady,
        maxLines: 1,
        textInputAction: TextInputAction.done,
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
      ),
    );

    final layoutIntentField = Semantics(
      identifier: 'layout_intent_input',
      textField: true,
      child: TextField(
        controller: _layoutIntentController,
        enabled: isReady,
        style: const TextStyle(color: AppColors.primaryText, fontSize: 11),
        decoration: InputDecoration(
          hintText: 'OPTIONAL LAYOUT INTENT (e.g. compare)…',
          hintStyle: const TextStyle(
            color: AppColors.mutedText,
            fontFamily: 'monospace',
            fontSize: 10,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          filled: true,
          fillColor: AppColors.background,
          enabledBorder: AppBorders.inputBorder,
          focusedBorder: AppBorders.inputFocusedBorder,
          disabledBorder: AppBorders.inputBorder,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        textField,
        const SizedBox(height: AppSpacing.xs),
        layoutIntentField,
      ],
    );
  }

  Widget _buildInferButton() {
    final isReady =
        widget.state.status == WorkerState.ready && !widget.state.isProcessing;

    return SizedBox(
      width: double.infinity,
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
        child: Semantics(
          identifier: 'infer_button',
          button: true,
          label: 'INFER',
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
      ),
    );
  }

  Widget _buildCompareInputArea() {
    final isReady =
        widget.state.status == WorkerState.ready && !widget.state.isProcessing;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            identifier: 'compare_input',
            textField: true,
            child: TextField(
              controller: _compareController,
              enabled: isReady,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 12,
              ),
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
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: isReady ? _handleCompareSubmit : null,
          child: Semantics(
            identifier: 'compare_button',
            button: true,
            label: 'COMPARE',
            child: const Text(
              'COMPARE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
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
        semanticsIdentifier: 'active_vector_detail',
        toggleSemanticsIdentifier: 'active_vector_detail_toggle',
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

        return Semantics(
          identifier: index == 0 ? 'catalog_history_item' : null,
          container: true,
          child: VectorDetailPanel(
            result: item,
            expanded: _expandedHistoryIds.contains(itemId),
            headerLabel: 'VECTOR #${history.length - index}',
            toggleSemanticsIdentifier: index == 0
                ? 'catalog_history_item_toggle'
                : null,
            similarityToActive: similarityToActive(
              item,
              active,
              widget.state.similarities,
            ),
            onToggle: () => _toggleHistoryExpanded(itemId),
          ),
        );
      },
    );
  }
}

class _CatalogMinimizeButton extends StatelessWidget {
  final bool minimized;
  final bool isWide;
  final VoidCallback onPressed;

  const _CatalogMinimizeButton({
    required this.minimized,
    required this.isWide,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Semantics(
        identifier: 'catalog_minimize_button',
        button: true,
        label: minimized ? 'SHOW' : 'MIN',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWide ? Icons.chevron_right : Icons.expand_more,
              color: AppColors.mutedText,
              size: 16,
            ),
            const SizedBox(width: 2),
            Text(
              minimized ? 'SHOW' : 'MIN',
              style: const TextStyle(
                color: AppColors.mutedText,
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
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
              (_CatalogViewMode.map, 'MAP'),
              (_CatalogViewMode.matrix, 'MATRIX'),
              (_CatalogViewMode.generative, 'GEN'),
            ])
              _ToggleChip(
                label: entry.$2,
                identifier: 'catalog_view_${entry.$2.toLowerCase()}',
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
  final String identifier;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.identifier,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        identifier: identifier,
        button: true,
        selected: selected,
        label: label,
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
      ),
    );
  }
}
