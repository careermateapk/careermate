import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../profile/cv_parser.dart';
import 'job_models.dart';

/// Different spellings of the same city.
const _aliases = <String, List<String>>{
  'bangalore': ['bangalore', 'bengaluru'],
  'gurugram': ['gurugram', 'gurgaon'],
  'new delhi': ['new delhi', 'delhi'],
  'delhi': ['delhi', 'new delhi'],
  'mumbai': ['mumbai', 'bombay'],
  'chennai': ['chennai', 'madras'],
  'kolkata': ['kolkata', 'calcutta'],
  'mysuru': ['mysuru', 'mysore'],
  'prayagraj': ['prayagraj', 'allahabad'],
  'thiruvananthapuram': ['thiruvananthapuram', 'trivandrum'],
};

/// Cities close enough to commute, used by "Also show nearby cities".
const _nearby = <String, List<String>>{
  'delhi': ['noida', 'gurugram', 'gurgaon', 'ghaziabad', 'faridabad', 'greater noida', 'delhi ncr', 'ncr'],
  'new delhi': ['noida', 'gurugram', 'gurgaon', 'ghaziabad', 'faridabad', 'greater noida', 'delhi ncr', 'ncr'],
  'noida': ['delhi', 'new delhi', 'ghaziabad', 'greater noida', 'delhi ncr', 'ncr'],
  'gurugram': ['delhi', 'new delhi', 'faridabad', 'manesar', 'delhi ncr', 'ncr'],
  'ghaziabad': ['delhi', 'new delhi', 'noida', 'delhi ncr', 'ncr'],
  'faridabad': ['delhi', 'new delhi', 'gurugram', 'delhi ncr', 'ncr'],
  'mumbai': ['thane', 'navi mumbai', 'mira road', 'kalyan', 'vasai'],
  'thane': ['mumbai', 'navi mumbai', 'kalyan'],
  'navi mumbai': ['mumbai', 'thane', 'panvel'],
  'pune': ['pimpri', 'chinchwad', 'hinjewadi', 'pimpri-chinchwad'],
  'bangalore': ['electronic city', 'whitefield', 'hosur'],
  'hyderabad': ['secunderabad', 'gachibowli', 'hitec city'],
  'chennai': ['tambaram', 'sriperumbudur', 'guindy'],
  'kolkata': ['howrah', 'salt lake'],
  'ahmedabad': ['gandhinagar'],
  'chandigarh': ['mohali', 'panchkula', 'zirakpur'],
};

const popularCities = [
  'Delhi', 'Bangalore', 'Mumbai', 'Pune', 'Hyderabad', 'Chennai', 'Kolkata', 'Noida', 'Gurugram', 'Ahmedabad', 'Jaipur', 'Chandigarh',
];

String _key(String c) {
  final k = c.toLowerCase().trim();
  if (k == 'bengaluru') return 'bangalore';
  if (k == 'gurgaon') return 'gurugram';
  return k;
}

bool _hasWord(String text, String word) => CvParser.containsWord(text, word);

/// Whether [job] is in [city] (or close to it when [nearby] is on).
bool jobInCity(JobItem job, String city, {bool nearby = true}) {
  final loc = job.location.toLowerCase();
  final k = _key(city);
  final names = {..._aliases[k] ?? [k]};
  if (nearby) names.addAll(_nearby[k] ?? const []);
  return names.any((n) => _hasWord(loc, n));
}

/// Shows the city picker. Returns the chosen city, '' for all of India, or null if closed.
Future<(String, bool)?> pickCity(BuildContext context,
    {required String? current, required String cvCity, required bool nearby, required List<JobItem> jobs}) {
  return showModalBottomSheet<(String, bool)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _CitySheet(current: current, cvCity: cvCity, nearby: nearby, jobs: jobs),
  );
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.current, required this.cvCity, required this.nearby, required this.jobs});
  final String? current;
  final String cvCity;
  final bool nearby;
  final List<JobItem> jobs;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _q = '';
  late bool _nearby = widget.nearby;

  int _count(String c) => widget.jobs.where((j) => jobInCity(j, c, nearby: _nearby)).length;

  @override
  Widget build(BuildContext context) {
    final all = <String>{
      ...popularCities,
      for (final c in CvParser.cities.where((c) => c != 'remote')) c.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
    }.toList();
    final q = _q.toLowerCase();
    final results = q.isEmpty ? popularCities : (all.where((c) => c.toLowerCase().contains(q)).toList()..sort());
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose city', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: const InputDecoration(hintText: 'Search any city in India', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 12),
            if (widget.cvCity.isNotEmpty && q.isEmpty)
              _tile(widget.cvCity, 'From your CV · ${_count(widget.cvCity)} jobs', Icons.my_location_rounded),
            _tile('', 'All of India · ${widget.jobs.length} jobs', Icons.public_rounded, label: 'All cities'),
            const SizedBox(height: 10),
            Text(q.isEmpty ? 'POPULAR' : 'RESULTS',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in results.take(40))
                ChoiceChip(
                  label: Text('$c · ${_count(c)}'),
                  selected: widget.current != null && _key(widget.current!) == _key(c),
                  onSelected: (_) => Navigator.pop(context, (c, _nearby)),
                ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _nearby,
              onChanged: (v) => setState(() => _nearby = v),
              title: const Text('Also show nearby cities', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('e.g. Noida & Gurugram with Delhi, Thane with Mumbai'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tile(String city, String sub, IconData icon, {String? label}) {
    final selected = (widget.current ?? '') == city;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, (city, _nearby)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.blueTint : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: 1.5),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label ?? city, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? AppColors.navy : null)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            if (selected) const Icon(Icons.check_rounded, color: AppColors.blue),
          ]),
        ),
      ),
    );
  }
}
