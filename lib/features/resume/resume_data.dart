import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../profile/cv_parser.dart';
import '../profile/profile_repository.dart';

class ResumeJob {
  ResumeJob({this.role = '', this.company = '', this.city = '', this.start = '', this.end = '', List<String>? bullets})
      : bullets = bullets ?? [];
  String role, company, city, start, end;
  List<String> bullets;

  Map<String, dynamic> toJson() => {'role': role, 'company': company, 'city': city, 'start': start, 'end': end, 'bullets': bullets};
  factory ResumeJob.fromJson(Map<String, dynamic> m) => ResumeJob(
        role: m['role'] ?? '',
        company: m['company'] ?? '',
        city: m['city'] ?? '',
        start: m['start'] ?? '',
        end: m['end'] ?? '',
        bullets: List<String>.from(m['bullets'] ?? const []),
      );
  String get dates => [start, end].where((s) => s.trim().isNotEmpty).join(' – ');
}

class ResumeEdu {
  ResumeEdu({this.degree = '', this.school = '', this.city = '', this.start = '', this.end = '', this.detail = ''});
  String degree, school, city, start, end, detail;
  Map<String, dynamic> toJson() => {'degree': degree, 'school': school, 'city': city, 'start': start, 'end': end, 'detail': detail};
  factory ResumeEdu.fromJson(Map<String, dynamic> m) => ResumeEdu(
        degree: m['degree'] ?? '',
        school: m['school'] ?? '',
        city: m['city'] ?? '',
        start: m['start'] ?? '',
        end: m['end'] ?? '',
        detail: m['detail'] ?? '',
      );
  String get dates => [start, end].where((s) => s.trim().isNotEmpty).join(' – ');
}

/// Everything shown on the CV. Saved only on this phone.
class ResumeData {
  ResumeData({
    this.name = '',
    this.headline = '',
    this.email = '',
    this.phone = '',
    this.city = '',
    this.link = '',
    this.summary = '',
    List<ResumeJob>? jobs,
    List<ResumeEdu>? education,
    List<String>? skills,
    List<String>? languages,
    List<String>? certifications,
    this.templateId = 'sidebarLeft-0',
    this.color = 0xFF1E3A6E,
  })  : jobs = jobs ?? [],
        education = education ?? [],
        skills = skills ?? [],
        languages = languages ?? [],
        certifications = certifications ?? [];

  String name, headline, email, phone, city, link, summary;
  List<ResumeJob> jobs;
  List<ResumeEdu> education;
  List<String> skills, languages, certifications;
  String templateId;
  int color;

  String get initials => name.trim().isEmpty
      ? 'CV'
      : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

  List<String> get contactLine => [phone, email, city, link].where((s) => s.trim().isNotEmpty).toList();

  Map<String, dynamic> toJson() => {
        'name': name,
        'headline': headline,
        'email': email,
        'phone': phone,
        'city': city,
        'link': link,
        'summary': summary,
        'jobs': jobs.map((j) => j.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'skills': skills,
        'languages': languages,
        'certifications': certifications,
        'templateId': templateId,
        'color': color,
      };

  factory ResumeData.fromJson(Map<String, dynamic> m) => ResumeData(
        name: m['name'] ?? '',
        headline: m['headline'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        city: m['city'] ?? '',
        link: m['link'] ?? '',
        summary: m['summary'] ?? '',
        jobs: [for (final j in (m['jobs'] as List? ?? const [])) ResumeJob.fromJson(Map<String, dynamic>.from(j as Map))],
        education: [for (final e in (m['education'] as List? ?? const [])) ResumeEdu.fromJson(Map<String, dynamic>.from(e as Map))],
        skills: List<String>.from(m['skills'] ?? const []),
        languages: List<String>.from(m['languages'] ?? const []),
        certifications: List<String>.from(m['certifications'] ?? const []),
        templateId: m['templateId'] ?? 'sidebarLeft-0',
        color: (m['color'] as num?)?.toInt() ?? 0xFF1E3A6E,
      );

  ResumeData copy() => ResumeData.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);

  /// Clearly-marked sample used only for template previews when the user has no data yet.
  static ResumeData sample() => ResumeData(
        name: 'Your Name',
        headline: 'Your job title',
        email: 'you@example.com',
        phone: '98XXX XXXXX',
        city: 'Your city',
        summary: 'Sample text — write 2–3 lines about your experience, your strongest skills and the role you want.',
        jobs: [
          ResumeJob(role: 'Job title', company: 'Company name', city: 'City', start: 'Jan 2023', end: 'Present', bullets: [
            'Sample point — start with an action word and add a real result.',
            'Sample point — mention the tools you used.',
          ]),
          ResumeJob(role: 'Previous job title', company: 'Company name', city: 'City', start: 'Jun 2020', end: 'Dec 2022', bullets: [
            'Sample point — what you were responsible for.',
          ]),
        ],
        education: [ResumeEdu(degree: 'Your degree', school: 'College / University', start: '2016', end: '2020')],
        skills: ['Skill one', 'Skill two', 'Skill three', 'Skill four', 'Skill five'],
        languages: ['English', 'Hindi'],
      );

  /// Starts from the confirmed profile and, when available, the CV text (jobs and points).
  static ResumeData fromProfile(CareerProfile p, {String cvText = ''}) {
    final d = ResumeData(
      name: p.name,
      headline: p.titles.isEmpty ? '' : CvParser.prettySkill(p.titles.first),
      email: p.email,
      phone: p.phone,
      city: p.location,
      link: p.links.isEmpty ? '' : p.links.first,
      skills: p.skills.map(CvParser.prettySkill).toList(),
      education: [for (final e in p.education) ResumeEdu(degree: e)],
    );
    if (cvText.trim().isNotEmpty) _importText(d, cvText);
    return d;
  }

  static void importForTest(ResumeData d, String raw) => _importText(d, raw);

  static void _importText(ResumeData d, String raw) {
    final text = CvParser.normalize(raw);
    final layer = text.contains(CvParser.textLayerMarker) ? text.split(CvParser.textLayerMarker).last : text;
    final lines = layer.split('\n').map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim()).where((l) => l.isNotEmpty).toList();
    final dateRe = RegExp(
        r'^((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*\d{4}|\d{1,2}[/.-]\d{4}|\d{4})\s*(?:-|–|—|to)\s*(present|current|till date|now|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*\d{4}|\d{1,2}[/.-]\d{4}|\d{4})$',
        caseSensitive: false);
    final bulletRe = RegExp(r'^[•●▪◦\-–*➢➤►✓]\s*');
    String section = '';
    final summary = <String>[];
    ResumeJob? cur;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final low = l.toLowerCase().replaceAll(RegExp(r'[^a-z ]'), '').trim();
      if (const ['education', 'projects', 'certifications', 'skills', 'languages', 'personal details', 'hobbies', 'achievements']
          .contains(low)) {
        section = low;
        cur = null;
        continue;
      }
      if (const ['summary', 'professional summary', 'profile', 'profile summary', 'objective', 'career objective'].contains(low)) {
        section = 'summary';
        continue;
      }
      final m = dateRe.firstMatch(l);
      if (m != null && section != 'education' && section != 'projects') {
        final prev = i > 0 ? lines[i - 1] : '';
        final looksRole = prev.length < 100 && !bulletRe.hasMatch(prev) && !prev.endsWith('.') && dateRe.firstMatch(prev) == null;
        final parts = looksRole ? prev.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() : <String>[];
        if (looksRole) {
          // The role line was taken as summary text or as the end of the previous job's point: undo that.
          if (summary.isNotEmpty && summary.last == prev) summary.removeLast();
          final last = cur?.bullets.isNotEmpty == true ? cur!.bullets.last : '';
          if (last.endsWith(' $prev')) cur!.bullets[cur.bullets.length - 1] = last.substring(0, last.length - prev.length - 1);
        }
        cur = ResumeJob(
          role: parts.isNotEmpty ? parts.first.replaceAll(RegExp(r'\s*[-–]\s*$'), '') : '',
          company: parts.length > 1 ? parts[1] : '',
          city: parts.length > 2 ? parts.sublist(2).join(', ') : '',
          start: m.group(1)!,
          end: m.group(2)!,
        );
        d.jobs.add(cur);
        continue;
      }
      if (section == 'summary' && cur == null && summary.join(' ').length < 600) {
        summary.add(l);
        continue;
      }
      if (cur != null && section != 'education' && section != 'projects') {
        if (bulletRe.hasMatch(l) || cur.bullets.isEmpty) {
          if (cur.bullets.length < 8) cur.bullets.add(l.replaceFirst(bulletRe, ''));
        } else if (l.length < 140 && !dateRe.hasMatch(l)) {
          cur.bullets[cur.bullets.length - 1] = '${cur.bullets.last} $l';
        }
      }
    }
    if (summary.isNotEmpty) d.summary = summary.join(' ');
    if (d.summary.isEmpty) {
      // A first paragraph that reads like a summary ("…with N years of experience…").
      final s = lines.firstWhere((l) => l.length > 80 && RegExp(r'experience', caseSensitive: false).hasMatch(l), orElse: () => '');
      d.summary = s;
    }
  }
}

class ResumeStore {
  static Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/cv_maker.json');

  static Future<ResumeData?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return ResumeData.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(ResumeData d) async => (await _file()).writeAsString(jsonEncode(d.toJson()));

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
