import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/profile_repository.dart';
import '../skill_bank.dart';
import '../skill_repository.dart';

class SkillTestsScreen extends ConsumerWidget {
  const SkillTestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(myBadgesProvider).value ?? const {};
    final skills = (ref.watch(profileProvider).value?.skills ?? const <String>[]).map((s) => s.toLowerCase()).toSet();
    final tests = [...skillTests]..sort((a, b) {
        int rel(SkillTest t) => t.keywords.any(skills.contains) ? 0 : 1;
        return rel(a).compareTo(rel(b));
      });
    final passed = badges.values.where((b) => b.passed).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Skill tests')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF14532D), Color(0xFF166534)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(children: [
              const Text('🛡️', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$passed badge${passed == 1 ? '' : 's'} earned', style: AppTheme.display(context, size: 19, color: Colors.white)),
                  const Text('Pass a 10-question test (7/10) to show a verified skill to recruiters.',
                      style: TextStyle(color: Color(0xFFDCFCE7), fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        for (final (i, t) in tests.indexed) ...[
          FadeSlideIn(index: i + 1, child: _TestTile(test: t, result: badges[t.id], relevant: t.keywords.any(skills.contains))),
          const SizedBox(height: 10),
        ],
        const Text('Badges show the date you passed. You can retake a test after 7 days.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _TestTile extends StatelessWidget {
  const _TestTile({required this.test, required this.result, required this.relevant});
  final SkillTest test;
  final SkillResult? result;
  final bool relevant;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final locked = r != null && !r.canRetry;
    return AppCard(
      onTap: locked
          ? () => showMessage(context, 'You can retake this test on ${r.nextTry!.day}/${r.nextTry!.month}.')
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SkillQuizScreen(test: test))),
      child: Row(children: [
        Text(test.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(test.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(relevant ? 'In your CV · 10 questions · ~7 min' : '10 questions · ~7 min',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ]),
        ),
        if (r?.passed == true)
          StatusChip('🛡️ ${r!.percent}%', tone: ChipTone.positive)
        else if (r != null)
          StatusChip(locked ? 'Retry ${r.nextTry!.day}/${r.nextTry!.month}' : 'Retry', tone: ChipTone.warning)
        else
          const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}

class SkillQuizScreen extends ConsumerStatefulWidget {
  const SkillQuizScreen({super.key, required this.test});
  final SkillTest test;
  @override
  ConsumerState<SkillQuizScreen> createState() => _SkillQuizScreenState();
}

class _SkillQuizScreenState extends ConsumerState<SkillQuizScreen> {
  late final List<(SkillQuestion, List<int>)> _qs;
  int _i = 0;
  int? _picked;
  int _score = 0;
  int _left = secondsPerQuestion;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    final all = [...widget.test.questions]..shuffle(rnd);
    _qs = [
      for (final q in all.take(questionsPerTest)) (q, List<int>.generate(q.options.length, (i) => i)..shuffle(rnd)),
    ];
    _start();
  }

  void _start() {
    _timer?.cancel();
    _left = secondsPerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        _next();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _next() async {
    final (q, order) = _qs[_i];
    if (_picked != null && order[_picked!] == q.answer) _score++;
    if (_i == _qs.length - 1) {
      _timer?.cancel();
      setState(() => _done = true);
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid != null) {
        try {
          await ref.read(skillRepositoryProvider).save(uid, widget.test.id, _score, _qs.length, _score >= passMark);
        } catch (_) {
          if (mounted) showMessage(context, 'Could not save your result. Check your internet.', error: true);
        }
      }
      return;
    }
    setState(() {
      _i++;
      _picked = null;
    });
    _start();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _result(context);
    final (q, order) = _qs[_i];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Leave the test?'),
            content: const Text('Your answers so far won’t be saved.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.test.name} test'),
            const Text('Basic level · 10 questions', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ]),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (_i + 1) / _qs.length),
                  duration: AppMotion.medium,
                  builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 7),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${_i + 1} / ${_qs.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            StatusChip('⏱ 0:${_left.toString().padLeft(2, '0')}', tone: _left <= 10 ? ChipTone.risk : ChipTone.warning),
          ]),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: AppMotion.medium,
            child: Container(
              key: ValueKey(_i),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), AppColors.navy]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('QUESTION ${_i + 1}', style: const TextStyle(color: Color(0xFF9FB4E8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
                const SizedBox(height: 8),
                Text(q.q, style: AppTheme.display(context, size: 18, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          for (var k = 0; k < order.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _picked = k),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _picked == k ? AppColors.blue.withValues(alpha: 0.16) : null,
                    border: Border.all(color: _picked == k ? AppColors.blue : AppColors.border, width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _picked == k ? AppColors.blue : AppColors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(String.fromCharCode(65 + k),
                          style: TextStyle(fontWeight: FontWeight.w900, color: _picked == k ? Colors.white : AppColors.blue)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(q.options[order[k]], style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              ),
            ),
          const Text('Questions come in random order and each has a time limit.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: _picked == null ? null : _next,
            child: Text(_i == _qs.length - 1 ? 'Finish test' : 'Next question'),
          ),
        ),
      ),
    );
  }

  Widget _result(BuildContext context) {
    final pass = _score >= passMark;
    return Scaffold(
      appBar: AppBar(title: const Text('Your result')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 10),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _score / _qs.length),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => SizedBox(
              width: 160,
              height: 160,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 12,
                    color: pass ? AppColors.green : AppColors.amber,
                    backgroundColor: AppColors.line,
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$_score/${_qs.length}', style: AppTheme.display(context, size: 34)),
                  Text(pass ? 'Passed' : 'Not yet', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                ]),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (pass)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF166534), borderRadius: BorderRadius.circular(999)),
                child: Text('🛡️ Verified skill · ${widget.test.name}',
                    style: const TextStyle(color: Color(0xFFDCFCE7), fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          pass
              ? 'Great! Recruiters will see this badge on your applications.'
              : 'You need $passMark/10 to earn the badge. Revise the basics and try again in 7 days.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, height: 1.45),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
      ]),
    );
  }
}

/// Small row of badge chips, e.g. on the dashboard or an applicant card.
class BadgeChips extends StatelessWidget {
  const BadgeChips(this.labels, {super.key});
  final List<String> labels;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final l in labels) StatusChip('🛡️ $l', tone: ChipTone.positive),
      ]);
}
