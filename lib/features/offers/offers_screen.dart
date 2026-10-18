import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../community/post_reader.dart';
import '../profile/text_extractor.dart';
import 'offer_calc.dart';

class CompareOffersScreen extends StatefulWidget {
  const CompareOffersScreen({super.key});
  @override
  State<CompareOffersScreen> createState() => _CompareOffersScreenState();
}

class _CompareOffersScreenState extends State<CompareOffersScreen> {
  List<Offer> _offers = [Offer(company: 'Offer A'), Offer(company: 'Offer B')];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/offers.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        _offers = [for (final m in list) Offer.fromJson(Map<String, dynamic>.from(m as Map))];
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      await (await _file()).writeAsString(jsonEncode(_offers.map((o) => o.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _edit(int i) async {
    final o = Offer.fromJson(_offers[i].toJson());
    final r = await Navigator.of(context).push<Offer>(MaterialPageRoute(builder: (_) => _OfferForm(offer: o)));
    if (r == null) return;
    setState(() => _offers[i] = r);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final a = _offers[0], b = _offers[1];
    final pa = payOf(a), pb = payOf(b);
    final filled = a.ctcLakh > 0 && b.ctcLakh > 0;
    // Each row: label, A text, B text, which is better (0 = A, 1 = B, -1 = same / no judgement)
    int better(num x, num y, {bool lowerIsBetter = false}) => x == y ? -1 : ((x > y) != lowerIsBetter ? 0 : 1);
    final rows = <(String, String, String, int)>[
      ('In-hand / month', rupees(pa.monthlyInHand), rupees(pb.monthlyInHand), better(pa.monthlyInHand.round(), pb.monthlyInHand.round())),
      ('CTC', '₹${a.ctcLakh} L', '₹${b.ctcLakh} L', better(a.ctcLakh, b.ctcLakh)),
      ('Variable pay', a.variableLakh == 0 ? 'None' : '₹${a.variableLakh} L', b.variableLakh == 0 ? 'None' : '₹${b.variableLakh} L', -1),
      ('Notice period', '${a.noticeDays} days', '${b.noticeDays} days', better(a.noticeDays, b.noticeDays, lowerIsBetter: true)),
      ('Bond', a.bondMonths == 0 ? 'None' : '${a.bondMonths} mo${a.bondAmount > 0 ? ' · ${rupees(a.bondAmount)}' : ''}',
          b.bondMonths == 0 ? 'None' : '${b.bondMonths} mo${b.bondAmount > 0 ? ' · ${rupees(b.bondAmount)}' : ''}', better(a.bondMonths, b.bondMonths, lowerIsBetter: true)),
      ('Commute (one way)', '${a.commuteMin} min', '${b.commuteMin} min', better(a.commuteMin, b.commuteMin, lowerIsBetter: true)),
      ('Weekly off', '${a.weeklyOffs} day${a.weeklyOffs == 1 ? '' : 's'}', '${b.weeklyOffs} day${b.weeklyOffs == 1 ? '' : 's'}', better(a.weeklyOffs, b.weeklyOffs)),
      ('Benefits', _benefits(a), _benefits(b), better(a.benefits.length, b.benefits.length)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Compare 2 offers')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Row(children: [
          const Expanded(flex: 11, child: SizedBox()),
          for (final (i, o) in _offers.indexed)
            Expanded(
              flex: 10,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () => _edit(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: i == 0 ? const Color(0xFF1E3A8A) : const Color(0xFF4C1D95),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i == 0 ? 'Offer A' : 'Offer B', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      Text(o.company.isEmpty || o.company.startsWith('Offer') ? 'Tap to fill' : o.company,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFC9D8FF), fontSize: 11.5)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final r in rows)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)))),
                child: Row(children: [
                  Expanded(flex: 11, child: Text(r.$1, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13))),
                  for (final (i, v) in [r.$2, r.$3].indexed)
                    Expanded(
                      flex: 10,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(v,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: filled && r.$4 == i ? AppColors.green : null,
                            )),
                      ),
                    ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (filled)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF1E3A8A)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('IN SHORT', style: TextStyle(color: Color(0xFFDDD6FE), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
              const SizedBox(height: 6),
              Text(_summary(a, b, pa, pb), style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            ]),
          )
        else
          const AppCard(child: Text('Tap Offer A and Offer B to enter each offer, or read the numbers from the offer letter.')),
        const SizedBox(height: 10),
        const Text(
          'In-hand is an estimate: new tax regime, PF at 12%, ₹200/month professional tax. We show facts side by side — the choice is yours.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
        ),
      ]),
    );
  }

  static String _benefits(Offer o) {
    const names = {'cab': 'Cab', 'health': 'Health', 'food': 'Food', 'wfh': 'WFH'};
    final l = o.benefits.map((b) => names[b] ?? b).toList();
    return l.isEmpty ? '—' : l.join(', ');
  }

  static String _summary(Offer a, Offer b, Pay pa, Pay pb) {
    final na = a.company.startsWith('Offer') || a.company.isEmpty ? 'Offer A' : a.company;
    final nb = b.company.startsWith('Offer') || b.company.isEmpty ? 'Offer B' : b.company;
    final diff = (pa.monthlyInHand - pb.monthlyInHand).round();
    final parts = <String>[];
    if (diff.abs() >= 500) parts.add('${diff > 0 ? na : nb} pays about ${rupees(diff.abs())} more a month.');
    if (a.bondMonths != b.bondMonths) parts.add('${a.bondMonths < b.bondMonths ? na : nb} has ${a.bondMonths == 0 || b.bondMonths == 0 ? 'no bond' : 'a shorter bond'}.');
    if (a.noticeDays != b.noticeDays) parts.add('${a.noticeDays < b.noticeDays ? na : nb} has a shorter notice period.');
    final travel = ((a.commuteMin - b.commuteMin).abs() * 2 * 22 / 60).round();
    if (travel >= 3) parts.add('${a.commuteMin < b.commuteMin ? na : nb} saves about $travel hours of travel a month.');
    if (a.weeklyOffs != b.weeklyOffs) parts.add('${a.weeklyOffs > b.weeklyOffs ? na : nb} gives more weekly offs.');
    return parts.isEmpty ? 'Both offers look very similar on these points.' : parts.join(' ');
  }
}

class _OfferForm extends StatefulWidget {
  const _OfferForm({required this.offer});
  final Offer offer;
  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  late Offer o = widget.offer;
  int _rev = 0;
  bool _reading = false;

  Future<void> _fromLetter() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    if (file == null) return;
    setState(() => _reading = true);
    try {
      final bytes = await file.readAsBytes();
      String text;
      if (file.name.toLowerCase().endsWith('.pdf')) {
        text = (await const TextExtractor().extractSmart(file.name, bytes)).text;
      } else {
        final f = File('${(await getTemporaryDirectory()).path}/offer_${DateTime.now().millisecondsSinceEpoch}.png');
        await f.writeAsBytes(bytes);
        text = await PostReader.fromImage(f.path);
      }
      final r = offerFromText(text);
      setState(() {
        if (r.ctcLakh > 0) o.ctcLakh = r.ctcLakh;
        if (r.variableLakh > 0) o.variableLakh = r.variableLakh;
        o.noticeDays = r.noticeDays;
        o.bondMonths = r.bondMonths;
        o.bondAmount = r.bondAmount;
        o.benefits.addAll(r.benefits);
        _rev++;
      });
      if (mounted) showMessage(context, r.ctcLakh > 0 ? 'Filled from the letter — please check every number.' : 'Couldn’t find the CTC. Please type it.');
    } catch (_) {
      if (mounted) showMessage(context, 'Couldn’t read that file.', error: true);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Widget _num(String label, String value, void Function(String) set, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          key: ValueKey('$label-$_rev'),
          initialValue: value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, hintText: hint),
          onChanged: set,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pay = payOf(o);
    return Scaffold(
      appBar: AppBar(title: const Text('Offer details')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        OutlinedButton.icon(
          onPressed: _reading ? null : _fromLetter,
          icon: _reading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner_outlined),
          label: const Text('Read from offer letter (PDF or photo)'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          initialValue: o.company.startsWith('Offer') ? '' : o.company,
          decoration: const InputDecoration(labelText: 'Company'),
          onChanged: (v) => o.company = v.trim(),
        ),
        const SizedBox(height: 12),
        _num('CTC (lakh per year)', o.ctcLakh == 0 ? '' : '${o.ctcLakh}', (v) => setState(() => o.ctcLakh = double.tryParse(v) ?? 0), hint: '7.2'),
        _num('Variable / bonus part (lakh)', o.variableLakh == 0 ? '' : '${o.variableLakh}', (v) => setState(() => o.variableLakh = double.tryParse(v) ?? 0)),
        _num('Basic salary as % of fixed pay', '${o.basicPct.round()}', (v) => setState(() => o.basicPct = double.tryParse(v) ?? 50)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: o.pfOnFullBasic,
          onChanged: (v) => setState(() => o.pfOnFullBasic = v),
          title: const Text('PF on full basic (not capped at ₹15,000)'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: o.gratuityInCtc,
          onChanged: (v) => setState(() => o.gratuityInCtc = v),
          title: const Text('Gratuity is part of CTC'),
        ),
        _num('Notice period (days)', '${o.noticeDays}', (v) => o.noticeDays = int.tryParse(v) ?? 30),
        Row(children: [
          Expanded(child: _num('Bond (months)', '${o.bondMonths}', (v) => o.bondMonths = int.tryParse(v) ?? 0)),
          const SizedBox(width: 10),
          Expanded(child: _num('Bond amount (₹)', '${o.bondAmount}', (v) => o.bondAmount = int.tryParse(v) ?? 0)),
        ]),
        _num('Travel time one way (minutes)', '${o.commuteMin}', (v) => o.commuteMin = int.tryParse(v) ?? 30),
        Wrap(spacing: 8, children: [
          for (final d in [1, 2])
            ChoiceChip(label: Text('$d weekly off${d == 1 ? '' : 's'}'), selected: o.weeklyOffs == d, onSelected: (_) => setState(() => o.weeklyOffs = d)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (k, l) in const [('cab', '🚌 Cab'), ('health', '🩺 Health insurance'), ('food', '🍱 Food'), ('wfh', '🏠 WFH / hybrid')])
            FilterChip(
              label: Text(l),
              selected: o.benefits.contains(k),
              onSelected: (v) => setState(() => v ? o.benefits.add(k) : o.benefits.remove(k)),
            ),
        ]),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Estimated in-hand: ${rupees(pay.monthlyInHand)} / month', style: AppTheme.display(context, size: 16)),
            const SizedBox(height: 4),
            Text('Tax ${rupees(pay.yearlyTax)}/yr · your PF ${rupees(pay.employeePf / 12)}/mo · employer PF ${rupees(pay.employerPf / 12)}/mo',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(onPressed: () => Navigator.pop(context, o), child: const Text('Save offer')),
      ),
    );
  }
}
