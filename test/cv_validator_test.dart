import 'dart:convert';
import 'dart:typed_data';

import 'package:careermate/features/cv/cv_validator.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(latin1.encode(s));

void main() {
  const v = CvValidator();

  test('accepts a normal PDF', () {
    final r = v.check('cv.pdf', _bytes('%PDF-1.7\n1 0 obj\n<<>>\nendobj\n%%EOF\n'));
    expect(r.isValid, isTrue);
    expect(r.type, CvFileType.pdf);
    expect(r.mimeType, 'application/pdf');
  });

  test('rejects unsupported extension', () {
    expect(v.check('cv.doc', _bytes('anything')).isValid, isFalse);
    expect(v.check('cv', _bytes('anything')).isValid, isFalse);
  });

  test('rejects empty and too-large files', () {
    expect(v.check('cv.pdf', Uint8List(0)).error, contains('empty'));
    const small = CvValidator(maxBytes: 10);
    expect(small.check('cv.pdf', _bytes('%PDF-1.7 long content %%EOF')).error, contains('too large'));
  });

  test('rejects a renamed non-PDF', () {
    expect(v.check('cv.pdf', _bytes('hello world %%EOF')).error, contains('not a valid PDF'));
  });

  test('rejects a password-protected PDF', () {
    final r = v.check('cv.pdf', _bytes('%PDF-1.7\ntrailer << /Encrypt 5 0 R >>\n%%EOF'));
    expect(r.error, contains('password'));
  });

  test('rejects a truncated PDF', () {
    expect(v.check('cv.pdf', _bytes('%PDF-1.7\n1 0 obj')).error, contains('incomplete'));
  });

  test('accepts a DOCX and rejects a fake one', () {
    final docx = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, ...latin1.encode('....word/document.xml....')]);
    expect(v.check('CV.DOCX', docx).type, CvFileType.docx);
    expect(v.check('cv.docx', _bytes('not a zip')).isValid, isFalse);
  });
}
