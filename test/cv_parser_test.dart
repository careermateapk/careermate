import 'package:careermate/features/profile/ats_scorer.dart';
import 'package:careermate/features/profile/category_matcher.dart';
import 'package:careermate/features/profile/cv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const sampleCv = '''
Aarav Sharma
Pune, Maharashtra | aarav.sharma@example.com | +91 98765 43210
linkedin.com/in/aarav-sharma

Summary
Flutter developer with 3 years of experience building Android apps.

Work Experience
Flutter Developer, Nimbus Labs
Jan 2023 - Present
• Built a payments flow in Flutter used by 20,000 users
• Reduced app start time by 35% using lazy loading
• Led a team of 3 developers

Android Developer, Kavya Fintech
Jun 2021 - Dec 2022
• Developed Kotlin screens with Jetpack Compose
• Worked on REST API integration

Education
B.Tech in Computer Science, 2017 - 2021

Skills
Flutter, Dart, Kotlin, Firebase, Git, REST API, SQL, Riverpod, Android Studio
''';

void main() {
  final parser = CvParser(now: DateTime(2026, 10));

  test('reads contact details', () {
    final cv = parser.parse(sampleCv);
    expect(cv.name, 'Aarav Sharma');
    expect(cv.email, 'aarav.sharma@example.com');
    expect(cv.phone, contains('9876543210'));
    expect(cv.location, 'Pune');
    expect(cv.links.single, contains('linkedin.com/in/aarav-sharma'));
  });

  test('finds sections, skills, titles and education', () {
    final cv = parser.parse(sampleCv);
    expect(cv.sections.keys, containsAll(['summary', 'experience', 'education', 'skills']));
    expect(cv.skills, containsAll(['flutter', 'dart', 'kotlin', 'sql', 'rest api', 'jetpack compose']));
    expect(cv.skills, isNot(contains('java')));
    expect(cv.titles, containsAll(['flutter developer', 'android developer']));
    expect(cv.education, contains('B.Tech'));
  });

  test('counts experience without double-counting and ignores education dates', () {
    final cv = parser.parse(sampleCv);
    // Jun 2021 – Dec 2022 (19 months) + Jan 2023 – Oct 2026 (46 months) = 65 months
    expect(cv.experienceYears, closeTo(5.4, 0.1));
  });

  test('places the CV in IT, mobile first', () {
    final cv = parser.parse(sampleCv);
    final r = const CategoryMatcher().match(skills: cv.skills, titles: cv.titles);
    expect(r.main?.id, 'it');
    expect(r.subs.first.sub.id, 'it_mobile');
    expect(r.subs.first.strength, 95);
  });

  test('scores a decent CV fairly and explains issues', () {
    final cv = parser.parse(sampleCv);
    final report = const AtsScorer().score(cv);
    expect(report.total, inInclusiveRange(55, 95));
    expect(report.parts.fold<int>(0, (s, p) => s + p.max), 100);
    expect(report.parts.every((p) => p.score >= 0 && p.score <= p.max), isTrue);
  });

  test('a nearly empty CV gets a low score with high-severity issues', () {
    final cv = parser.parse('Rahul\nLooking for a job.');
    final report = const AtsScorer().score(cv);
    expect(report.total, lessThan(40));
    expect(report.issues.first.severity, Severity.high);
  });

  test('date ranges in different formats', () {
    final ranges = parser.dateRanges('03/2019 - 08/2020\nSept 2020 to Present\n2015 – 2016');
    expect(ranges.length, 3);
    expect(ranges[0].months, 18);
  });
}
