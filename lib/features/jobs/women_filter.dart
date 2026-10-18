import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import 'benefits.dart';
import 'job_models.dart';

String companyKey(String company) => company.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');

/// How many CareerMate users recommend each company as a good workplace for women.
final womenRecsProvider = StreamProvider<Map<String, int>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(firestoreProvider).collection('women_recs').limit(500).snapshots().map((s) => {
        for (final d in s.docs) d.id: ((d.data()['count'] as num?) ?? 0).toInt(),
      });
});

Future<void> recommendForWomen(FirebaseFirestore db, String company, String uid) async {
  final ref = db.collection('women_recs').doc(companyKey(company));
  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final by = List<String>.from(snap.data()?['by'] as List? ?? const []);
    if (by.contains(uid)) return;
    tx.set(ref, {'company': company, 'count': by.length + 1, 'by': [...by, uid]});
  });
}

class WomenFilter {
  const WomenFilter({this.remote = false, this.dayOnly = false, this.nightNeedsCab = false, this.maternity = false, this.posh = false, this.recommended = false});
  final bool remote, dayOnly, nightNeedsCab, maternity, posh, recommended;

  int get count => [remote, dayOnly, nightNeedsCab, maternity, posh, recommended].where((b) => b).length;
  bool get active => count > 0;

  bool allows(JobItem j, Map<String, int> recs) {
    final p = perksOf(j);
    if (remote && !(p.contains(Perk.wfh) || p.contains(Perk.hybrid))) return false;
    if (dayOnly && (p.contains(Perk.nightShift) || p.contains(Perk.rotational))) return false;
    if (nightNeedsCab && (p.contains(Perk.nightShift) || p.contains(Perk.rotational)) && !p.contains(Perk.cab)) return false;
    if (maternity && !(p.contains(Perk.maternity) || p.contains(Perk.creche))) return false;
    if (posh && !p.contains(Perk.posh)) return false;
    if (recommended && (recs[companyKey(j.company)] ?? 0) == 0) return false;
    return true;
  }

  WomenFilter copyWith({bool? remote, bool? dayOnly, bool? nightNeedsCab, bool? maternity, bool? posh, bool? recommended}) => WomenFilter(
        remote: remote ?? this.remote,
        dayOnly: dayOnly ?? this.dayOnly,
        nightNeedsCab: nightNeedsCab ?? this.nightNeedsCab,
        maternity: maternity ?? this.maternity,
        posh: posh ?? this.posh,
        recommended: recommended ?? this.recommended,
      );
}

Future<WomenFilter?> pickWomenFilter(BuildContext context, WomenFilter current, int Function(WomenFilter f) countFor) {
  return showModalBottomSheet<WomenFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Sheet(current: current, countFor: countFor),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.current, required this.countFor});
  final WomenFilter current;
  final int Function(WomenFilter f) countFor;
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late WomenFilter _f = widget.current;

  Widget _t(String emoji, String text, bool v, WomenFilter Function(bool) set) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: v,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFFEC4899),
        onChanged: (x) => setState(() => _f = set(x)),
        title: Text('$emoji  $text', style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.countFor(_f);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Safe & flexible jobs', style: AppTheme.display(context, size: 19)),
          const SizedBox(height: 4),
          Text('$n jobs match', style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _t('🏠', 'Work from home / hybrid', _f.remote, (x) => _f.copyWith(remote: x)),
          _t('☀️', 'No night or rotational shifts', _f.dayOnly, (x) => _f.copyWith(dayOnly: x)),
          _t('🌙🚌', 'Night shift only with cab drop', _f.nightNeedsCab, (x) => _f.copyWith(nightNeedsCab: x)),
          _t('🤱', 'Maternity / creche benefits', _f.maternity, (x) => _f.copyWith(maternity: x)),
          _t('🛡️', 'POSH policy mentioned', _f.posh, (x) => _f.copyWith(posh: x)),
          _t('💬', 'Recommended for women by CareerMate users', _f.recommended, (x) => _f.copyWith(recommended: x)),
          const SizedBox(height: 6),
          const Text(
            'These come from what each job says. Many jobs don’t mention every benefit — ask HR to confirm.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, const WomenFilter()), child: const Text('Clear'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, _f), child: Text('Show $n jobs'))),
          ]),
        ]),
      ),
    );
  }
}
