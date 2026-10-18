import 'package:careermate/features/company/company_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a CIN', () {
    final c = decodeCin('U74999DL2012PTC123456')!;
    expect(c.year, 2012);
    expect(c.state, 'Delhi');
    expect(c.type, 'Private limited company');
    expect(c.listed, isFalse);
    expect(decodeCin('NOT-A-CIN'), isNull);
  });

  test('checks GSTIN checksum', () {
    // Valid sample with a correct check character
    final ok = decodeGstin('27AAPFU0939F1ZV')!;
    expect(ok.valid, isTrue);
    expect(ok.state, 'Maharashtra');
    expect(ok.business, 'Firm / LLP');
    final bad = decodeGstin('27AAPFU0939F1ZA')!;
    expect(bad.valid, isFalse);
  });
}
