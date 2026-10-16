import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/ats_scorer.dart';
import '../../profile/profile_repository.dart';
import '../../profile/taxonomy.dart';
import '../../tracker/tracker.dart';
import '../questions.dart';

/// Answers and checklist saved only on this phone.
class _PrepStore {
  static Future<File> _f() async => File('${(await getApplicationDocumentsDirectory()).path}/prep.json');
  static Future<Map<String, dynamic>> load() async {
    try {
      final f = await _f();
      if (await f.exists()) return Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map);
    } catch (_) {}
    return {};
  }

  static Future<void> save(Map<String, dynamic> m) async => (await _f()).writeAsString(jsonEncode(m));
}

class AnswerFeedback {
  AnswerFeedback(this.relevance, this.structure, this.evidence, this.notes);
  final double relevance, structure, evidence;
  final List<String> notes;

  /// Simple, transparent rules — not an AI judgement.
  static AnswerFeedback of(PrepQuestion q, String answer, List<String> roleSkills) {
    final a = ' ${answer.toLowerCase()} ';
    final words = RegExp(r'\S+').allMatches(answer).length;
    final kws = [...q.keywords, ...roleSkills.take(8)];
    final hits = kws.where((k) => a.contains(k.toLowerCase())).length;
    final relevance = (hits / (q.keywords.isEmpty ? 2 : (q.keywords.length * 0.6).clamp(2, 6))).clamp(0.0, 1.0);
    final situation = RegExp(r'\b(when|in my (last|previous|current) (role|job|company)|at my|during|once|last year)\b').hasMatch(a);
    final action = AtsScorer.actionVerbs.any((v) => a.contains(' $v ')) || a.contains(' i ');
    final result = RegExp(r'\b(result|so that|which|as a result|increased|reduced|saved|improved|achieved|delivered)\b|%|\d').hasMatch(a);
    final structure = q.kind == 'behavioural' || q.kind == 'role'
        ? ([situation, action, result].where((b) => b).length / 3)
        : (words >= 40 && words <= 220 ? 1.0 : words >= 20 ? 0.6 : 0.3);
    final evidence = RegExp(r'\d').hasMatch(a) ? 1.0 : (a.contains('for example') || a.contains('for instance')) ? 0.6 : 0.25;
    final notes = <String>[
      if (words < 30) 'Your answer is short (about $words words). Aim for 60–150 words, about one minute when spoken.',
      if (words > 250) 'It’s long (about $words words). Keep to the main points — around one or two minutes.',
      if (relevance < 0.5) 'Connect it more to the question: ${q.keywords.take(3).join(', ')}.',
      if ((q.kind == 'behavioural' || q.kind == 'role') && !situation) 'Start with the situation: where you were and what was happening.',
      if ((q.kind == 'behavioural' || q.kind == 'role') && !result) 'End with the result — what changed because of you.',
      if (evidence < 1) 'Add a real number (time saved, %, amount, team size). Use only figures you can prove.',
      if (!a.contains(' i ') && a.contains(' we ')) 'Say “I” for your own actions, not only “we”.',
    ];
    if (notes.isEmpty) notes.add('Clear and well-structured. Practise saying it aloud once or twice.');
    return AnswerFeedback(relevance.toDouble(), structure.toDouble(), evidence, notes);
  }
}

class InterviewPrepScreen extends ConsumerStatefulWidget {
  const InterviewPrepScreen({super.key});
  @override
  ConsumerState<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends ConsumerState<InterviewPrepScreen> {
  int _tab = 0;
  Map<String, dynamic> _store = {};

  @override
  void initState() {
    super.initState();
    _PrepStore.load().then((m) {
      if (mounted) setState(() => _store = m);
    });
  }

  Map<String, String> get _answers => Map<String, String>.from(_store['answers'] as Map? ?? {});
  Set<int> get _tipsDone => Set<int>.from(_store['tips'] as List? ?? const []);

  void _saveAnswer(String id, String text) {
    final a = _answers..[id] = text;
    _store['answers'] = a;
    _PrepStore.save(_store);
  }

  void _toggleTip(int i) {
    final t = _tipsDone;
    t.contains(i) ? t.remove(i) : t.add(i);
    setState(() => _store['tips'] = t.toList());
    _PrepStore.save(_store);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final catId = profile?.categoryId ?? (profile?.subCategoryIds.isNotEmpty == true ? categoryOfSub(profile!.subCategoryIds.first)?.id : null);
    final role = roleQuestions[catId] ?? roleQuestions['it']!;
    final practice = <PrepQuestion>[hrQuestions[0], ...role.take(3), behaviouralQuestions[0], hrQuestions[8], behaviouralQuestions[1], hrQuestions[11]];
    final skills = profile?.skills ?? const <String>[];
    final upcoming = (ref.watch(trackerProvider).value ?? const <TrackedJob>[])
        .where((t) => t.stage == Stage.interview && t.interviewAt != null && t.interviewAt!.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.interviewAt!.compareTo(b.interviewAt!));

    return Scaffold(
      appBar: AppBar(title: const Text('Interview prep')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        if (upcoming.isNotEmpty)
          FadeSlideIn(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF2F6BFF)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(Icons.event_available_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Next interview: ${upcoming.first.title}${upcoming.first.company.isEmpty ? '' : ' · ${upcoming.first.company}'} — ${_countdown(upcoming.first.interviewAt!)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
            ),
          ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.blue,
            selectedForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          ),
          segments: const [
            ButtonSegment(value: 0, label: FittedBox(child: Text('Practice', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800)))),
            ButtonSegment(value: 1, label: FittedBox(child: Text('Questions', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800)))),
            ButtonSegment(value: 2, label: FittedBox(child: Text('Tips', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w800)))),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: 14),
        if (_tab == 0)
          _Practice(
            key: ValueKey(catId),
            questions: practice,
            roleName: categoryById(catId ?? '')?.name ?? 'your field',
            skills: skills,
            answers: _answers,
            onSave: _saveAnswer,
          )
        else if (_tab == 1)
          ..._questionList(role, skills)
        else
          ..._tips(),
      ]),
    );
  }

  static String _countdown(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.inHours < 24) return 'in ${diff.inHours} h';
    return 'in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
  }

  List<Widget> _questionList(List<PrepQuestion> role, List<String> skills) {
    Widget group(String title, List<PrepQuestion> qs) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: Text(title, style: AppTheme.display(context, size: 15))),
              for (final q in qs)
                ExpansionTile(
                  shape: const Border(),
                  title: Text(q.text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  leading: Icon(_answers[q.id]?.isNotEmpty == true ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: _answers[q.id]?.isNotEmpty == true ? AppColors.green : AppColors.textMuted, size: 20),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What they look for: ${q.tip}', style: const TextStyle(fontSize: 13, height: 1.45)),
                    if (_answers[q.id]?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      const Text('YOUR ANSWER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                      Text(_answers[q.id]!, style: const TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
            ]),
          ),
        );
    return [
      group('For your field', role),
      group('HR questions', hrQuestions),
      group('Behavioural (STAR)', behaviouralQuestions),
    ];
  }

  List<Widget> _tips() => [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Before the interview', style: AppTheme.display(context, size: 15)),
            const SizedBox(height: 4),
            Text('${_tipsDone.length} of ${prepTips.length} done', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _tipsDone.length / prepTips.length, minHeight: 6),
            ),
            const SizedBox(height: 6),
            for (final (i, t) in prepTips.indexed)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _tipsDone.contains(i),
                onChanged: (_) => _toggleTip(i),
                title: Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(t.$2),
              ),
          ]),
        ),
      ];
}

class _Practice extends StatefulWidget {
  const _Practice({super.key, required this.questions, required this.roleName, required this.skills, required this.answers, required this.onSave});
  final List<PrepQuestion> questions;
  final String roleName;
  final List<String> skills;
  final Map<String, String> answers;
  final void Function(String id, String text) onSave;
  @override
  State<_Practice> createState() => _PracticeState();
}

class _PracticeState extends State<_Practice> {
  int _i = 0;
  final _ctrl = TextEditingController();
  AnswerFeedback? _fb;
  Timer? _timer;
  int _left = 120;

  PrepQuestion get _q => widget.questions[_i];

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.answers[_q.id] ?? '';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int i) {
    widget.onSave(_q.id, _ctrl.text.trim());
    _timer?.cancel();
    setState(() {
      _i = i;
      _fb = null;
      _left = 120;
      _timer = null;
      _ctrl.text = widget.answers[_q.id] ?? '';
    });
  }

  void _toggleTimer() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_left <= 0) {
          t.cancel();
          setState(() => _timer = null);
        } else {
          setState(() => _left--);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = switch (_q.kind) { 'hr' => 'HR', 'behavioural' => 'BEHAVIOURAL · USE STAR', _ => widget.roleName.toUpperCase() };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text('Mock interview · Q ${_i + 1} of ${widget.questions.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
        ),
        ActionChip(
          avatar: Icon(_timer == null ? Icons.timer_outlined : Icons.pause_rounded, size: 18),
          label: Text('${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}'),
          onPressed: _toggleTimer,
        ),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: (_i + 1) / widget.questions.length),
          duration: AppMotion.medium,
          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6),
        ),
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: AppMotion.medium,
        child: Container(
          key: ValueKey(_q.id),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navy, Color(0xFF243B7A)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kind, style: const TextStyle(color: Color(0xFF9FB4E8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
            const SizedBox(height: 8),
            Text(_q.text, style: AppTheme.display(context, size: 19, color: Colors.white)),
            const SizedBox(height: 10),
            Text(_q.tip, style: const TextStyle(color: Color(0xFFC9D3EA), fontSize: 13, height: 1.45)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _ctrl,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(
          labelText: 'Your answer',
          alignLabelWithHint: true,
          hintText: 'Type what you would say. Use your real experience — tip: speak it aloud with the timer.',
        ),
        onChanged: (_) {
          if (_fb != null) setState(() => _fb = null);
        },
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () {
                if (_ctrl.text.trim().isEmpty) {
                  showMessage(context, 'Write your answer first.', error: true);
                  return;
                }
                widget.onSave(_q.id, _ctrl.text.trim());
                setState(() => _fb = AnswerFeedback.of(_q, _ctrl.text, widget.skills));
              },
        icon: const Icon(Icons.insights_rounded),
        label: const Text('Get feedback'),
      ),
      if (_fb != null) ...[
        const SizedBox(height: 12),
        FadeSlideIn(
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Feedback on your answer', style: AppTheme.display(context, size: 15)),
              const SizedBox(height: 10),
              _bar('Relevance', _fb!.relevance),
              _bar(_q.kind == 'hr' ? 'Length & clarity' : 'STAR structure', _fb!.structure),
              _bar('Evidence', _fb!.evidence),
              const SizedBox(height: 6),
              for (final n in _fb!.notes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 17, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(n, style: const TextStyle(fontSize: 13, height: 1.4))),
                  ]),
                ),
              const SizedBox(height: 4),
              const Text('Rule-based tips from CareerMate, not a hiring decision.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _i == 0 ? null : () => _go(_i - 1), child: const Text('Previous'))),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonal(
            onPressed: _i == widget.questions.length - 1 ? () => _go(0) : () => _go(_i + 1),
            child: Text(_i == widget.questions.length - 1 ? 'Start again' : 'Next question'),
          ),
        ),
      ]),
    ]);
  }

  Widget _bar(String label, double v) {
    final c = v >= 0.75 ? AppColors.green : v >= 0.45 ? AppColors.blue : AppColors.amber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: v),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, x, _) => LinearProgressIndicator(value: x, minHeight: 8, color: c, backgroundColor: AppColors.line),
            ),
          ),
        ),
      ]),
    );
  }
}
