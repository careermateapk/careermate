import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../job_models.dart';

/// Opens other job sites' own search pages for the same role and city.
/// CareerMate does not copy jobs from these sites; the person applies there with their own account.
class OtherSite {
  const OtherSite(this.initials, this.name, this.bg, this.fg, this.build);
  final String initials;
  final String name;
  final Color bg;
  final Color fg;
  final Uri Function(String role, String city) build;
}

String _slug(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');

final otherSites = <OtherSite>[
  OtherSite('Li', 'LinkedIn Jobs', const Color(0xFFE0ECFA), const Color(0xFF0A5DB0), (r, c) => Uri.https(
      'www.linkedin.com', '/jobs/search/', {'keywords': r, if (c.isNotEmpty) 'location': '$c, India', 'f_TPR': 'r2592000'})),
  OtherSite('Nk', 'Naukri', const Color(0xFFE6F0FF), const Color(0xFF2453A6),
      (r, c) => Uri.https('www.naukri.com', c.isEmpty ? '/${_slug(r)}-jobs' : '/${_slug(r)}-jobs-in-${_slug(c)}')),
  OtherSite('In', 'Indeed', const Color(0xFFEEF0FF), const Color(0xFF3B3FB0),
      (r, c) => Uri.https('in.indeed.com', '/jobs', {'q': r, if (c.isNotEmpty) 'l': c, 'fromage': '30'})),
  OtherSite('Fo', 'Foundit', const Color(0xFFF3E8FF), const Color(0xFF6B21A8),
      (r, c) => Uri.https('www.foundit.in', '/srp/results', {'query': r, if (c.isNotEmpty) 'locations': c})),
  OtherSite('Ap', 'Apna', const Color(0xFFFEF3C7), const Color(0xFF92400E),
      (r, c) => Uri.https('apna.co', '/jobs', {'text': r, if (c.isNotEmpty) 'location': c})),
  OtherSite('G', 'Google Jobs', const Color(0xFFECFDF3), const Color(0xFF15803D),
      (r, c) => Uri.https('www.google.com', '/search', {'q': c.isEmpty ? '$r jobs' : '$r jobs in $c', 'ibp': 'htl;jobs'})),
  OtherSite('NC', 'National Career Service (Govt)', const Color(0xFFDCFCE7), const Color(0xFF166534),
      (r, c) => Uri.https('www.ncs.gov.in', '/')),
];

/// A cleaner search phrase: drops brackets, codes and "- Team" suffixes from job titles.
String searchRole(String title) {
  var t = title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), ' ');
  t = t.split(RegExp(r'\s[-–|/]\s')).first;
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.isEmpty ? title.trim() : t;
}

String searchCity(JobItem j) {
  final first = j.location.split(RegExp(r'[,;·]')).first.trim();
  final low = first.toLowerCase();
  if (low.isEmpty || low.contains('remote') || low == 'india' || low.contains('anywhere')) return '';
  return first;
}

Future<void> showOtherSites(BuildContext context, {required String role, required String city}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => _OtherSitesSheet(role: role, city: city),
  );
}

class _OtherSitesSheet extends StatelessWidget {
  const _OtherSitesSheet({required this.role, required this.city});
  final String role;
  final String city;

  Future<void> _go(BuildContext context, OtherSite s) async {
    final ok = await launchUrl(s.build(role, city), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showMessage(context, 'Could not open ${s.name}.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Search on other sites', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('We open each site’s own search page. Apply there with your own account.',
              style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Pill(role, dark: true, icon: Icons.search_rounded),
            if (city.isNotEmpty) _Pill(city),
            const _Pill('Last 30 days'),
          ]),
          const SizedBox(height: 8),
          for (final s in otherSites)
            InkWell(
              onTap: () => _go(context, s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)))),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(12)),
                    child: Text(s.initials, style: TextStyle(color: s.fg, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text(
                        s.initials == 'NC'
                            ? 'Opens the NCS website · search there'
                            : '${s.build(role, city).host.replaceFirst('www.', '')} · $role${city.isEmpty ? '' : ', $city'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ]),
                  ),
                  const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.blue),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? AppColors.blue.withValues(alpha: 0.16) : AppColors.blueTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue.withValues(alpha: dark ? 0.35 : 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 16, color: dark ? const Color(0xFF8FB0FF) : AppColors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Opens in your browser or the site’s app. CareerMate doesn’t copy jobs from these sites.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: dark ? const Color(0xFFDCE4F7) : AppColors.textBody)),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.dark = false, this.icon});
  final String text;
  final bool dark;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: dark ? AppColors.navy : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: dark ? Colors.white : null), const SizedBox(width: 6)],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: dark ? Colors.white : null)),
          ),
        ]),
      );
}

/// The small "Li Nk In  Search other sites" button used on job cards.
class OtherSitesButton extends StatelessWidget {
  const OtherSitesButton({super.key, required this.job});
  final JobItem job;

  @override
  Widget build(BuildContext context) {
    Widget mini(OtherSite s) => Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.white, width: 1.5)),
          child: Text(s.initials, style: TextStyle(color: s.fg, fontWeight: FontWeight.w900, fontSize: 9.5)),
        );
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        backgroundColor: AppColors.blueTint,
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: Color(0xFFC7D7FF), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => showOtherSites(context, role: searchRole(job.title), city: searchCity(job)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final s in otherSites.take(3)) mini(s),
        const SizedBox(width: 6),
        const Flexible(
          child: Text('Search other sites',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ]),
    );
  }
}
