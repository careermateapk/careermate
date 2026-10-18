import 'package:careermate/features/offers/offer_calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no tax up to 12 lakh taxable (new regime)', () {
    expect(newRegimeTax(1200000), 0);
    expect(newRegimeTax(1000000), 0);
  });

  test('tax above 12 lakh with marginal relief', () {
    // 12.1 L taxable → relief caps tax at ₹10,000 + cess
    expect(newRegimeTax(1210000), closeTo(10400, 1));
    // 16 L taxable: 20k + 40k + 60k = 1.2 L + cess
    expect(newRegimeTax(1600000), closeTo(124800, 1));
  });

  test('in-hand for a 7.2 L offer is sensible', () {
    final p = payOf(Offer(ctcLakh: 7.2));
    expect(p.yearlyTax, 0);
    expect(p.monthlyInHand, inInclusiveRange(52000, 58000));
  });

  test('rupee formatting', () {
    expect(rupees(5240000), '₹52,40,000');
    expect(rupees(52400), '₹52,400');
  });

  test('read offer letter text', () {
    final o = offerFromText('Your annual CTC will be Rs. 7,20,000. Notice period of 90 days. '
        'You agree to a service bond of 12 months, failing which Rs. 1,00,000 is payable. Medical insurance and cab facility provided.');
    expect(o.ctcLakh, closeTo(7.2, 0.001));
    expect(o.noticeDays, 90);
    expect(o.bondMonths, 12);
    expect(o.bondAmount, 100000);
    expect(o.benefits, containsAll(['cab', 'health']));
  });
}
