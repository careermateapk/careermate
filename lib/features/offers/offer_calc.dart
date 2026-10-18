/// One job offer as typed in (or read from an offer letter).
class Offer {
  Offer({
    this.company = '',
    this.ctcLakh = 0,
    this.variableLakh = 0,
    this.basicPct = 50,
    this.pfOnFullBasic = false,
    this.gratuityInCtc = true,
    this.noticeDays = 30,
    this.bondMonths = 0,
    this.bondAmount = 0,
    this.commuteMin = 30,
    this.weeklyOffs = 2,
    Set<String>? benefits,
  }) : benefits = benefits ?? {};

  String company;
  double ctcLakh, variableLakh, basicPct;
  bool pfOnFullBasic, gratuityInCtc;
  int noticeDays, bondMonths, bondAmount, commuteMin, weeklyOffs;
  Set<String> benefits;

  Map<String, dynamic> toJson() => {
        'company': company,
        'ctc': ctcLakh,
        'variable': variableLakh,
        'basicPct': basicPct,
        'pfFull': pfOnFullBasic,
        'gratuity': gratuityInCtc,
        'notice': noticeDays,
        'bondMonths': bondMonths,
        'bondAmount': bondAmount,
        'commute': commuteMin,
        'offs': weeklyOffs,
        'benefits': benefits.toList(),
      };

  factory Offer.fromJson(Map<String, dynamic> m) => Offer(
        company: m['company'] ?? '',
        ctcLakh: (m['ctc'] as num?)?.toDouble() ?? 0,
        variableLakh: (m['variable'] as num?)?.toDouble() ?? 0,
        basicPct: (m['basicPct'] as num?)?.toDouble() ?? 50,
        pfOnFullBasic: m['pfFull'] ?? false,
        gratuityInCtc: m['gratuity'] ?? true,
        noticeDays: (m['notice'] as num?)?.toInt() ?? 30,
        bondMonths: (m['bondMonths'] as num?)?.toInt() ?? 0,
        bondAmount: (m['bondAmount'] as num?)?.toInt() ?? 0,
        commuteMin: (m['commute'] as num?)?.toInt() ?? 30,
        weeklyOffs: (m['offs'] as num?)?.toInt() ?? 2,
        benefits: Set<String>.from(m['benefits'] ?? const []),
      );
}

class Pay {
  Pay({required this.monthlyInHand, required this.yearlyTax, required this.employeePf, required this.employerPf, required this.gratuity});
  final double monthlyInHand, yearlyTax, employeePf, employerPf, gratuity;
}

/// New tax regime slabs (FY 2025-26 onwards) with the ₹75,000 standard deduction and the 87A rebate up to ₹12 lakh.
double newRegimeTax(double taxable) {
  if (taxable <= 1200000) return 0;
  const slabs = [(400000.0, 0.0), (800000.0, 0.05), (1200000.0, 0.10), (1600000.0, 0.15), (2000000.0, 0.20), (2400000.0, 0.25), (double.infinity, 0.30)];
  var tax = 0.0, prev = 0.0;
  for (final (top, rate) in slabs) {
    if (taxable > prev) tax += ((taxable < top ? taxable : top) - prev) * rate;
    prev = top;
  }
  // Marginal relief just above ₹12 lakh: tax can't exceed the income above ₹12 lakh.
  final relief = taxable - 1200000;
  if (tax > relief) tax = relief;
  return tax * 1.04; // + 4% health & education cess
}

/// Estimated monthly take-home for an offer. Assumes ₹200/month professional tax.
Pay payOf(Offer o) {
  final ctc = o.ctcLakh * 100000;
  final variable = o.variableLakh * 100000;
  final basic = (ctc - variable) * o.basicPct / 100;
  final pfBase = o.pfOnFullBasic ? basic : (basic < 180000 ? basic : 180000);
  final employerPf = pfBase * 0.12;
  final employeePf = pfBase * 0.12;
  final gratuity = o.gratuityInCtc ? basic * 0.0481 : 0.0;
  final gross = ctc - employerPf - gratuity; // salary actually paid, incl. variable
  const pt = 2400.0;
  final taxable = gross - 75000;
  final tax = newRegimeTax(taxable < 0 ? 0 : taxable);
  final fixedGross = gross - variable;
  final taxOnFixed = gross <= 0 ? 0.0 : tax * (fixedGross / gross);
  final monthly = (fixedGross - employeePf - pt - taxOnFixed) / 12;
  return Pay(monthlyInHand: monthly < 0 ? 0 : monthly, yearlyTax: tax, employeePf: employeePf, employerPf: employerPf, gratuity: gratuity);
}

String rupees(num v) {
  final n = v.round();
  final s = n.abs().toString();
  if (s.length <= 3) return '₹${n < 0 ? '-' : ''}$s';
  final last = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${n < 0 ? '-' : ''}${[...parts, last].join(',')}';
}

/// Reads numbers from an offer letter's text. Everything is shown for the user to check.
Offer offerFromText(String text) {
  final t = text.toLowerCase().replaceAll(',', '');
  final o = Offer();
  final lpa = RegExp(r'(\d{1,2}(?:\.\d{1,2})?)\s*(?:lpa|lakhs? per annum|lakh p\.?a)').firstMatch(t);
  final ctcRs = RegExp(r'(?:ctc|cost to company|annual (?:gross )?(?:salary|compensation))[^0-9]{0,40}(?:rs\.?|inr|₹)?\s*(\d{5,8})').firstMatch(t);
  if (lpa != null) {
    o.ctcLakh = double.parse(lpa.group(1)!);
  } else if (ctcRs != null) {
    o.ctcLakh = double.parse(ctcRs.group(1)!) / 100000;
  }
  final notice = RegExp(r'notice period[^.]{0,40}?(\d{1,3})\s*(days|months?)').firstMatch(t);
  if (notice != null) {
    final n = int.parse(notice.group(1)!);
    o.noticeDays = notice.group(2)!.startsWith('month') ? n * 30 : n;
  } else if (RegExp(r'notice period[^.]{0,40}(three|3) months').hasMatch(t)) {
    o.noticeDays = 90;
  }
  final bond = RegExp(r'(?:bond|service agreement|minimum service)[^.]{0,60}?(\d{1,2})\s*(months?|years?)').firstMatch(t);
  if (bond != null) {
    final n = int.parse(bond.group(1)!);
    o.bondMonths = bond.group(2)!.startsWith('year') ? n * 12 : n;
    final amt = RegExp(r'(?:rs\.?|inr|₹)\s*(\d{4,7})').firstMatch(t.substring(bond.start));
    if (amt != null) o.bondAmount = int.parse(amt.group(1)!);
  }
  final variable = RegExp(r'(?:variable|performance (?:pay|bonus))[^0-9]{0,30}(?:rs\.?|inr|₹)?\s*(\d{4,7})').firstMatch(t);
  if (variable != null) o.variableLakh = double.parse(variable.group(1)!) / 100000;
  for (final (k, words) in const [
    ('cab', ['cab', 'transport']),
    ('health', ['medical insurance', 'health insurance', 'mediclaim']),
    ('food', ['meal', 'food', 'lunch']),
    ('wfh', ['work from home', 'hybrid']),
  ]) {
    if (words.any(t.contains)) o.benefits.add(k);
  }
  return o;
}
