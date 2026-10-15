import 'taxonomy.dart';

/// Details read from a CV's text. Every field can be wrong; the user
/// reviews and edits them before they become their profile.
class ParsedCv {
  ParsedCv({
    required this.text,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.links,
    required this.skills,
    required this.titles,
    required this.education,
    required this.experienceYears,
    required this.sections,
    required this.bullets,
    required this.dateRanges,
  });

  final String text;
  final String name;
  final String email;
  final String phone;
  final String location;
  final List<String> links;
  final List<String> skills; // lowercase keywords
  final List<String> titles; // lowercase
  final List<String> education;
  final double experienceYears;

  /// Section key → its lines (summary, experience, education, skills, …).
  final Map<String, List<String>> sections;
  final List<String> bullets;
  final List<DateRange> dateRanges;

  int get wordCount => RegExp(r'\S+').allMatches(text).length;
  bool get hasText => text.trim().length > 80;
}

class DateRange {
  DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get months => (end.year - start.year) * 12 + end.month - start.month + 1;
}

class CvParser {
  CvParser({DateTime? now}) : now = now ?? DateTime.now();
  final DateTime now;

  static const _sectionWords = {
    'summary': ['summary', 'profile', 'objective', 'career objective', 'about me', 'professional summary', 'profile summary'],
    'experience': ['experience', 'work experience', 'professional experience', 'employment', 'employment history', 'work history', 'internship', 'internships', 'career history'],
    'education': ['education', 'academic', 'academics', 'qualification', 'qualifications', 'educational qualification', 'academic qualification'],
    'skills': ['skills', 'technical skills', 'key skills', 'core competencies', 'competencies', 'expertise', 'areas of expertise', 'it skills', 'skill set'],
    'projects': ['projects', 'academic projects', 'key projects', 'personal projects'],
    'certifications': ['certifications', 'certification', 'certificates', 'courses', 'trainings', 'training'],
    'achievements': ['achievements', 'awards', 'accomplishments', 'honours', 'honors'],
    'languages': ['languages', 'languages known'],
    'personal': ['personal details', 'personal information', 'personal profile', 'declaration', 'hobbies', 'interests'],
  };

  static const cities = [
    'delhi', 'new delhi', 'mumbai', 'bengaluru', 'bangalore', 'hyderabad', 'chennai', 'kolkata', 'pune', 'ahmedabad',
    'jaipur', 'lucknow', 'kanpur', 'nagpur', 'indore', 'bhopal', 'patna', 'ranchi', 'surat', 'vadodara', 'noida',
    'gurgaon', 'gurugram', 'ghaziabad', 'faridabad', 'chandigarh', 'mohali', 'ludhiana', 'amritsar', 'dehradun',
    'kochi', 'thiruvananthapuram', 'coimbatore', 'madurai', 'mysuru', 'mysore', 'mangaluru', 'visakhapatnam',
    'vijayawada', 'bhubaneswar', 'guwahati', 'raipur', 'nashik', 'aurangabad', 'thane', 'navi mumbai', 'varanasi',
    'prayagraj', 'allahabad', 'agra', 'meerut', 'darbhanga', 'muzaffarpur', 'gaya', 'bhagalpur', 'jamshedpur',
    'dhanbad', 'siliguri', 'jodhpur', 'udaipur', 'kota', 'goa', 'panaji', 'srinagar', 'jammu', 'shimla', 'remote',
  ];

  static const _degrees = [
    'ph.d', 'phd', 'm.tech', 'mtech', 'b.tech', 'btech', 'b.e.', 'm.e.', 'mba', 'pgdm', 'mca', 'bca', 'm.sc', 'msc',
    'b.sc', 'bsc', 'm.com', 'mcom', 'b.com', 'bcom', 'bba', 'b.ed', 'm.ed', 'llb', 'll.b', 'llm', 'mbbs', 'b.pharm',
    'd.pharm', 'm.pharm', 'bds', 'gnm', 'anm', 'polytechnic', 'diploma', 'iti', 'b.a.', 'm.a.', 'ca inter', 'ca final',
    'chartered accountant', 'cs executive', '12th', 'class xii', 'hsc', 'intermediate', '10th', 'class x', 'ssc', 'matriculation',
  ];

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  ParsedCv parse(String raw) {
    final text = raw.replaceAll('\r', '\n').replaceAll(' ', ' ');
    final lines = text
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final lower = text.toLowerCase();

    final sections = _sections(lines);
    final bullets = lines
        .where((l) => RegExp(r'^[•●▪◦\-–*➢➤►✓]').hasMatch(l) || (l.length > 40 && l.length < 260))
        .map((l) => l.replaceFirst(RegExp(r'^[•●▪◦\-–*➢➤►✓]\s*'), ''))
        .toList();

    final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').firstMatch(text)?.group(0) ?? '';
    final phone = RegExp(r'(\+91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}').firstMatch(text)?.group(0)?.replaceAll(RegExp(r'\s'), '') ?? '';
    final links = RegExp(r'((https?://)?(www\.)?(linkedin\.com/in/|github\.com/|behance\.net/)[\w\-./]+)', caseSensitive: false)
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    final skills = <String>{};
    final titles = <String>{};
    for (final c in jobCategories) {
      for (final s in c.subs) {
        for (final k in s.skills) {
          if (containsWord(lower, k)) skills.add(k);
        }
        for (final t in s.titles) {
          if (containsWord(lower, t)) titles.add(t);
        }
      }
    }

    final eduText = (sections['education'] ?? lines).join(' \n ').toLowerCase();
    final education = <String>[];
    for (final d in _degrees) {
      if (containsWord(eduText, d) && !education.any((e) => e.replaceAll('.', '') == d.replaceAll('.', ''))) {
        education.add(d);
      }
    }

    final expLines = sections['experience'] ?? lines.where((l) => !(sections['education'] ?? const []).contains(l)).toList();
    final ranges = dateRanges(expLines.join('\n'));

    return ParsedCv(
      text: text,
      name: _name(lines),
      email: email,
      phone: phone,
      location: _location(lines),
      links: links,
      skills: skills.toList(),
      titles: titles.toList(),
      education: education.map(prettySkill).toList(),
      experienceYears: _years(ranges),
      sections: sections,
      bullets: bullets,
      dateRanges: ranges,
    );
  }

  /// Whole-word, case-insensitive match (expects [lowerText] already lowercase).
  static bool containsWord(String lowerText, String keyword) {
    final k = RegExp.escape(keyword.toLowerCase());
    return RegExp('(?<![a-z0-9+#])$k(?![a-z0-9+#])').hasMatch(lowerText);
  }

  /// "power bi" → "Power BI", "sql" → "SQL".
  static String prettySkill(String k) {
    const special = {
      'node.js': 'Node.js', 'next.js': 'Next.js', '.net': '.NET', 'c#': 'C#', 'ci/cd': 'CI/CD', 'iti': 'ITI',
      'b.tech': 'B.Tech', 'm.tech': 'M.Tech', 'b.e.': 'B.E.', 'm.e.': 'M.E.', 'b.com': 'B.Com', 'm.com': 'M.Com',
      'b.sc': 'B.Sc', 'm.sc': 'M.Sc', 'b.ed': 'B.Ed', 'm.ed': 'M.Ed', 'b.pharm': 'B.Pharm', 'd.pharm': 'D.Pharm',
      'm.pharm': 'M.Pharm', 'b.a.': 'B.A.', 'm.a.': 'M.A.', 'ph.d': 'Ph.D', 'll.b': 'LL.B', '12th': '12th', '10th': '10th',
      'figma': 'Figma', 'flutter': 'Flutter', 'ios': 'iOS', 'swiftui': 'SwiftUI', 'b.sc nursing': 'B.Sc Nursing',
    };
    if (special.containsKey(k)) return special[k]!;
    return k.split(' ').map((w) {
      if (w.isEmpty) return w;
      if (w.length <= 4 && !const ['java', 'dart', 'vue', 'ruby', 'sass', 'jira', 'lean', 'icu', 'tally'].contains(w)) {
        return w.toUpperCase();
      }
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  Map<String, List<String>> _sections(List<String> lines) {
    final out = <String, List<String>>{};
    String? current;
    for (final l in lines) {
      final key = _headingKey(l);
      if (key != null) {
        current = key;
        out.putIfAbsent(key, () => []);
        continue;
      }
      if (current != null) out[current]!.add(l);
    }
    return out;
  }

  String? _headingKey(String line) {
    if (line.length > 40) return null;
    final h = line.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
    for (final e in _sectionWords.entries) {
      if (e.value.contains(h)) return e.key;
    }
    return null;
  }

  String _name(List<String> lines) {
    for (final l in lines.take(8)) {
      if (l.contains('@') || RegExp(r'\d{3}').hasMatch(l) || _headingKey(l) != null) continue;
      final words = l.split(' ');
      if (words.length >= 2 && words.length <= 4 && words.every((w) => RegExp(r"^[A-Za-z.']+$").hasMatch(w))) {
        final lower = l.toLowerCase();
        if (lower.contains('resume') || lower.contains('curriculum')) continue;
        return words.map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
      }
    }
    return '';
  }

  String _location(List<String> lines) {
    final n = (lines.length * 0.3).ceil();
    final head = lines.take(n < 6 ? 6 : (n > 25 ? 25 : n)).join(' ').toLowerCase();
    for (final c in cities) {
      if (containsWord(head, c)) return c.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
    }
    return '';
  }

  /// Finds ranges like "Jan 2021 – Present", "03/2019 - 08/2022", "2018 to 2020".
  List<DateRange> dateRanges(String text) {
    final t = text.toLowerCase();
    const mon = r'(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?';
    final point = '(?:$mon\\s*[\',]?\\s*(\\d{4})|(\\d{1,2})[/.-](\\d{4})|(\\d{4}))';
    final end = '(?:present|current|till date|till now|now|ongoing|date|$point)';
    final re = RegExp('$point\\s*(?:-|–|—|to|till)\\s*$end');
    final out = <DateRange>[];
    for (final m in re.allMatches(t)) {
      final start = _point(m.group(1), m.group(2), m.group(3), m.group(4), m.group(5));
      final endIsWord = m.group(7) == null && m.group(8) == null && m.group(10) == null;
      final e = endIsWord
          ? DateTime(now.year, now.month)
          : _point(m.group(6), m.group(7), m.group(8), m.group(9), m.group(10), isEnd: true);
      if (start == null || e == null) continue;
      if (start.year < 1970 || e.isBefore(start) || e.isAfter(DateTime(now.year, now.month + 1))) continue;
      out.add(DateRange(start, e));
    }
    return out;
  }

  DateTime? _point(String? monName, String? monYear, String? mm, String? mmYear, String? yearOnly, {bool isEnd = false}) {
    if (monName != null && monYear != null) {
      final m = _months[monName.length >= 4 && monName.startsWith('sept') ? 'sept' : monName.substring(0, 3)];
      if (m == null) return null;
      return DateTime(int.parse(monYear), m);
    }
    if (mm != null && mmYear != null) {
      final m = int.parse(mm);
      if (m < 1 || m > 12) return null;
      return DateTime(int.parse(mmYear), m);
    }
    if (yearOnly != null) return DateTime(int.parse(yearOnly), isEnd ? 12 : 1);
    return null;
  }

  /// Total experience in years, counting overlapping jobs once.
  double _years(List<DateRange> ranges) {
    if (ranges.isEmpty) return 0;
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    var months = 0;
    var curStart = sorted.first.start;
    var curEnd = sorted.first.end;
    for (final r in sorted.skip(1)) {
      if (!r.start.isAfter(curEnd)) {
        if (r.end.isAfter(curEnd)) curEnd = r.end;
      } else {
        months += DateRange(curStart, curEnd).months;
        curStart = r.start;
        curEnd = r.end;
      }
    }
    months += DateRange(curStart, curEnd).months;
    return (months / 12 * 10).round() / 10;
  }
}
