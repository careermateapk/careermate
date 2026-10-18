/// Reads facts that are built into Indian company and GST numbers — works offline, no data source needed.

const _cinStates = {
  'AN': 'Andaman & Nicobar', 'AP': 'Andhra Pradesh', 'AR': 'Arunachal Pradesh', 'AS': 'Assam', 'BR': 'Bihar', 'CH': 'Chandigarh',
  'CT': 'Chhattisgarh', 'DL': 'Delhi', 'DN': 'Dadra & Nagar Haveli', 'GA': 'Goa', 'GJ': 'Gujarat', 'HP': 'Himachal Pradesh',
  'HR': 'Haryana', 'JH': 'Jharkhand', 'JK': 'Jammu & Kashmir', 'KA': 'Karnataka', 'KL': 'Kerala', 'LD': 'Lakshadweep',
  'MH': 'Maharashtra', 'ML': 'Meghalaya', 'MN': 'Manipur', 'MP': 'Madhya Pradesh', 'MZ': 'Mizoram', 'NL': 'Nagaland',
  'OR': 'Odisha', 'PB': 'Punjab', 'PY': 'Puducherry', 'RJ': 'Rajasthan', 'SK': 'Sikkim', 'TG': 'Telangana', 'TN': 'Tamil Nadu',
  'TR': 'Tripura', 'UP': 'Uttar Pradesh', 'UR': 'Uttarakhand', 'WB': 'West Bengal',
};

const _cinTypes = {
  'PTC': 'Private limited company', 'PLC': 'Public limited company', 'OPC': 'One person company',
  'NPL': 'Not-for-profit (Section 8) company', 'GOI': 'Central government company', 'SGC': 'State government company',
  'FTC': 'Subsidiary of a foreign company', 'GAT': 'Guarantee & association company', 'GAP': 'Guarantee & association (public)',
  'ULL': 'Unlimited liability company', 'ULT': 'Unlimited liability (private)', 'FLC': 'Financial lease company',
};

class CinInfo {
  CinInfo({required this.listed, required this.state, required this.year, required this.type, required this.industryCode});
  final bool listed;
  final String state;
  final int year;
  final String type;
  final String industryCode;
}

/// CIN looks like U74999DL2012PTC123456 (21 characters).
CinInfo? decodeCin(String raw) {
  final c = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
  final m = RegExp(r'^([LU])(\d{5})([A-Z]{2})(\d{4})([A-Z]{3})(\d{6})$').firstMatch(c);
  if (m == null) return null;
  final year = int.parse(m.group(4)!);
  if (year < 1850 || year > DateTime.now().year) return null;
  return CinInfo(
    listed: m.group(1) == 'L',
    industryCode: m.group(2)!,
    state: _cinStates[m.group(3)] ?? m.group(3)!,
    year: year,
    type: _cinTypes[m.group(5)] ?? m.group(5)!,
  );
}

const _gstStates = {
  '01': 'Jammu & Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab', '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana',
  '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar', '11': 'Sikkim', '12': 'Arunachal Pradesh',
  '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram', '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam', '19': 'West Bengal',
  '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh', '23': 'Madhya Pradesh', '24': 'Gujarat',
  '26': 'Dadra & Nagar Haveli and Daman & Diu', '27': 'Maharashtra', '29': 'Karnataka', '30': 'Goa', '31': 'Lakshadweep',
  '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry', '35': 'Andaman & Nicobar', '36': 'Telangana', '37': 'Andhra Pradesh',
  '38': 'Ladakh', '97': 'Other territory',
};

class GstInfo {
  GstInfo({required this.valid, required this.state, required this.pan, required this.business});
  final bool valid;
  final String state;
  final String pan;

  /// From the 4th letter of the PAN: Company, Firm, Person, Trust…
  final String business;
}

const _panTypes = {
  'C': 'Company', 'P': 'Individual / proprietor', 'F': 'Firm / LLP', 'H': 'Hindu undivided family', 'A': 'Association of persons',
  'T': 'Trust', 'B': 'Body of individuals', 'L': 'Local authority', 'J': 'Artificial juridical person', 'G': 'Government',
};

/// GSTIN: 2-digit state + 10-character PAN + entity + Z + check character.
GstInfo? decodeGstin(String raw) {
  final g = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(g)) return null;
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  var sum = 0;
  for (var i = 0; i < 14; i++) {
    final p = chars.indexOf(g[i]) * (i.isEven ? 1 : 2);
    sum += p ~/ 36 + p % 36;
  }
  final check = chars[(36 - sum % 36) % 36];
  final pan = g.substring(2, 12);
  return GstInfo(
    valid: check == g[14],
    state: _gstStates[g.substring(0, 2)] ?? 'Unknown state code ${g.substring(0, 2)}',
    pan: pan,
    business: _panTypes[pan[3]] ?? 'Other',
  );
}

/// Finds a CIN or GSTIN inside any text (offer letter, job post).
String? findCin(String text) => RegExp(r'\b[LU]\d{5}[A-Z]{2}\d{4}[A-Z]{3}\d{6}\b').firstMatch(text.toUpperCase())?.group(0);
String? findGstin(String text) => RegExp(r'\b\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]\b').firstMatch(text.toUpperCase())?.group(0);
