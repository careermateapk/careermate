import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../outreach/ui/email_compose_screen.dart';
import '../../recruiter/posted_job.dart';
import '../../community/job_post.dart';
import '../../tracker/tracker.dart';
import '../job_models.dart';
import 'about_job.dart';
import 'other_sites.dart';
import 'jobs_screen.dart' show postedText;

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.match});
  final JobMatch match;

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showMessage(context, 'Could not open the link.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final j = match.job;
    final rec = match.recommendation;
    final (recText, recColor) = switch (rec) {
      Recommendation.apply => ('Recommended: apply', AppColors.green),
      Recommendation.review => ('Review carefully', AppColors.blue),
      Recommendation.deprioritise => ('Low priority', AppColors.amber),
    };
    final salary = (j.salaryMin != null || j.salaryMax != null)
        ? '₹${_money(j.salaryMin)}${j.salaryMax != null ? ' – ₹${_money(j.salaryMax)}' : ''} a year'
        : null;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 210,
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          actions: [_SaveButton(job: j)],
          flexibleSpace: FlexibleSpaceBar(
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(j.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.display(context, size: 21, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${j.company} · ${j.location}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFC9D3EA), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (salary != null) _HeaderChip(salary),
                    if (j.employmentType != null && j.employmentType!.isNotEmpty) _HeaderChip(j.employmentType!),
                    if (j.remote) const _HeaderChip('Remote'),
                    _HeaderChip(postedText(j)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FadeSlideIn(
                    child: AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('YOUR MATCH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: .5)),
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: match.score.toDouble()),
                                duration: const Duration(milliseconds: 1100),
                                curve: AppMotion.curve,
                                builder: (context, v, _) => Text('${v.round()}%', style: AppTheme.display(context, size: 32, color: recColor)),
                              ),
                            ]),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: recColor, borderRadius: BorderRadius.circular(10)),
                            child: Text(recText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        for (final r in match.reasons) _Line(icon: Icons.check_circle_rounded, color: AppColors.green, text: r),
                        for (final c in match.concerns) _Line(icon: Icons.info_rounded, color: AppColors.amber, text: c),
                        const SizedBox(height: 4),
                        const Text('Match is an estimate based on your confirmed profile.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(index: 2, child: _Authenticity(job: j)),
                  const SizedBox(height: 12),
                  FadeSlideIn(index: 3, child: AboutJobCard(match: match)),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 4,
                    child: AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Find more like this on other sites', style: AppTheme.display(context, size: 15)),
                        const SizedBox(height: 4),
                        Text('Opens LinkedIn, Naukri, Indeed and more with “${searchRole(j.title)}” already searched.',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: OtherSitesButton(job: j)),
                      ]),
                    ),
                  ),
                  if (j.source == 'jobicy' || j.source == 'arbeitnow') ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _open(context, j.source == 'jobicy' ? 'https://jobicy.com' : 'https://www.arbeitnow.com'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(j.source == 'jobicy' ? 'Job listing from Jobicy' : 'Job listing from Arbeitnow'),
                      ),
                    ),
                  ],
                  if (j.isAdzuna) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _open(context, 'https://www.adzuna.in'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Jobs by Adzuna'),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: j.isCareerMate
            ? _CareerMateApply(match: match)
            : Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () => openEmailComposer(context, match),
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Email HR', maxLines: 1, softWrap: false)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: j.url.isEmpty
                        ? null
                        : () async {
                            await _open(context, j.url);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Applied there? Add it to your tracker.'),
                              duration: const Duration(seconds: 8),
                              action: SnackBarAction(
                                label: 'Mark applied',
                                onPressed: () => ProviderScope.containerOf(context, listen: false)
                                    .read(trackerRepositoryProvider)
                                    ?.save(TrackedJob.fromJob(j, stage: Stage.applied)),
                              ),
                            ));
                          },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(j.isCommunity ? (j.url.isEmpty ? 'No link in post' : 'Open original post') : j.official ? 'Apply on site' : 'View on ${j.sourceName}', maxLines: 1, softWrap: false),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  static String _money(num? v) {
    if (v == null) return '';
    final n = v.round();
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(n % 100000 == 0 ? 0 : 1)} L';
    return n.toString();
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
        ]),
      );
}

class _SaveButton extends ConsumerStatefulWidget {
  const _SaveButton({required this.job});
  final JobItem job;
  @override
  ConsumerState<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends ConsumerState<_SaveButton> {
  bool? _saved;

  String get _id => widget.job.isCareerMate ? widget.job.postedJobId! : widget.job.id;

  @override
  void initState() {
    super.initState();
    ref.read(trackerRepositoryProvider)?.has(_id).then((v) {
      if (mounted) setState(() => _saved = v);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: _saved == true ? 'Saved in tracker' : 'Save to tracker',
        icon: Icon(_saved == true ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
        onPressed: () async {
          final repo = ref.read(trackerRepositoryProvider);
          if (repo == null) return;
          if (_saved == true) {
            await repo.delete(_id);
          } else {
            await repo.save(TrackedJob.fromJob(widget.job));
          }
          if (!mounted) return;
          setState(() => _saved = !(_saved ?? false));
          showMessage(context, _saved! ? 'Saved to your tracker.' : 'Removed from tracker.');
        },
      );
}

class _ReportButton extends ConsumerStatefulWidget {
  const _ReportButton({required this.job});
  final JobItem job;
  @override
  ConsumerState<_ReportButton> createState() => _ReportButtonState();
}

class _ReportButtonState extends ConsumerState<_ReportButton> {
  bool _done = false;
  Future<void> _report() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report as fake?'),
        content: const Text('Report only if the job asks for money, the company doesn’t exist, or it looks like a scam.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Report')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(communityRepositoryProvider).report(widget.job.communityId!, uid);
      if (mounted) {
        setState(() => _done = true);
        showMessage(context, 'Thanks — reported.');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'You have already reported this job, or you are offline.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: _done ? null : _report,
        icon: const Icon(Icons.flag_rounded, size: 18, color: AppColors.red),
        label: Text(_done ? 'Reported' : 'Report as fake', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
      );
}

class _Authenticity extends StatelessWidget {
  const _Authenticity({required this.job});
  final JobItem job;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon, color) = job.scamFlags.isNotEmpty
        ? ('Suspicious indicators found', ChipTone.risk, Icons.gpp_bad_outlined, AppColors.red)
        : job.isCommunity
        ? ('Checks passed ${job.checksPassed}/${job.checksTotal}', job.checksPassed >= job.checksTotal - 1 ? ChipTone.positive : ChipTone.warning,
            Icons.groups_rounded, AppColors.blue)
        : job.isCareerMate
            ? ('Verified recruiter', ChipTone.positive, Icons.verified_user_outlined, AppColors.green)
            : job.official
            ? ('Official source confirmed', ChipTone.positive, Icons.verified_user_outlined, AppColors.green)
            : ('Needs further verification', ChipTone.warning, Icons.shield_outlined, AppColors.amber);
    final checked = job.lastChecked;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Authenticity check', maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: AppTheme.display(context, size: 16)),
          ),
        ]),
        const SizedBox(height: 10),
        StatusChip(label, tone: tone),
        const SizedBox(height: 10),
        if (job.isCommunity) ...[
          const _Line(icon: Icons.info_outline_rounded, color: AppColors.blue,
              text: 'Shared by a CareerMate user from a public post. We checked the email, website and warning signs, but please confirm with the company.'),
          _Line(icon: Icons.flag_outlined, color: AppColors.textMuted, text: '${job.reports} report${job.reports == 1 ? '' : 's'} so far. Jobs with 3 reports are hidden.'),
          Align(alignment: Alignment.centerLeft, child: _ReportButton(job: job)),
        ] else if (job.isCareerMate)
          const _Line(icon: Icons.check_rounded, color: AppColors.green, text: 'Posted on CareerMate by a recruiter whose company email is verified.')
        else if (job.official)
          const _Line(icon: Icons.check_rounded, color: AppColors.green, text: "Published on the company's own hiring page.")
        else
          _Line(icon: Icons.info_outline_rounded, color: AppColors.amber, text: 'Found through ${job.sourceName}. Check the job on the company’s own website before sharing documents.'),
        if (job.scamFlags.isNotEmpty)
          _Line(icon: Icons.warning_amber_rounded, color: AppColors.red, text: 'Mentions "${job.scamFlags.join('", "')}". Never pay to apply or join.'),
        _Line(
          icon: Icons.schedule_rounded,
          color: AppColors.textMuted,
          text: checked == null ? 'Live status not checked yet.' : 'Listing seen on ${checked.day}/${checked.month}/${checked.year}. It may have closed since.',
        ),
        Text('Source: ${job.sourceName}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}


/// Apply button for jobs posted on CareerMate; shows "Applied" once done.
class _CareerMateApply extends ConsumerWidget {
  const _CareerMateApply({required this.match});
  final JobMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final jobId = match.job.postedJobId!;
    return FutureBuilder<bool>(
      future: uid == null ? Future.value(false) : ref.read(recruiterRepositoryProvider).hasApplied(jobId, uid),
      builder: (context, snap) {
        final applied = snap.data ?? false;
        if (applied) {
          return FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Applied'),
          );
        }
        return FilledButton.icon(
          onPressed: () => openEmailComposer(context, match),
          icon: const Icon(Icons.send_rounded),
          label: const Text('Apply with my CV'),
        );
      },
    );
  }
}
