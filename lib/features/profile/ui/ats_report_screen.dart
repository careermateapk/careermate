import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../ats_scorer.dart';
import '../cv_analysis.dart';
import '../profile_repository.dart';

class AtsReportScreen extends ConsumerWidget {
  const AtsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final p = profileAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CV readiness report'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go(Routes.cv)),
      ),
      body: profileAsync.isLoading && p == null
          ? const Center(child: CircularProgressIndicator())
          : (p == null || p.atsScore == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.description_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('Upload your CV to see your report.', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => context.go(Routes.cv), child: const Text('Upload CV')),
                    ]),
                  ),
                )
              : _Report(p: p),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.p});
  final CareerProfile p;

  @override
  Widget build(BuildContext context) {
    final score = p.atsScore!;
    final verdict = score >= 80 ? 'Strong' : score >= 60 ? 'Good, with room to grow' : score >= 40 ? 'Needs work' : 'Needs a lot of work';
    final ringColor = score >= 75 ? AppColors.green : score >= 50 ? AppColors.blue : AppColors.amber;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            FadeSlideIn(
              child: AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  Row(children: [
                    ScoreRing(value: score, size: 104, color: ringColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(verdict, style: AppTheme.display(context, size: 17)),
                        const SizedBox(height: 4),
                        Text(p.resumeFileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  for (final e in atsPartLabels.entries)
                    if (p.atsParts.containsKey(e.key)) _PartBar(label: e.value, score: p.atsParts[e.key]!, max: AtsScorer.weights[e.key]!),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            if (p.atsIssues.isNotEmpty) ...[
              FadeSlideIn(index: 1, child: Text('What to improve first', style: AppTheme.display(context, size: 16))),
              const SizedBox(height: 10),
              for (var i = 0; i < p.atsIssues.length; i++) ...[
                FadeSlideIn(index: i + 2, child: _IssueCard(issue: p.atsIssues[i])),
                const SizedBox(height: 10),
              ],
            ] else
              const AppCard(child: Text('No major issues found. Nice work!')),
            const SizedBox(height: 8),
            const Text(
              'This score is an estimate made by CareerMate. Every company’s hiring system works differently, and no score guarantees selection.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartBar extends StatelessWidget {
  const _PartBar({required this.label, required this.score, required this.max});
  final String label;
  final int score;
  final int max;

  @override
  Widget build(BuildContext context) {
    final r = max == 0 ? 0.0 : score / max;
    final color = r >= 0.75 ? AppColors.green : r >= 0.5 ? AppColors.blue : r >= 0.3 ? AppColors.amber : AppColors.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          Text('$score/$max', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: r),
            duration: const Duration(milliseconds: 1000),
            curve: AppMotion.curve,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 7, color: color, backgroundColor: AppColors.line),
          ),
        ),
      ]),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});
  final Map<String, String> issue;

  @override
  Widget build(BuildContext context) {
    final sev = issue['severity'] ?? 'low';
    final tone = sev == 'high' ? ChipTone.risk : sev == 'medium' ? ChipTone.warning : ChipTone.info;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatusChip(sev.toUpperCase(), tone: tone),
          const SizedBox(width: 8),
          Expanded(child: Text(issue['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        Text(issue['detail'] ?? '', style: const TextStyle(color: AppColors.textBody, height: 1.45, fontSize: 13.5)),
        if (issue['before'] != null) ...[
          const SizedBox(height: 10),
          _Example(label: 'Before', text: issue['before']!, bg: AppColors.surface, fg: AppColors.redText),
          const SizedBox(height: 6),
          _Example(label: 'Better', text: issue['after'] ?? '', bg: AppColors.greenTint, fg: AppColors.greenText),
        ],
      ]),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({required this.label, required this.text, required this.bg, required this.fg});
  final String label;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label  ', style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
          TextSpan(text: text, style: const TextStyle(color: AppColors.navy)),
        ]), style: const TextStyle(fontSize: 13, height: 1.45)),
      );
}
