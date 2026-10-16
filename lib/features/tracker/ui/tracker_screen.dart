import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../tracker.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});
  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  Stage _stage = Stage.applied;

  static const _colors = {
    Stage.saved: AppColors.textMuted,
    Stage.applied: AppColors.blue,
    Stage.interview: Color(0xFF7C3AED),
    Stage.offer: AppColors.green,
    Stage.rejected: AppColors.red,
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trackerProvider);
    final all = async.value ?? const <TrackedJob>[];
    final list = all.where((t) => t.stage == _stage).toList();
    final now = DateTime.now();
    final week = now.add(const Duration(days: 7));
    final agenda = [
      for (final t in all)
        if (t.stage == Stage.interview && t.interviewAt != null && t.interviewAt!.isAfter(now.subtract(const Duration(hours: 3))) && t.interviewAt!.isBefore(week))
          (t, 'Interview', t.interviewAt!)
        else if (t.stage == Stage.applied && t.followUpAt != null && t.followUpAt!.isBefore(week))
          (t, t.followUpDue ? 'Follow up (due)' : 'Follow up', t.followUpAt!),
    ]..sort((a, b) => a.$3.compareTo(b.$3));

    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add job'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(trackerProvider),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, Color(0xFF1E3FAE)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PIPELINE · ${all.length} ROLES',
                    style: const TextStyle(color: Color(0xFFC9D3EA), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
                const SizedBox(height: 10),
                Row(children: [
                  for (final s in [Stage.saved, Stage.applied, Stage.interview, Stage.offer])
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _stage = s),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: AppMotion.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _stage == s ? Colors.white : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: all.where((t) => t.stage == s).length.toDouble()),
                              duration: const Duration(milliseconds: 700),
                              builder: (_, v, _) => Text('${v.round()}',
                                  style: AppTheme.display(context, size: 22, color: _stage == s ? AppColors.navy : Colors.white)),
                            ),
                            Text(s.label,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _stage == s ? AppColors.navy : const Color(0xFFC9D3EA))),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
          if (agenda.isNotEmpty) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('This week', style: AppTheme.display(context, size: 15)),
                  const SizedBox(height: 6),
                  for (final a in agenda.take(5))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Icon(a.$2 == 'Interview' ? Icons.event_rounded : Icons.reply_rounded,
                            size: 18, color: a.$2.contains('due') ? AppColors.red : AppColors.blue),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${a.$2} · ${a.$1.company.isEmpty ? a.$1.title : a.$1.company}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(_when(a.$3), style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final s in Stage.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${s.label} · ${all.where((t) => t.stage == s).length}'),
                    selected: _stage == s,
                    onSelected: (_) => setState(() => _stage = s),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          if (async.isLoading && all.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(children: [
                Icon(Icons.view_kanban_outlined, size: 46, color: _colors[_stage]),
                const SizedBox(height: 10),
                Text('Nothing in ${_stage.label} yet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Jobs you save, apply to or email from CareerMate appear here. You can also add any job yourself.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
              ]),
            )
          else
            for (final (i, t) in list.indexed) ...[
              FadeSlideIn(index: i < 8 ? i : 8, child: _card(context, t)),
              const SizedBox(height: 10),
            ],
        ]),
      ),
    );
  }

  static String _when(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final time = '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
    if (days < 0) return 'overdue';
    if (days == 0) return d.hour == 0 && d.minute == 0 ? 'today' : 'today $time';
    if (days == 1) return 'tomorrow';
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[d.weekday - 1]} ${d.day}/${d.month}';
  }

  Widget _card(BuildContext context, TrackedJob t) {
    final repo = ref.read(trackerRepositoryProvider);
    final info = <String>[
      if (t.company.isNotEmpty) t.company,
      if (t.appliedAt != null) 'applied ${t.appliedAt!.day}/${t.appliedAt!.month}',
      if (t.appliedAt == null && t.savedAt != null) 'saved ${t.savedAt!.day}/${t.savedAt!.month}',
    ];
    return AppCard(
      onTap: () => _edit(context, t),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: _colors[t.stage], borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(info.join(' · '), style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ]),
          ),
          PopupMenuButton<Stage>(
            tooltip: 'Move to',
            icon: const Icon(Icons.swap_horiz_rounded),
            onSelected: (s) => repo?.setStage(t, s),
            itemBuilder: (_) => [for (final s in Stage.values) if (s != t.stage) PopupMenuItem(value: s, child: Text('Move to ${s.label}'))],
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (t.fromCareerMate) StatusChip(_recruiter(t.recruiterStatus), tone: ChipTone.info),
          if (t.source == 'email') const StatusChip('Emailed HR', tone: ChipTone.info),
          if (t.stage == Stage.interview && t.interviewAt != null) StatusChip('Interview ${_when(t.interviewAt!)}', tone: ChipTone.positive),
          if (t.followUpDue) const StatusChip('Follow up overdue', tone: ChipTone.risk)
          else if (t.stage == Stage.applied && t.followUpAt != null) StatusChip('Follow up ${_when(t.followUpAt!)}'),
          if (t.notes.isNotEmpty) const StatusChip('Notes'),
        ]),
        if (t.followUpDue || t.url.isNotEmpty || t.contactEmail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (t.followUpDue)
              TextButton.icon(
                onPressed: () {
                  t.followUpAt = DateTime.now().add(const Duration(days: 7));
                  repo?.save(t);
                  showMessage(context, 'Next follow-up reminder in 7 days.');
                },
                icon: const Icon(Icons.done_rounded, size: 18),
                label: const Text('Followed up'),
              ),
            if (t.contactEmail.isNotEmpty)
              TextButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'mailto', path: t.contactEmail, query: 'subject=${Uri.encodeComponent('Following up: ${t.title}')}')),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Email'),
              ),
            if (t.url.isNotEmpty)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(t.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open'),
              ),
          ]),
        ],
      ]),
    );
  }

  static String _recruiter(String? s) => switch (s) {
        'shortlisted' => 'Recruiter: shortlisted',
        'interview' => 'Recruiter: interview',
        'rejected' => 'Recruiter: not selected',
        _ => 'Applied on CareerMate',
      };

  Future<void> _edit(BuildContext context, TrackedJob? existing) async {
    final repo = ref.read(trackerRepositoryProvider);
    if (repo == null) return;
    final t = existing ??
        TrackedJob(id: 'm${DateTime.now().millisecondsSinceEpoch}', title: '', company: '', stage: _stage == Stage.rejected ? Stage.applied : _stage, savedAt: DateTime.now());
    final title = TextEditingController(text: t.title);
    final company = TextEditingController(text: t.company);
    final url = TextEditingController(text: t.url);
    final email = TextEditingController(text: t.contactEmail);
    final notes = TextEditingController(text: t.notes);
    var stage = t.stage;
    var interviewAt = t.interviewAt;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(existing == null ? 'Add a job' : 'Edit job', style: AppTheme.display(ctx, size: 19)),
              const SizedBox(height: 12),
              TextField(controller: title, enabled: !t.fromCareerMate, decoration: const InputDecoration(labelText: 'Job title')),
              const SizedBox(height: 10),
              TextField(controller: company, enabled: !t.fromCareerMate, decoration: const InputDecoration(labelText: 'Company')),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in Stage.values)
                  ChoiceChip(label: Text(s.label), selected: stage == s, onSelected: (_) => setS(() => stage = s)),
              ]),
              if (stage == Stage.interview) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_rounded),
                  label: Text(interviewAt == null ? 'Set interview date & time' : 'Interview: ${_when(interviewAt!)}'),
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: ctx, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 365)), initialDate: interviewAt ?? now);
                    if (d == null || !ctx.mounted) return;
                    final time = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 11, minute: 0));
                    setS(() => interviewAt = DateTime(d.year, d.month, d.day, time?.hour ?? 11, time?.minute ?? 0));
                  },
                ),
              ],
              const SizedBox(height: 10),
              TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Job link (optional)')),
              const SizedBox(height: 10),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'HR email (optional)')),
              const SizedBox(height: 10),
              TextField(controller: notes, minLines: 2, maxLines: 6, decoration: const InputDecoration(labelText: 'Notes', hintText: 'Who you spoke to, salary discussed, next steps…')),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
              if (existing != null && !existing.fromCareerMate)
                TextButton(
                  onPressed: () async {
                    await repo.delete(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx, false);
                  },
                  child: const Text('Remove from tracker', style: TextStyle(color: AppColors.red)),
                ),
            ]),
          ),
        ),
      ),
    );
    if (saved != true) return;
    if (title.text.trim().isEmpty) {
      if (context.mounted) showMessage(context, 'Add a job title.', error: true);
      return;
    }
    t
      ..title = title.text.trim()
      ..company = company.text.trim()
      ..url = url.text.trim()
      ..contactEmail = email.text.trim()
      ..notes = notes.text.trim()
      ..interviewAt = interviewAt;
    await repo.setStage(t, stage);
    if (mounted) setState(() => _stage = stage);
  }
}
