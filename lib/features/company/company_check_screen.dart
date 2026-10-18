import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jobs/women_filter.dart' show companyKey;
import 'company_ids.dart';

class CompanyCheckArgs {
  const CompanyCheckArgs({this.company = '', this.email = '', this.text = ''});
  final String company;
  final String email;

  /// Job description or letter text, searched for a CIN / GSTIN.
  final String text;
}

class CompanyCheckScreen extends ConsumerStatefulWidget {
  const CompanyCheckScreen({super.key, this.args = const CompanyCheckArgs()});
  final CompanyCheckArgs args;
  @override
  ConsumerState<CompanyCheckScreen> createState() => _CompanyCheckScreenState();
}

class _CompanyCheckScreenState extends ConsumerState<CompanyCheckScreen> {
  late final _name = TextEditingController(text: widget.args.company);
  late final _cin = TextEditingController(text: findCin(widget.args.text) ?? '');
  late final _gst = TextEditingController(text: findGstin(widget.args.text) ?? '');
  late final _site = TextEditingController(
      text: widget.args.email.contains('@') && !widget.args.email.toLowerCase().contains('gmail') ? widget.args.email.split('@').last : '');
  bool? _siteOk;
  bool _checking = false;
  int _reports = 0;
  bool _reported = false;
  bool _ran = false;

  @override
  void dispose() {
    _name.dispose();
    _cin.dispose();
    _gst.dispose();
    _site.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _checking = true;
      _ran = true;
      _siteOk = null;
    });
    final site = _site.text.trim().replaceAll(RegExp(r'^https?://'), '').split('/').first;
    if (site.isNotEmpty) _siteOk = await _opens(site);
    try {
      final d = await ref.read(firestoreProvider).collection('company_reports').doc(companyKey(_name.text)).get();
      _reports = ((d.data()?['count'] as num?) ?? 0).toInt();
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  Future<bool> _opens(String host) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      for (final h in [host, 'www.$host']) {
        try {
          final req = await client.getUrl(Uri.https(h, '/')).timeout(const Duration(seconds: 8));
          final res = await req.close().timeout(const Duration(seconds: 8));
          await res.drain<void>();
          if (res.statusCode < 500) return true;
        } catch (_) {}
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _report() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _name.text.trim().isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report this company?'),
        content: const Text('Only if they asked you for money, lied about the job, or you believe it is fake.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Report')),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(firestoreProvider);
    final docRef = db.collection('company_reports').doc(companyKey(_name.text));
    try {
      await db.runTransaction((tx) async {
        final s = await tx.get(docRef);
        final by = List<String>.from(s.data()?['by'] as List? ?? const []);
        if (by.contains(uid)) return;
        tx.set(docRef, {'company': _name.text.trim(), 'count': by.length + 1, 'by': [...by, uid]});
      });
      if (mounted) {
        setState(() {
          _reported = true;
          _reports++;
        });
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not report. Update the Firebase rules and try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cin = decodeCin(_cin.text);
    final gst = decodeGstin(_gst.text);
    final age = cin == null ? null : DateTime.now().year - cin.year;
    final good = <String>[], warn = <String>[];
    if (_ran) {
      if (cin != null) {
        good.add('CIN is valid: ${cin.type}, registered in ${cin.state} in ${cin.year} (${age! <= 0 ? 'this year' : '$age years ago'}).');
        if (age <= 1) warn.add('The company is less than 2 years old — check it carefully.');
      } else if (_cin.text.trim().isNotEmpty) {
        warn.add('This CIN is not in the right format. A real CIN has 21 characters, like U74999DL2012PTC123456.');
      }
      if (gst != null) {
        (gst.valid ? good : warn).add(gst.valid
            ? 'GST number is valid (${gst.state} · ${gst.business}).'
            : 'GST number fails its check digit — it may be typed wrong or fake.');
      } else if (_gst.text.trim().isNotEmpty) {
        warn.add('This GST number is not in the right format (15 characters, like 27AAPFU0939F1ZV).');
      }
      if (_siteOk == true) good.add('Website ${_site.text.trim()} opens.');
      if (_siteOk == false) warn.add('Website ${_site.text.trim()} did not open.');
      final email = widget.args.email.toLowerCase();
      if (email.isNotEmpty) {
        final free = RegExp(r'@(gmail|yahoo|outlook|hotmail|rediffmail|ymail)\.').hasMatch(email);
        (free ? warn : good).add(free ? 'HR uses a free email ($email), not a company email.' : 'HR uses a company email ($email).');
      }
      (_reports == 0 ? good : warn).add(_reports == 0 ? 'No scam reports on CareerMate.' : '$_reports CareerMate user${_reports == 1 ? '' : 's'} reported this company.');
    }
    final verdict = !_ran
        ? null
        : warn.isEmpty && (cin != null || gst?.valid == true)
            ? ('Looks genuine', AppColors.green, Icons.verified_rounded)
            : warn.length >= 2 || _reports >= 2
                ? ('Be careful', AppColors.red, Icons.gpp_bad_rounded)
                : ('Check a little more', AppColors.amber, Icons.shield_outlined);

    return Scaffold(
      appBar: AppBar(title: const Text('Is this company real?')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Company name', prefixIcon: Icon(Icons.business_rounded))),
        const SizedBox(height: 10),
        TextField(
          controller: _cin,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'CIN (optional)', hintText: 'On the offer letter or website footer'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _gst,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'GST number (optional)'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        TextField(controller: _site, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Website (optional)', hintText: 'company.com')),
        const SizedBox(height: 12),
        LoadingButton(label: 'Check company', icon: Icons.fact_check_outlined, loading: _checking, onPressed: _run),
        if (verdict != null && !_checking) ...[
          const SizedBox(height: 16),
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: verdict.$2.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Icon(verdict.$3, color: verdict.$2, size: 34),
                const SizedBox(width: 12),
                Expanded(child: Text(verdict.$1, style: AppTheme.display(context, size: 19))),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final g in good) _line(Icons.check_circle_rounded, AppColors.green, g),
              for (final w in warn) _line(Icons.error_outline_rounded, AppColors.amber, w),
            ]),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://www.mca.gov.in/content/mca/global/en/mca/master-data/MDS.html'),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Confirm on the official MCA website'),
          ),
          TextButton.icon(
            onPressed: _reported ? null : _report,
            icon: const Icon(Icons.flag_rounded, color: AppColors.red, size: 18),
            label: Text(_reported ? 'Reported — thank you' : 'Report this company as fake', style: const TextStyle(color: AppColors.red)),
          ),
        ],
        const SizedBox(height: 10),
        const Text(
          'Shops and small firms are often not companies, so having no CIN isn’t always a scam. Never pay money to get a job.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
        ),
      ]),
    );
  }

  Widget _line(IconData i, Color c, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
        ]),
      );
}
