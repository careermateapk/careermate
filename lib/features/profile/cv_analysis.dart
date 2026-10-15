import 'ats_scorer.dart';
import 'cv_parser.dart';
import 'profile_repository.dart';

/// Turns raw CV text into a draft profile (with ATS score) for review.
CareerProfile draftFromText(String text, {required String fileName, String fallbackEmail = '', String fallbackName = ''}) {
  final parsed = CvParser().parse(text);
  final ats = const AtsScorer().score(parsed);
  return CareerProfile(
    name: parsed.name.isNotEmpty ? parsed.name : fallbackName,
    email: parsed.email.isNotEmpty ? parsed.email : fallbackEmail,
    phone: parsed.phone,
    location: parsed.location,
    links: parsed.links,
    experienceYears: parsed.experienceYears,
    skills: parsed.skills,
    titles: parsed.titles,
    education: parsed.education,
    atsScore: ats.total,
    atsParts: {for (final p in ats.parts) p.key: p.score},
    atsIssues: ats.issues.map(issueToMap).toList(),
    resumeFileName: fileName,
  );
}

Map<String, String> issueToMap(AtsIssue i) => {
      'severity': i.severity.name,
      'title': i.title,
      'detail': i.detail,
      if (i.before != null) 'before': i.before!,
      if (i.after != null) 'after': i.after!,
    };

/// Labels and maximums for the stored ATS parts, in display order.
const atsPartLabels = {
  'skills': 'Skills found',
  'sections': 'Section structure',
  'achievements': 'Measurable achievements',
  'contact': 'Contact details',
  'verbs': 'Action words',
  'length': 'Length & readability',
  'dates': 'Dates & timeline',
  'parsing': 'Easy for systems to read',
};
