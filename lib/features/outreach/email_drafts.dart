import '../jobs/job_models.dart';
import '../profile/cv_parser.dart';
import '../profile/profile_repository.dart';

/// Email draft styles. Every draft is built only from the confirmed CV profile and the job —
/// nothing is invented. "New version" picks a different wording of the same facts.
enum DraftStyle {
  professional('Professional'),
  short('Short & crisp'),
  friendly('Friendly'),
  fresher('Fresher'),
  followUp('Follow-up');

  const DraftStyle(this.label);
  final String label;
}

class EmailDraft {
  const EmailDraft(this.subject, this.body);
  final String subject;
  final String body;
}

class DraftWriter {
  DraftWriter({required this.match, required this.profile});
  final JobMatch match;
  final CareerProfile profile;

  JobItem get job => match.job;

  int variantsOf(DraftStyle s) => 3;

  String get _company => job.company.isEmpty ? 'your company' : job.company;
  String get _where => job.isCareerMate ? 'on CareerMate' : (job.official ? 'on your careers page' : 'online');

  String get _years {
    final y = profile.experienceYears;
    return y % 1 == 0 ? '${y.toInt()}' : y.toStringAsFixed(1);
  }

  bool get _hasExp => profile.experienceYears >= 1;

  List<String> _skills(int variant, [int n = 3]) {
    final matched = match.matchedSkills.map(CvParser.prettySkill).toList();
    final rest = profile.skills.map(CvParser.prettySkill).where((s) => !matched.contains(s)).toList();
    final all = [...matched, ...rest];
    if (all.length <= n) return all;
    // Matched skills first; later versions rotate in other real skills from the CV.
    final keep = matched.take(variant == 0 ? n : (n - 1).clamp(1, n)).toList();
    final pool = all.where((s) => !keep.contains(s)).toList();
    final start = pool.isEmpty ? 0 : (variant * 2) % pool.length;
    final extra = [for (var i = 0; i < pool.length && keep.length + i < n; i++) pool[(start + i) % pool.length]];
    return [...keep, ...extra].take(n).toList();
  }

  static String _join(List<String> s) =>
      s.length <= 1 ? s.join() : '${s.sublist(0, s.length - 1).join(', ')} and ${s.last}';

  String get _edu => profile.education.isEmpty ? '' : profile.education.first;
  String get _lastTitle => profile.titles.isEmpty ? '' : profile.titles.first;

  String get _signature => [profile.name, profile.phone, profile.location].where((s) => s.trim().isNotEmpty).join('\n');
  String get _signatureLine => [profile.name, profile.phone].where((s) => s.trim().isNotEmpty).join(' · ');

  String _expPhrase(int v) {
    if (!_hasExp) return 'I am a fresher';
    final t = _lastTitle.isEmpty ? '' : ' as a $_lastTitle';
    return switch (v % 3) {
      0 => 'I have $_years years of experience$t',
      1 => 'I bring $_years years of hands-on experience$t',
      _ => 'Over the last $_years years$t, I have built solid experience',
    };
  }

  String _skillPhrase(int v) {
    final s = _skills(v);
    if (s.isEmpty) return '';
    return switch (v % 3) {
      0 => ' with skills in ${_join(s)}',
      1 => ', working with ${_join(s)}',
      _ => ' in ${_join(s)}',
    };
  }

  EmailDraft write(DraftStyle style, int variant) {
    final v = variant % variantsOf(style);
    final name = profile.name.isEmpty ? 'application' : profile.name;
    switch (style) {
      case DraftStyle.professional:
        final open = ['Dear Hiring Team,', 'Dear Hiring Manager,', 'Dear Recruitment Team,'][v];
        final close = [
          'My CV is attached. I would welcome a short call to discuss the role.',
          'I have attached my CV and would be glad to discuss how I can contribute.',
          'Please find my CV attached. I look forward to hearing from you.',
        ][v];
        final edu = _edu.isEmpty ? '' : ' I hold a $_edu.';
        return EmailDraft(
          ['${job.title} role — $name', 'Application for ${job.title} — $name', '${job.title} at $_company — $name'][v],
          '$open\n\nI saw the ${job.title} opening at $_company $_where. ${_expPhrase(v)}${_skillPhrase(v)}.$edu\n\n'
          '$close\n\n${['Thank you,', 'Kind regards,', 'Sincerely,'][v]}\n$_signature',
        );
      case DraftStyle.short:
        final s = _skills(v, 2);
        final head = _hasExp ? '$_years yrs${s.isEmpty ? '' : ' ${s.join(' & ')}'}' : (s.isEmpty ? 'Fresher' : 'Fresher · ${s.join(' & ')}');
        final line = _hasExp
            ? 'I have $_years years of experience${s.isEmpty ? '' : ' in ${_join(s)}'}.'
            : 'I am a fresher${s.isEmpty ? '' : ' with skills in ${_join(s)}'}.';
        return EmailDraft(
          '${job.title} — $head',
          '${['Hello Hiring Team,', 'Hi,', 'Hello,'][v]}\n\nI’m applying for the ${job.title} role. $line\n\n'
          '${['My CV is attached. Happy to talk at your convenience.', 'CV attached. Available for a call anytime.', 'Please see my CV attached. Thank you!'][v]}\n\n'
          'Regards,\n$_signatureLine',
        );
      case DraftStyle.friendly:
        final hook = [
          'I came across the ${job.title} opening at $_company and it looks like a great fit for me.',
          'The ${job.title} role at $_company caught my eye, and I’d love to be considered.',
          'I was excited to see that $_company is hiring for a ${job.title}.',
        ][v];
        return EmailDraft(
          ['Excited about the ${job.title} role', '${job.title} — would love to chat', 'Interested in ${job.title} at $_company'][v],
          '${['Hi there,', 'Hello!', 'Hi Hiring Team,'][v]}\n\n$hook ${_expPhrase(v)}${_skillPhrase(v)}.\n\n'
          '${['I’ve attached my CV — it would be great to have a quick chat.', 'My CV is attached. I’d be happy to talk whenever suits you.', 'Sharing my CV here. Looking forward to connecting!'][v]}\n\n'
          '${['Thanks so much,', 'Best,', 'Cheers,'][v]}\n$_signature',
        );
      case DraftStyle.fresher:
        final s = _skills(v);
        final edu = _edu.isEmpty ? 'I have recently completed my studies' : 'I have recently completed my $_edu';
        final skills = s.isEmpty ? '' : ' During this time I built skills in ${_join(s)}.';
        final eager = [
          'I am eager to start my career and learn quickly on the job.',
          'I am keen to begin my career with a team like yours and grow with it.',
          'I am a quick learner and ready to contribute from day one.',
        ][v];
        return EmailDraft(
          ['Fresher application — ${job.title}', '${job.title} — fresher, $name', 'Application: ${job.title} (fresher)'][v],
          'Dear Hiring Team,\n\n$edu and would like to apply for the ${job.title} role at $_company.$skills $eager\n\n'
          'My CV is attached. I would be grateful for a chance to interview.\n\nThank you,\n$_signature',
        );
      case DraftStyle.followUp:
        final s = _skills(v, 2);
        return EmailDraft(
          ['Following up — ${job.title} application', 'Checking in on my ${job.title} application', '${job.title} — follow-up'][v],
          'Dear Hiring Team,\n\n${[
            'I recently applied for the ${job.title} role at $_company and wanted to follow up.',
            'I wanted to check in on my application for the ${job.title} position.',
            'I am writing to follow up on my application for the ${job.title} role.',
          ][v]} I am still very interested${s.isEmpty ? '' : ' and believe my experience in ${_join(s)} fits the role'}.\n\n'
          'I have attached my CV again for easy reference. Please let me know if you need anything else from me.\n\n'
          'Thank you for your time,\n$_signature',
        );
    }
  }
}
