import 'package:archive/archive.dart';
import 'package:careermate/features/resume/doc_builders.dart';
import 'package:careermate/features/resume/pdf_builder.dart';
import 'package:careermate/features/resume/resume_data.dart';
import 'package:careermate/features/resume/templates.dart';
import 'package:flutter_test/flutter_test.dart';

ResumeData longCv() => ResumeData(
      name: 'Rahul Kumar Verma',
      headline: 'Manager – Accounts Payable',
      email: 'rahul@example.com',
      phone: '98765 01234',
      city: 'New Delhi',
      summary: 'Accounts professional with 8 years of experience in AP, AR, GST and TDS. ₹ amounts “quoted” here… ' * 3,
      jobs: [
        for (var i = 0; i < 7; i++)
          ResumeJob(role: 'Accounts Executive $i', company: 'Company $i Pvt Ltd', city: 'New Delhi', start: '01/201$i', end: 'Present', bullets: [
            for (var k = 0; k < 6; k++) 'Managed end-to-end accounts payable and receivable, vendor payments and reconciliation, point $k.',
          ]),
      ],
      education: [ResumeEdu(degree: 'B.Com (Hons)', school: 'Delhi University', city: 'New Delhi', start: '2017', end: '2020')],
      skills: [for (var i = 0; i < 20; i++) 'Skill $i'],
      languages: ['English', 'Hindi'],
      certifications: ['CA Inter', 'GST Practitioner'],
    );

void main() {
  test('there are 40 templates in 5 categories', () {
    expect(resumeTemplates.length, 40);
    expect(resumeTemplates.map((t) => t.id).toSet().length, 40);
    for (final c in resumeCategories) {
      expect(resumeTemplates.where((t) => t.category == c), isNotEmpty);
    }
  });

  test('every template builds a multi-page PDF without errors', () async {
    final d = longCv();
    for (final t in resumeTemplates) {
      final bytes = await ResumePdf(d, t).build();
      expect(bytes.length, greaterThan(1000), reason: t.id);
    }
  });

  test('every template builds a short PDF', () async {
    for (final t in resumeTemplates) {
      final bytes = await ResumePdf(ResumeData.sample(), t).build();
      expect(bytes.length, greaterThan(1000), reason: t.id);
    }
  });

  test('DOCX and TXT are created', () {
    final docx = buildDocx(longCv(), resumeTemplates.first);
    final zip = ZipDecoder().decodeBytes(docx);
    expect(zip.files.map((f) => f.name), contains('word/document.xml'));
    final txt = buildTxt(longCv());
    expect(txt, contains('EXPERIENCE'));
    expect(txt, contains('RAHUL KUMAR VERMA'));
  });

  test('import jobs from CV text', () {
    const text = '''
Summary
Accounts professional with 8 years of experience.
Manager - Accounts Receivable, Easy Logistics Pvt Ltd, New Delhi
10/2025 - Pr ese nt
• Managed accounts payable
• Led a team of 4
Accounts Executive, Sharma & Associates, New Delhi
06/2019 - 01 /2021
• Prepared Form 15CA
Education
05/2017 - 12/2020
''';
    final d = ResumeData();
    ResumeData.importForTest(d, text);
    expect(d.jobs.length, 2);
    expect(d.jobs.first.company, 'Easy Logistics Pvt Ltd');
    expect(d.jobs.first.end, 'Present');
    expect(d.jobs.first.bullets.length, 2);
    expect(d.summary, contains('8 years'));
  });

  test('private-use bullets and OCR job titles', () {
    const text = 'Manager - Accounts Receivable, Easy Shipping India Private Limited, New Delhi\n'
        'Sr. Accounts & Finance Executive, HV freight private Limited, New Delhi\n'
        'B.COM (HONS), School of Open Learning, Delhi university, New Delhi\n'
        '<<<pdf-text>>>\n'
        'Dynamic Accounts Executive with over 8 years of experience.\n'
        '10/2025 - Present\n'
        ' Managed end-to-end operations, including\n'
        'invoice processing.\n'
        ' Supervised and led a team of 4 members.\n'
        '07/2024 - 10 /2025\n'
        ' Worked as AR professional.\n'
        'with accuracy\n';
    final d = ResumeData();
    ResumeData.importForTest(d, text);
    expect(d.jobs.length, 2);
    expect(d.jobs[0].bullets.length, 2);
    expect(d.jobs[0].role, 'Manager - Accounts Receivable');
    expect(d.jobs[0].company, 'Easy Shipping India Private Limited');
    expect(d.jobs[1].role, 'Sr. Accounts & Finance Executive');
  });

  test('PDF text has no unsupported dash symbols', () {
    expect(clean('10/2025 – Present'), '10/2025 - Present');
    expect(clean('Manager — AP '), 'Manager - AP ');
  });
}
