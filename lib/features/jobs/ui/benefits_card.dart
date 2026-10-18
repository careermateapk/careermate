import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../benefits.dart';
import '../job_models.dart';
import '../women_filter.dart';

class BenefitsCard extends ConsumerStatefulWidget {
  const BenefitsCard({super.key, required this.job});
  final JobItem job;
  @override
  ConsumerState<BenefitsCard> createState() => _BenefitsCardState();
}

class _BenefitsCardState extends ConsumerState<BenefitsCard> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final perks = perksOf(j);
    final unknown = unknownBasics(perks);
    final recs = ref.watch(womenRecsProvider).value ?? const <String, int>{};
    final n = recs[companyKey(j.company)] ?? 0;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text('Benefits radar', style: AppTheme.display(context, size: 15))),
        ]),
        const SizedBox(height: 10),
        if (perks.isEmpty)
          const Text('This job doesn’t mention benefits like PF, cab or shift timing. Ask HR before you join.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in perks) StatusChip('${p.emoji} ${p.label}', tone: p.caution ? ChipTone.warning : ChipTone.positive),
          ]),
        if (unknown.isNotEmpty && perks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Not mentioned: ${unknown.map((u) => u == Perk.dayShift ? 'shift timing' : u.label).join(', ')} — ask HR.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ],
        if (j.company.trim().isNotEmpty) ...[
          const Divider(height: 22),
          Row(children: [
            const Text('💬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                n == 0 ? 'No one has recommended ${j.company} for women yet.' : '$n CareerMate user${n == 1 ? '' : 's'} recommend ${j.company} as a good workplace for women.',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _sent
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Recommend for women?'),
                          content: Text('Only if you have worked at ${j.company} and found it safe and respectful for women.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Recommend')),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      final uid = ref.read(authStateProvider).value?.uid;
                      if (uid == null) return;
                      try {
                        await recommendForWomen(ref.read(firestoreProvider), j.company, uid);
                        if (mounted) setState(() => _sent = true);
                      } catch (_) {
                        if (context.mounted) showMessage(context, 'Could not save. Update the Firebase rules and try again.', error: true);
                      }
                    },
              icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
              label: Text(_sent ? 'Thanks for recommending' : 'I worked here — recommend for women'),
            ),
          ),
        ],
      ]),
    );
  }
}
