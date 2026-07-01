import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/inference_result.dart';
import '../../domain/vector_math.dart';

class ChallengeRound {
  final String target;
  final List<String> candidates;
  final int correctIndex;

  const ChallengeRound({
    required this.target,
    required this.candidates,
    required this.correctIndex,
  });
}

class SimilarityChallenge extends StatefulWidget {
  final List<InferenceResult> pool;
  final void Function(InferenceResult text)? onRequestInference;

  const SimilarityChallenge({
    super.key,
    required this.pool,
    this.onRequestInference,
  });

  @override
  State<SimilarityChallenge> createState() => _SimilarityChallengeState();
}

class _SimilarityChallengeState extends State<SimilarityChallenge> {
  static const _presets = [
    'The weather is beautiful today',
    'Machine learning models run on device',
    'I love programming in Dart',
    'Neural networks learn from data',
    'Flutter delivers smooth animations',
    'Semantic search finds similar meaning',
    'Background isolates keep UI responsive',
    'Embeddings capture text meaning',
    'On-device inference saves latency',
    'Vectors represent language in math',
  ];

  ChallengeRound? _round;
  int? _selectedIndex;
  bool _revealed = false;
  int _streak = 0;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final pool = widget.pool.where((p) => p.embedding.isNotEmpty).toList();
    if (pool.length >= 4) {
      _roundFromEmbeddings(pool);
    } else {
      _roundFromPresets();
    }
    setState(() {
      _selectedIndex = null;
      _revealed = false;
    });
  }

  void _roundFromEmbeddings(List<InferenceResult> pool) {
    final target = pool[_rand.nextInt(pool.length)];
    final others = pool.where((p) => p != target).toList()..shuffle(_rand);
    final distractors = others.take(2).toList();
    final candidates = [target.text, ...distractors.map((d) => d.text)]
      ..shuffle(_rand);
    final correctIndex = candidates.indexOf(target.text);
    _round = ChallengeRound(
      target: target.text,
      candidates: candidates,
      correctIndex: correctIndex,
    );
  }

  void _roundFromPresets() {
    final target = _presets[_rand.nextInt(_presets.length)];
    final others = _presets.where((p) => p != target).toList()..shuffle(_rand);
    final candidates = [target, others[0], others[1]]..shuffle(_rand);
    _round = ChallengeRound(
      target: target,
      candidates: candidates,
      correctIndex: candidates.indexOf(target),
    );
  }

  void _select(int index) {
    if (_revealed || _round == null) return;
    setState(() {
      _selectedIndex = index;
      _revealed = true;
      if (index == _round!.correctIndex) {
        _streak++;
      } else {
        _streak = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    if (round == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SIMILARITY CHALLENGE',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                'STREAK: $_streak',
                style: const TextStyle(
                  color: AppColors.success,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Which is most similar to:',
            style: TextStyle(
              color: AppColors.secondaryText.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '"${round.target}"',
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(round.candidates.length, (i) {
            final isCorrect = i == round.correctIndex;
            final isSelected = _selectedIndex == i;
            Color border = AppColors.borderDark;
            if (_revealed && isCorrect) border = AppColors.success;
            if (_revealed && isSelected && !isCorrect) border = AppColors.error;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _select(i),
                  borderRadius: BorderRadius.circular(AppBorders.radiusSm),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surface
                          : AppColors.background,
                      border: Border.all(
                        color: border,
                        width: isSelected ? 1.2 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(AppBorders.radiusSm),
                    ),
                    child: Text(
                      round.candidates[i],
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_revealed) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _newRound,
              child: const Text(
                'NEXT ROUND',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Builds challenge rounds from embedding pool when available.
ChallengeRound? buildChallengeFromPool(
  List<InferenceResult> pool,
  Random rand,
) {
  final valid = pool.where((p) => p.embedding.isNotEmpty).toList();
  if (valid.length < 3) return null;

  final target = valid[rand.nextInt(valid.length)];
  final scored =
      valid
          .where((p) => p != target)
          .map((p) => (p, cosineSimilarity(target.embedding, p.embedding)))
          .toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));

  if (scored.length < 2) return null;

  final correct = scored.first.$1.text;
  final distractors = scored
      .sublist(scored.length - 2)
      .map((e) => e.$1.text)
      .toList();
  final candidates = [correct, distractors[0], distractors[1]]..shuffle(rand);

  return ChallengeRound(
    target: target.text,
    candidates: candidates,
    correctIndex: candidates.indexOf(correct),
  );
}
