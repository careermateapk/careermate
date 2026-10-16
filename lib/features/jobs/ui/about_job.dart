import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/cv_parser.dart';
import '../job_models.dart';

/// Key facts read from the job text. Only what the text actually says.
class JobFacts {
  JobFacts({this.salary, this.experience, this.qualification, this.location});
  final String? salary;
  final String? experience;
  final String? qualification;
  final String? location;

  static JobFacts of(JobItem j) {
    final text = '${j.title}\n${j.fullText}';
    final low = text.toLowerCase();
    String? salary;
    if (j.salaryMin != null || j.salaryMax != null) {
      String f(num v) => v >= 100000 ? '${(v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1)} L' : v.round().toString();
      salary = '₹${[j.salaryMin, j.salaryMax].whereType<num>().map(f).join(' – ')} a year';
    } else {
      final m = RegExp(r'(?:salary|ctc|stipend|pay)[^\n]{0,20}?((?:₹|rs\.?|inr)?\s?[\d,.]+\s*(?:k|lpa|l|lakh)?\s*(?:-|–|to)\s*(?:₹|rs\.?|inr)?\s?[\d,.]+\s*(?:k|lpa|l|lakhs?)?(?:\s*(?:per|/|a)\s*(?:month|annum|year|pm|pa))?)',
              caseSensitive: false)
          .firstMatch(text);
      salary = m?.group(1)?.trim();
    }
    final e = RegExp(r'(\d{1,2}\s*(?:-|–|to)\s*\d{1,2}|\d{1,2}\+?)\s*(?:years?|yrs?)', caseSensitive: false).firstMatch(text);
    String? qual;
    final found = <String>[];
    for (final d in CvParser.degrees) {
      if (CvParser.containsWord(low, d) && !found.any((f) => f.replaceAll('.', '') == d.replaceAll('.', ''))) found.add(d);
      if (found.length == 3) break;
    }
    if (found.isNotEmpty) qual = found.map(CvParser.prettySkill).join(' / ');
    if (low.contains('fresher')) qual = qual == null ? 'Freshers can apply' : '$qual · freshers OK';
    return JobFacts(
      salary: salary,
      experience: e == null ? (low.contains('fresher') ? 'Fresher' : null) : '${e.group(1)!.replaceAll(RegExp(r'\s+'), ' ')} years',
      qualification: qual,
      location: j.location.isEmpty ? null : j.location,
    );
  }
}

class AboutJobCard extends StatefulWidget {
  const AboutJobCard({super.key, required this.match});
  final JobMatch match;

  @override
  State<AboutJobCard> createState() => _AboutJobCardState();
}

class _AboutJobCardState extends State<AboutJobCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final j = widget.match.job;
    final facts = JobFacts.of(j);
    final text = j.fullText.trim();
    final long = text.length > 420;
    final shown = !_open && long ? '${text.substring(0, 420).trimRight()}…' : text;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tile = dark ? const Color(0xFF1D2950) : const Color(0xFFF1F4FB);
    final factRows = [
      if (facts.salary != null) ('💰', 'Salary', facts.salary!),
      if (facts.experience != null) ('🧳', 'Experience', facts.experience!),
      if (facts.location != null) ('📍', 'Location', facts.location!),
      if (facts.qualification != null) ('🎓', 'Qualification', facts.qualification!),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (factRows.isNotEmpty || j.skills.isNotEmpty)
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KEY DETAILS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, c) {
              final w = (c.maxWidth - 8) / 2;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in factRows)
                  Container(
                    width: w,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${f.$1} ${f.$2}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(f.$3, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    ]),
                  ),
              ]);
            }),
            if (widget.match.matchedSkills.isNotEmpty || widget.match.missingSkills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in widget.match.matchedSkills) StatusChip('${CvParser.prettySkill(s)} ✓', tone: ChipTone.positive),
                for (final s in widget.match.missingSkills) StatusChip('${CvParser.prettySkill(s)} · add to CV', tone: ChipTone.warning),
              ]),
            ],
          ]),
        ),
      if (text.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('About the job', style: AppTheme.display(context, size: 15)),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              alignment: Alignment.topCenter,
              child: Text.rich(
                TextSpan(children: _highlight(shown, widget.match, dark)),
                style: TextStyle(color: dark ? const Color(0xFFE2E8F5) : AppColors.textBody, height: 1.55, fontSize: 14),
              ),
            ),
            if (long)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? 'Show less ▲' : 'Read full description ▼', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            Text(
              j.isCareerMate
                  ? 'Written by the recruiter on CareerMate.'
                  : 'This is everything ${j.sourceName} shares. Open the job page for the original.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ]),
        ),
      ],
    ]);
  }

  /// Bold section words and highlight the job's skills so the eye finds them.
  List<InlineSpan> _highlight(String text, JobMatch m, bool dark) {
    final words = <String>{...m.job.skills, ...m.matchedSkills}.where((w) => w.length > 1).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    const heads = r'responsibilities|requirements|qualifications?|skills|salary|experience|location|eligibility|benefits|about (?:us|the role)|job description|role';
    final pattern = [
      '(?<![a-z0-9])(?:$heads)(?=\\s*:)',
      for (final w in words) '(?<![a-z0-9])${RegExp.escape(w)}(?![a-z0-9])',
    ].join('|');
    final re = RegExp(pattern, caseSensitive: false);
    final spans = <InlineSpan>[];
    var i = 0;
    for (final hit in re.allMatches(text)) {
      if (hit.start > i) spans.add(TextSpan(text: text.substring(i, hit.start)));
      final s = hit.group(0)!;
      final isHead = RegExp('^(?:$heads)\$', caseSensitive: false).hasMatch(s);
      spans.add(TextSpan(
        text: s,
        style: isHead
            ? TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : AppColors.navy)
            : TextStyle(
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : AppColors.blueDark,
                backgroundColor: AppColors.blue.withValues(alpha: dark ? 0.28 : 0.12),
              ),
      ));
      i = hit.end;
    }
    if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
    return spans;
  }
}
