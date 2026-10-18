import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jobs/women_filter.dart' show companyKey;
import '../recruiter/posted_job.dart' show findMoneyAsk;

class InterviewReport {
  InterviewReport(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  String get role => m['role'] as String? ?? '';
  int get rounds => (m['rounds'] as num?)?.toInt() ?? 0;
  int get days => (m['days'] as num?)?.toInt() ?? 0;
  String get difficulty => m['difficulty'] as String? ?? 'medium';
  String get result => m['result'] as String? ?? 'waiting';
  List<String> get questions => List<String>.from(m['questions'] as List? ?? const []);
  String get tip => m['tip'] as String? ?? '';
  int get reports => (m['reports'] as num?)?.toInt() ?? 0;
  DateTime? get at => (m['createdAt'] as Timestamp?)?.toDate();
}

final interviewReportsProvider = StreamProvider.family<List<InterviewReport>, String>((ref, company) {
  return ref
      .watch(firestoreProvider)
      .collection('interview_reports')
      .where('companyKey', isEqualTo: companyKey(company))
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map((d) => InterviewReport(d.id, d.data())).where((r) => r.reports < 3).toList()
        ..sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000))));
});

/// Removes phone numbers and emails so no one's personal details are posted.
String _scrub(String s) => s
    .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '[email removed]')
    .replaceAll(RegExp(r'(\+91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}'), '[number removed]')
    .trim();

class InterviewReportsScreen extends ConsumerWidget {
  const InterviewReportsScreen({super.key, required this.company});
  final String company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(interviewReportsProvider(company));
    final list = async.value ?? const <InterviewReport>[];
    final rounds = list.isEmpty ? 0 : (list.map((r) => r.rounds).reduce((a, b) => a + b) / list.length).round();
    final days = list.isEmpty ? 0 : (list.map((r) => r.days).reduce((a, b) => a + b) / list.length).round();
    final diffCount = {for (final d in ['easy', 'medium', 'hard']) d: list.where((r) => r.difficulty == d).length};
    final diff = list.isEmpty ? '–' : (diffCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key);
    final res = {for (final r in ['offer', 'waiting', 'rejected']) r: list.where((x) => x.result == r).length};
    final questions = [for (final r in list) ...r.questions].take(15).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Interviews at $company', maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Shared anonymously by ${list.length} ${list.length == 1 ? 'person' : 'people'}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ShareInterview(company: company))),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Share my interview'),
      ),
      body: async.isLoading && list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
              if (list.isEmpty)
                const AppCard(
                  child: Text('No one has shared an interview here yet. Been interviewed at this company? Share it to help others prepare.',
                      style: TextStyle(height: 1.45)),
                )
              else ...[
                Row(children: [
                  for (final (v, k) in [('$rounds', 'rounds'), ('$days days', 'to hear back'), (diff[0].toUpperCase() + diff.substring(1), 'difficulty')])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AppCard(
                          padding: const EdgeInsets.all(10),
                          child: Column(children: [
                            Text(v, style: AppTheme.display(context, size: 18)),
                            Text(k, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                if (questions.isNotEmpty)
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('QUESTIONS ASKED', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                      for (final q in questions)
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('“$q”', style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('HOW IT WENT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Row(children: [
                        for (final (k, c) in [('offer', AppColors.green), ('waiting', AppColors.amber), ('rejected', AppColors.red)])
                          if (res[k]! > 0) Expanded(flex: res[k]!, child: Container(height: 10, color: c)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text('🟢 Offer ${res['offer']}  🟡 Waiting ${res['waiting']}  🔴 Not selected ${res['rejected']}', style: const TextStyle(fontSize: 12.5)),
                  ]),
                ),
                const SizedBox(height: 12),
                for (final r in list) ...[
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r.role.isEmpty ? 'Interview' : r.role, style: const TextStyle(fontWeight: FontWeight.w800))),
                        StatusChip(switch (r.result) { 'offer' => 'Got offer', 'rejected' => 'Not selected', _ => 'Waiting' },
                            tone: r.result == 'offer' ? ChipTone.positive : r.result == 'rejected' ? ChipTone.risk : ChipTone.warning),
                      ]),
                      Text('${r.rounds} rounds · ${r.difficulty} · heard back in ${r.days} days',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                      if (r.tip.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Tip: ${r.tip}')),
                      Align(alignment: Alignment.centerRight, child: _ReportLink(id: r.id)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const Text('Names are never shown. Posts with money requests or personal details are removed.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
    );
  }
}

class _ReportLink extends ConsumerWidget {
  const _ReportLink({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
        onPressed: () async {
          final uid = ref.read(authStateProvider).value?.uid;
          if (uid == null) return;
          try {
            await ref.read(firestoreProvider).collection('interview_reports').doc(id).update({
              'reports': FieldValue.increment(1),
              'reportedBy': FieldValue.arrayUnion([uid]),
            });
            if (context.mounted) showMessage(context, 'Reported. Thanks!');
          } catch (_) {
            if (context.mounted) showMessage(context, 'Already reported, or you are offline.', error: true);
          }
        },
        child: const Text('Report', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
}

class _ShareInterview extends ConsumerStatefulWidget {
  const _ShareInterview({required this.company});
  final String company;
  @override
  ConsumerState<_ShareInterview> createState() => _ShareInterviewState();
}

class _ShareInterviewState extends ConsumerState<_ShareInterview> {
  final _role = TextEditingController();
  final _qs = TextEditingController();
  final _tip = TextEditingController();
  int _rounds = 2;
  int _days = 7;
  String _difficulty = 'medium';
  String _result = 'waiting';
  bool _busy = false;

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final text = '${_role.text}\n${_qs.text}\n${_tip.text}';
    if (findMoneyAsk(text) != null) {
      showMessage(context, 'Please don’t include money requests.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(firestoreProvider).collection('interview_reports').add({
        'company': widget.company,
        'companyKey': companyKey(widget.company),
        'role': _scrub(_role.text),
        'rounds': _rounds,
        'days': _days,
        'difficulty': _difficulty,
        'result': _result,
        'questions': _qs.text.split('\n').map(_scrub).where((q) => q.length > 5).take(8).toList(),
        'tip': _scrub(_tip.text),
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'reports': 0,
        'reportedBy': <String>[],
      });
      if (mounted) {
        showMessage(context, 'Shared anonymously. Thank you for helping others!');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not share. Update the Firebase rules and try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget choice<T>(String label, List<(T, String)> opts, T value, void Function(T) set) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final o in opts) ChoiceChip(label: Text(o.$2), selected: value == o.$1, onSelected: (_) => setState(() => set(o.$1))),
            ]),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: Text('Interview at ${widget.company}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        TextField(controller: _role, decoration: const InputDecoration(labelText: 'Role you interviewed for')),
        const SizedBox(height: 12),
        choice<int>('Rounds', [(1, '1'), (2, '2'), (3, '3'), (4, '4+')], _rounds, (v) => _rounds = v),
        choice<int>('Heard back in', [(2, '1–2 days'), (7, 'A week'), (14, '2 weeks'), (30, 'Month+')], _days, (v) => _days = v),
        choice<String>('Difficulty', [('easy', 'Easy'), ('medium', 'Medium'), ('hard', 'Hard')], _difficulty, (v) => _difficulty = v),
        choice<String>('Result', [('offer', 'Got offer'), ('waiting', 'Waiting'), ('rejected', 'Not selected')], _result, (v) => _result = v),
        TextField(
          controller: _qs,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Questions asked (one per line)', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        TextField(controller: _tip, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Tip for others (optional)')),
        const SizedBox(height: 10),
        const Text('Shared anonymously. Don’t include names, phone numbers or emails — we remove them anyway.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: LoadingButton(label: 'Share anonymously', loading: _busy, onPressed: _submit),
      ),
    );
  }
}
