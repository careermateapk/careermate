import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../outreach/ui/email_compose_screen.dart';
import '../../profile/cv_parser.dart';
import '../../recruiter/posted_job.dart';
import '../job_models.dart';
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
                  if (j.skills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 1,
                      child: AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Skills this job mentions', style: AppTheme.display(context, size: 15)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            for (final s in match.matchedSkills) StatusChip(CvParser.prettySkill(s), tone: ChipTone.positive),
                            for (final s in match.missingSkills) StatusChip('${CvParser.prettySkill(s)} · not shown in CV', tone: ChipTone.warning),
                          ]),
                        ]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FadeSlideIn(index: 2, child: _Authenticity(job: j)),
                  if (j.snippet.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FadeSlideIn(
                      index: 3,
                      child: AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('About the job', style: AppTheme.display(context, size: 15)),
                          const SizedBox(height: 8),
                          Text('${j.snippet}${j.snippet.length >= 400 ? '…' : ''}', style: const TextStyle(color: AppColors.textBody, height: 1.5)),
                          const SizedBox(height: 6),
                          const Text('Read the full description on the job page.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ]),
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
                    onPressed: () => openEmailComposer(context, match),
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Email'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _open(context, j.url),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(j.official ? 'Apply on site' : 'View on ${j.sourceName}', maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _Authenticity extends StatelessWidget {
  const _Authenticity({required this.job});
  final JobItem job;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon, color) = job.scamFlags.isNotEmpty
        ? ('Suspicious indicators found', ChipTone.risk, Icons.gpp_bad_outlined, AppColors.red)
        : job.isCareerMate
            ? ('Verified recruiter', ChipTone.positive, Icons.verified_user_outlined, AppColors.green)
            : job.official
            ? ('Official source confirmed', ChipTone.positive, Icons.verified_user_outlined, AppColors.green)
            : ('Needs further verification', ChipTone.warning, Icons.shield_outlined, AppColors.amber);
    final checked = job.lastChecked;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('Authenticity check', style: AppTheme.display(context, size: 15))),
          StatusChip(label, tone: tone),
        ]),
        const SizedBox(height: 10),
        if (job.isCareerMate)
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
