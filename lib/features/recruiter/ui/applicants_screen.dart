import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../outreach/email_service.dart';
import '../../profile/cv_parser.dart';
import '../posted_job.dart';
import 'slot_picker.dart';

const _tabs = [('new', 'New'), ('shortlisted', 'Shortlisted'), ('interview', 'Interview'), ('rejected', 'Rejected')];

class ApplicantsScreen extends ConsumerStatefulWidget {
  const ApplicantsScreen({super.key, required this.job});
  final PostedJob job;

  @override
  ConsumerState<ApplicantsScreen> createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends ConsumerState<ApplicantsScreen> {
  String _tab = 'new';

  Future<void> _setStatus(Application a, String status) async {
    try {
      await ref.read(recruiterRepositoryProvider).setApplicationStatus(widget.job.id, a.seekerUid, status);
      if (mounted) showMessage(context, '${a.name.isEmpty ? 'Candidate' : a.name} moved to ${_tabs.firstWhere((t) => t.$1 == status).$2}.');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not update. Check your internet and try again.', error: true);
    }
  }

  Future<void> _jobAction(String action) async {
    final repo = ref.read(recruiterRepositoryProvider);
    switch (action) {
      case 'edit':
        final mine = ref.read(myPostedJobsProvider).value ?? const <PostedJob>[];
        context.push(Routes.recruiterPost, extra: mine.firstWhere((j) => j.id == widget.job.id, orElse: () => widget.job));
      case 'close':
        await repo.setStatus(widget.job.id, 'closed');
        if (mounted) showMessage(context, 'Job closed. Job seekers no longer see it.');
      case 'reopen':
        await repo.setStatus(widget.job.id, 'live');
        if (mounted) showMessage(context, 'Job is live again.');
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Delete this job?'),
            content: const Text('The job and all its applications will be permanently deleted.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await repo.delete(widget.job.id);
          if (mounted) context.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(applicationsProvider(widget.job.id));
    final all = appsAsync.value ?? const <Application>[];
    final shown = all.where((a) => a.status == _tab).toList();
    final mine = ref.watch(myPostedJobsProvider).value ?? const <PostedJob>[];
    final job = mine.firstWhere((j) => j.id == widget.job.id, orElse: () => widget.job);

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${all.length} applicants · sorted by match',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Job options',
            onSelected: _jobAction,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit job')),
              if (job.isLive) const PopupMenuItem(value: 'close', child: Text('Close job')),
              if (!job.isLive) const PopupMenuItem(value: 'reopen', child: Text('Publish / reopen')),
              const PopupMenuItem(value: 'delete', child: Text('Delete job')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final t in _tabs)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${t.$2}  ${all.where((a) => a.status == t.$1).length}'),
                        selected: _tab == t.$1,
                        onSelected: (_) => setState(() => _tab = t.$1),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              if (appsAsync.isLoading && all.isEmpty)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    const Icon(Icons.people_outline_rounded, size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text(all.isEmpty ? 'No applicants yet' : 'No one here yet', style: AppTheme.display(context, size: 17)),
                    const SizedBox(height: 4),
                    Text(
                      all.isEmpty ? 'Matching job seekers see this job at the top of their list.' : 'Move candidates here from other tabs.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ]),
                )
              else
                for (var i = 0; i < shown.length; i++) ...[
                  FadeSlideIn(
                    index: i < 8 ? i : 8,
                    child: _ApplicantCard(
                      app: shown[i],
                      job: job,
                      onStatus: (s) => _setStatus(shown[i], s),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 6),
              const Text(
                'Match uses the candidate’s confirmed CV details. A missing keyword does not mean a missing skill — review every candidate fairly. CVs arrive in your email inbox when candidates attach them.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantCard extends StatelessWidget {
  const _ApplicantCard({required this.app, required this.job, required this.onStatus});
  final Application app;
  final PostedJob job;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final color = app.score >= 70 ? AppColors.green : app.score >= 50 ? AppColors.blue : AppColors.amber;
    final tint = app.score >= 70 ? AppColors.greenTint : app.score >= 50 ? AppColors.blueTint : AppColors.amberTint;
    final jobSkills = job.skills.toSet();
    final initials = app.name.trim().isEmpty
        ? '?'
        : app.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    final ago = app.appliedAt == null ? '' : _ago(app.appliedAt!);
    return AppCard(
      onTap: () => _showDetails(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: AppColors.navy, child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.name.isEmpty ? 'Candidate' : app.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                [
                  if (app.location.isNotEmpty) app.location,
                  app.experienceYears == 0 ? 'Fresher' : '${app.experienceYears} yrs',
                  if (ago.isNotEmpty) 'applied $ago',
                ].join(' · '),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            ]),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${app.score}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
              Text('match', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 9)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in app.skills.where(jobSkills.contains).take(5)) StatusChip(CvParser.prettySkill(s), tone: ChipTone.positive),
          for (final s in jobSkills.where((s) => !app.skills.contains(s)).take(2))
            StatusChip('${CvParser.prettySkill(s)} · not in CV', tone: ChipTone.warning),
          if (app.cvEmailed) const StatusChip('CV sent to your email', tone: ChipTone.info),
          for (final b in app.badges) StatusChip('🛡️ $b', tone: ChipTone.positive),
          if (app.chosenSlot != null)
            StatusChip('Interview: ${slotText(app.chosenSlot!)}', tone: ChipTone.positive)
          else if (app.slots.isNotEmpty)
            const StatusChip('Times sent · waiting for candidate', tone: ChipTone.warning),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _showDetails(context), style: _small, child: const Text('Details'))),
          const SizedBox(width: 8),
          if (app.status != 'rejected')
            Expanded(
              child: OutlinedButton(
                onPressed: () => onStatus('rejected'),
                style: _small.copyWith(foregroundColor: const WidgetStatePropertyAll(AppColors.red)),
                child: const Text('Reject'),
              ),
            ),
          if (app.status != 'rejected') const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () async {
                if (app.status == 'shortlisted' || app.status == 'interview') {
                  final r = await pickInterviewSlots(context, initial: app.slots, info: app.slotInfo);
                  if (r == null || !context.mounted) return;
                  try {
                    await ProviderScope.containerOf(context, listen: false)
                        .read(recruiterRepositoryProvider)
                        .offerSlots(job.id, app.seekerUid, r.$1, r.$2);
                    if (context.mounted) showMessage(context, 'Interview times sent. The candidate will pick one.');
                  } catch (_) {
                    if (context.mounted) showMessage(context, 'Could not send. Update the Firebase rules, then try again.', error: true);
                  }
                  return;
                }
                onStatus(app.status == 'new' ? 'shortlisted' : 'shortlisted');
              },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: AppColors.green, padding: EdgeInsets.zero),
              child: FittedBox(
                child: Text(switch (app.status) {
                  'new' => 'Shortlist',
                  'shortlisted' => 'Interview times',
                  'interview' => app.chosenSlot == null ? 'Edit times' : 'Change time',
                  'rejected' => 'Restore',
                  _ => 'Shortlist',
                }),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  static final ButtonStyle _small = OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: EdgeInsets.zero);

  void _showDetails(BuildContext context) {
    if (app.viewedAt == null) {
      ProviderScope.containerOf(context, listen: false)
          .read(recruiterRepositoryProvider)
          .markViewed(job.id, app.seekerUid)
          .catchError((_) {});
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
          Text(app.name.isEmpty ? 'Candidate' : app.name, style: AppTheme.display(context, size: 20)),
          const SizedBox(height: 4),
          Text('${app.score}% match · ${app.experienceYears == 0 ? 'Fresher' : '${app.experienceYears} yrs experience'}',
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          _kv(Icons.mail_outline_rounded, app.email),
          if (app.phone.isNotEmpty) _kv(Icons.phone_outlined, app.phone),
          if (app.location.isNotEmpty) _kv(Icons.location_on_outlined, app.location),
          const SizedBox(height: 12),
          if (app.titles.isNotEmpty) ...[
            const Text('Job titles', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final t in app.titles) StatusChip(CvParser.prettySkill(t))]),
            const SizedBox(height: 12),
          ],
          const Text('Skills', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in app.skills) StatusChip(CvParser.prettySkill(s), tone: job.skills.contains(s) ? ChipTone.positive : ChipTone.neutral),
          ]),
          if (app.education.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Education', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(app.education.join(', ')),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              final err = await EmailService.compose(
                to: app.email,
                subject: '${job.title} at ${job.company}',
                body: 'Hi ${app.name.split(' ').first},\n\nThank you for applying for the ${job.title} role at ${job.company}. ',
              );
              if (err != null && context.mounted) showMessage(context, err, error: true);
            },
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Email candidate'),
          ),
          const SizedBox(height: 8),
          Text(app.cvEmailed ? 'The candidate emailed their CV to you — check your inbox.' : 'The candidate did not attach a CV. Ask for it by email.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  static Widget _kv(IconData i, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(i, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(v)),
        ]),
      );

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inHours < 1) return 'just now';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    return '${d.inDays} days ago';
  }
}
