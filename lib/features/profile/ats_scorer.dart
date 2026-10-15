import 'cv_parser.dart';

enum Severity { high, medium, low }

class AtsPart {
  const AtsPart(this.key, this.label, this.score, this.max);
  final String key;
  final String label;
  final int score;
  final int max;
  double get ratio => max == 0 ? 0 : score / max;
}

class AtsIssue {
  const AtsIssue(this.severity, this.title, this.detail, {this.before, this.after});
  final Severity severity;
  final String title;
  final String detail;
  final String? before;
  final String? after;
}

class AtsReport {
  const AtsReport(this.total, this.parts, this.issues);
  final int total;
  final List<AtsPart> parts;
  final List<AtsIssue> issues;
}

/// A transparent, rule-based CV readiness estimate. It is not the score of
/// any employer's applicant tracking system. Weights add up to 100.
class AtsScorer {
  const AtsScorer();

  static const weights = {
    'contact': 10,
    'sections': 15,
    'skills': 20,
    'achievements': 15,
    'verbs': 10,
    'length': 10,
    'dates': 10,
    'parsing': 10,
  };

  static const actionVerbs = [
    'led', 'built', 'developed', 'designed', 'managed', 'created', 'improved', 'increased', 'reduced', 'launched',
    'implemented', 'delivered', 'achieved', 'handled', 'trained', 'coordinated', 'organised', 'organized', 'resolved',
    'analysed', 'analyzed', 'automated', 'optimised', 'optimized', 'negotiated', 'supervised', 'prepared', 'planned',
    'executed', 'maintained', 'generated', 'won', 'established', 'mentored', 'streamlined', 'served', 'taught',
  ];

  AtsReport score(ParsedCv cv) {
    final parts = <AtsPart>[];
    final issues = <AtsIssue>[];

    // Contact details
    var c = 0;
    if (cv.email.isNotEmpty) c += 4; else issues.add(const AtsIssue(Severity.high, 'Add your email address', 'Recruiters and job portals need an email to contact you.'));
    if (cv.phone.isNotEmpty) c += 3; else issues.add(const AtsIssue(Severity.high, 'Add your mobile number', 'Most Indian recruiters call first. Add a 10-digit mobile number near your name.'));
    if (cv.location.isNotEmpty) c += 2; else issues.add(const AtsIssue(Severity.low, 'Add your city', 'Job filters often use location. Add your current city, e.g. "Pune, Maharashtra".'));
    if (cv.links.isNotEmpty) c += 1;
    parts.add(AtsPart('contact', 'Contact details', c, weights['contact']!));

    // Sections
    const needed = {'experience': 'Work experience (or internships)', 'education': 'Education', 'skills': 'Skills', 'summary': 'Summary'};
    var sec = 0;
    final missing = <String>[];
    needed.forEach((k, label) {
      if (cv.sections.containsKey(k)) {
        sec += k == 'summary' ? 3 : 4;
      } else {
        missing.add(label);
      }
    });
    if (cv.sections.containsKey('projects') || cv.sections.containsKey('certifications')) sec = (sec + 2).clamp(0, 15).toInt();
    if (missing.isNotEmpty) {
      issues.add(AtsIssue(missing.contains('Education') || missing.contains('Skills') ? Severity.medium : Severity.low,
          'Add clear section headings',
          'We could not find: ${missing.join(', ')}. Use simple headings like "Experience", "Education" and "Skills" so systems can read your CV.'));
    }
    parts.add(AtsPart('sections', 'Section structure', sec, weights['sections']!));

    // Skills
    final n = cv.skills.length;
    final sk = n >= 12 ? 20 : (n * 20 / 12).round();
    if (n < 6) {
      issues.add(AtsIssue(Severity.high, 'List more of your real skills',
          'We recognised $n skill${n == 1 ? '' : 's'}. Add tools and skills you actually use (software, methods, certifications) in a "Skills" section. Only add skills you have.'));
    }
    parts.add(AtsPart('skills', 'Skills found', sk, weights['skills']!));

    // Achievements with numbers
    final quantified = cv.bullets.where((b) => RegExp(r'\d+\s*%|₹|\brs\.?\s?\d|\d+\s*(lakh|lac|crore|k\b|\+)|\b\d{2,}\b', caseSensitive: false).hasMatch(b)).length;
    final ach = quantified >= 5 ? 15 : quantified * 3;
    if (quantified < 3) {
      final plain = cv.bullets.firstWhere(
        (b) => b.length > 30 && b.length < 140 && !RegExp(r'\d').hasMatch(b),
        orElse: () => 'Worked on the sales reports for my team.',
      );
      issues.add(AtsIssue(Severity.high, 'Show results with numbers',
          'Only $quantified line${quantified == 1 ? '' : 's'} show a measurable result. Add verified numbers: how much, how many, how fast. Never invent a number.',
          before: plain, after: '${_stripEnd(plain)}, which [WHAT IMPROVED] by [YOUR VERIFIED NUMBER].'));
    }
    parts.add(AtsPart('achievements', 'Measurable achievements', ach, weights['achievements']!));

    // Action verbs
    final verbs = cv.bullets.where((b) {
      final first = b.toLowerCase().split(RegExp(r'[^a-z]+')).firstWhere((w) => w.isNotEmpty, orElse: () => '');
      return actionVerbs.contains(first);
    }).length;
    final vb = verbs >= 5 ? 10 : verbs * 2;
    if (verbs < 3) {
      issues.add(const AtsIssue(Severity.medium, 'Start points with action words',
          'Begin each point with a strong verb like "Built", "Managed", "Trained" or "Reduced".',
          before: 'Responsible for handling customer complaints.', after: 'Resolved 30+ customer complaints a day… (use your real figure).'));
    }
    parts.add(AtsPart('verbs', 'Action words', vb, weights['verbs']!));

    // Length & readability
    final w = cv.wordCount;
    int len;
    if (w < 150) {
      len = 3;
      issues.add(AtsIssue(Severity.medium, 'Your CV looks very short', 'We found about $w words. Add details of your work, projects and skills (300–900 words is typical).'));
    } else if (w > 1400) {
      len = 6;
      issues.add(AtsIssue(Severity.low, 'Your CV is long', 'We found about $w words. Keep it to 1–2 pages; remove old or unrelated details.'));
    } else {
      len = 10;
    }
    parts.add(AtsPart('length', 'Length & readability', len, weights['length']!));

    // Dates
    int dt;
    if (cv.sections.containsKey('experience') && cv.dateRanges.isEmpty) {
      dt = 4;
      issues.add(const AtsIssue(Severity.medium, 'Add dates to your experience', 'Write dates as "Jan 2022 – Present" so your total experience can be calculated.'));
    } else {
      dt = 10;
      final sorted = [...cv.dateRanges]..sort((a, b) => a.start.compareTo(b.start));
      for (var i = 1; i < sorted.length; i++) {
        final gap = (sorted[i].start.year - sorted[i - 1].end.year) * 12 + sorted[i].start.month - sorted[i - 1].end.month;
        if (gap > 6) {
          issues.add(AtsIssue(Severity.low, 'Explain the gap of about ${(gap / 12).toStringAsFixed(1)} years',
              'A short, honest line about a career break (study, family, health, relocation) helps. You can use the Career break helper.'));
          break;
        }
      }
    }
    parts.add(AtsPart('dates', 'Dates & timeline', dt, weights['dates']!));

    // Parsing compatibility
    final odd = RegExp(r'[^\x00-\x7F₹•●▪◦–—’‘“”…]').allMatches(cv.text).length;
    final ratio = cv.text.isEmpty ? 1 : odd / cv.text.length;
    final pc = ratio > 0.05 ? 5 : 10;
    if (ratio > 0.05) {
      issues.add(const AtsIssue(Severity.medium, 'Some text may not be readable by hiring systems',
          'Fancy fonts, icons or text inside images can confuse systems. Use a simple one-column layout with standard fonts.'));
    }
    parts.add(AtsPart('parsing', 'Easy for systems to read', pc, weights['parsing']!));

    final total = parts.fold<int>(0, (s, p) => s + p.score);
    issues.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return AtsReport(total.clamp(0, 100).toInt(), parts, issues);
  }

  static String _stripEnd(String s) => s.trim().replaceFirst(RegExp(r'[.;,]+$'), '');
}
