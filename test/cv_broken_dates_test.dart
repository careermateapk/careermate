import 'package:careermate/features/profile/cv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text like a PDF whose name/headings were images (read by OCR first),
/// followed by the PDF text layer with broken dates ("01 /2 01 8", "Pr ese nt").
const ocrCv = '''
RAHUL KUMAR VERMA
MANAGER - AP
Professional Summary
Employment History
Manager - Accounts Receivable, Easy Logistics Private Limited, New Delhi
Sr. Accounts & Finance Executive, Blue Freight Private Limited, New Delhi
Personal Details
9876501234
rahul.verma@example.com
Skills
Accounts & Taxation Executive, P.K. Rao & Co., New Delhi
Accounts Executive, Sharma & Associates, New Delhi
Education
B.COM (HONS), Delhi University, New Delhi
<<<pdf-text>>>
MANAGER - AP
Dynamic Accounts Executive with over 8 years of experience in optimizing financial operations.
10/2025 - Pr ese nt
 Managed end-to-end Accounts Payable and Receivable operations.
 Supervised and led a team of 4 members.
07/ 2024 - 10 /2025
 Handled invoice generation, GST, TDS and bank reconciliation in Tally.
03/2021 - 06 /2024
 Maintained general ledger entries.
06/2019 - 01 /2021
 Prepared and filed Form 15CA & 15CB.
01 /2 01 8 - 05/ 201 9
 Worked in MCA and Compliance department.
Education
05/201 7 - 1 2/2020
11/2021 - 11 /2021
Projects
08/201 9 - 03/ 2020
 Performed internal audit procedures.
01 /2 02 1 - 02/ 2021
 Prepared GST returns.
''';

void main() {
  test('normalize fixes spaced dates and words', () {
    expect(CvParser.normalize('01 /2 01 8 - 05/ 201 9'), '01/2018 - 05/2019');
    expect(CvParser.normalize('10/2025 - Pr ese nt'), '10/2025 - Present');
    expect(CvParser.normalize('05/201 7 - 1 2/2020'), '05/2017 - 12/2020');
  });

  test('experience counts jobs only, city from job lines', () {
    final cv = CvParser(now: DateTime(2026, 10)).parse(ocrCv);
    expect(cv.experienceYears, inInclusiveRange(8.6, 8.9));
    expect(cv.location, 'New Delhi');
    expect(cv.email, 'rahul.verma@example.com');
    expect(cv.phone, '9876501234');
    expect(cv.name, 'Rahul Kumar Verma');
    expect(cv.sections.containsKey('experience'), isTrue);
  });
}
