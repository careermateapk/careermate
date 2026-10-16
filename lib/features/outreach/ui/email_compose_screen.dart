import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../cv/local_cv.dart';
import '../../jobs/job_models.dart';
import '../../profile/cv_parser.dart';
import '../../profile/profile_repository.dart';
import '../../recruiter/posted_job.dart';
import '../email_service.dart';

class EmailDraftArgs {
  const EmailDraftArgs({required this.match});
  final JobMatch match;
}

/// Writes an email to the recruiter from the user's confirmed profile and
/// opens Gmail with the CV attached from this phone. The user presses Send.
/// For jobs posted on CareerMate this also saves the application.
class EmailComposeScreen extends ConsumerStatefulWidget {
  const EmailComposeScreen({super.key, required this.args});
  final EmailDraftArgs args;

  @override
  ConsumerState<EmailComposeScreen> createState() => _EmailComposeScreenState();
}

class _EmailComposeScreenState extends ConsumerState<EmailComposeScreen> {
  late final TextEditingController _to, _subject, _body;
  bool _attach = true;
  bool _busy = false;

  JobItem get _job => widget.args.match.job;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider).value ?? CareerProfile();
    _to = TextEditingController(text: _job.contactEmail);
    _subject = TextEditingController(text: '${_job.title} role — ${p.name.isEmpty ? 'application' : p.name}');
    _body = TextEditingController(text: _draft(p));
  }

  @override
  void dispose() {
    _to.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Uses only facts from the confirmed profile — nothing invented.
  String _draft(CareerProfile p) {
    final matched = widget.args.match.matchedSkills.take(3).map(CvParser.prettySkill).toList();
    final skills = matched.isNotEmpty ? matched : p.skills.take(3).map(CvParser.prettySkill).toList();
    final where = _job.isCareerMate ? 'on CareerMate' : (_job.official ? 'on your careers page' : 'online');
    final exp = p.experienceYears >= 1
        ? 'I have ${p.experienceYears % 1 == 0 ? p.experienceYears.toInt() : p.experienceYears} years of experience'
        : 'I am a fresher';
    final skillText = skills.isEmpty ? '' : ' with skills in ${_join(skills)}';
    final edu = p.education.isEmpty ? '' : ' I hold a ${p.education.first}.';
    final sign = [p.name, p.phone, p.location].where((s) => s.trim().isNotEmpty).join('\n');
    return 'Dear Hiring Team,\n\n'
        'I saw the ${_job.title} opening at ${_job.company.isEmpty ? 'your company' : _job.company} $where. '
        '$exp$skillText.$edu\n\n'
        'My CV is attached. I would welcome a short call to discuss the role.\n\n'
        'Thank you,\n$sign';
  }

  static String _join(List<String> s) => s.length <= 1 ? s.join() : '${s.sublist(0, s.length - 1).join(', ')} and ${s.last}';

  Future<void> _send() async {
    final to = _to.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(to)) {
      showMessage(context, 'Enter the recruiter’s email address. Use only an email shown by the company.', error: true);
      return;
    }
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(profileProvider).value;
    if (user == null || profile == null) return;
    final cvPath = _attach ? ref.read(localCvProvider).path : null;
    setState(() => _busy = true);
    try {
      if (_job.isCareerMate) {
        await ref.read(recruiterRepositoryProvider).apply(
              jobId: _job.postedJobId!,
              uid: user.uid,
              profile: profile,
              score: widget.args.match.score,
              cvEmailed: cvPath != null,
            );
      } else {
        await ref.read(firestoreProvider).collection('users').doc(user.uid).collection('outreach').doc(_job.id).set({
          'jobTitle': _job.title,
          'company': _job.company,
          'to': to,
          'url': _job.url,
          'emailedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not save your application. Check your internet and try again.', error: true);
        setState(() => _busy = false);
      }
      return;
    }
    final err = await EmailService.compose(to: to, subject: _subject.text.trim(), body: _body.text, attachmentPath: cvPath);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showMessage(context, _job.isCareerMate ? 'Application saved, but: $err' : err, error: true);
      return;
    }
    showMessage(context, _job.isCareerMate ? 'Application saved. Press Send in Gmail to email your CV.' : 'Gmail opened. Press Send there.');
    context.pop();
  }

  Future<void> _applyWithoutEmail() async {
    final user = ref.read(authStateProvider).value;
    final profile = ref.read(profileProvider).value;
    if (user == null || profile == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(recruiterRepositoryProvider).apply(
            jobId: _job.postedJobId!, uid: user.uid, profile: profile, score: widget.args.match.score, cvEmailed: false);
      if (mounted) {
        showMessage(context, 'Applied. The recruiter can see your profile details.');
        context.pop();
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not apply. Check your internet and try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(localCvProvider);
    final cvName = local.name;
    final isApply = _job.isCareerMate;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isApply ? 'Apply with your CV' : 'Email the recruiter'),
          Text('${_job.title} · ${_job.company}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
            children: [
              FadeSlideIn(
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(
                      controller: _to,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'To',
                        helperText: _job.contactEmail.isNotEmpty
                            ? 'Recruiter’s verified work email'
                            : 'Use only an email the company has published, e.g. on its careers page.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.blueDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Written from your confirmed CV — edit anything',
                            style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF8FB0FF) : AppColors.blueDark, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    TextField(controller: _body, minLines: 8, maxLines: 18, decoration: const InputDecoration(alignLabelWithHint: true)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 1,
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: cvName != null && _attach,
                    onChanged: cvName == null ? null : (v) => setState(() => _attach = v),
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.redTint, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.red),
                    ),
                    title: const Text('Attach my CV', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(cvName ?? 'No CV saved on this phone. Upload your CV again in the CV tab to attach it.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isApply
                    ? 'Your profile details (name, contact, skills, experience) are shared with this recruiter. Your CV goes by email from your own Gmail.'
                    : 'Gmail opens with everything filled in. You check it and press Send — CareerMate never sends emails for you.',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LoadingButton(
            label: isApply ? 'Apply & open Gmail' : 'Open in Gmail & send',
            icon: Icons.mail_outline_rounded,
            loading: _busy,
            onPressed: _send,
          ),
          if (isApply)
            TextButton(onPressed: _busy ? null : _applyWithoutEmail, child: const Text('Apply without email')),
        ]),
      ),
    );
  }
}

/// Opens the email screen for [match].
void openEmailComposer(BuildContext context, JobMatch match) =>
    context.push(Routes.emailRecruiter, extra: EmailDraftArgs(match: match));
