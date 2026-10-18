import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../recruiter/posted_job.dart';
import '../../recruiter/ui/slot_picker.dart';

/// Candidate picks one of the interview times a recruiter offered.
class PickSlotScreen extends ConsumerStatefulWidget {
  const PickSlotScreen({super.key, required this.jobId});
  final String jobId;
  @override
  ConsumerState<PickSlotScreen> createState() => _PickSlotScreenState();
}

class _PickSlotScreenState extends ConsumerState<PickSlotScreen> {
  DateTime? _pick;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final db = ref.watch(firestoreProvider);
    if (uid == null) return const Scaffold();
    final jobRef = db.collection('posted_jobs').doc(widget.jobId);
    return StreamBuilder(
      stream: jobRef.collection('applications').doc(uid).snapshots(),
      builder: (context, snap) {
        final app = snap.data == null || !snap.data!.exists ? null : Application.fromDoc(snap.data!);
        return FutureBuilder(
          future: jobRef.get(),
          builder: (context, jobSnap) {
            final jm = jobSnap.data?.data() ?? const <String, dynamic>{};
            final title = '${jm['title'] ?? 'Interview'}${(jm['company'] ?? '').toString().isEmpty ? '' : ' · ${jm['company']}'}';
            final slots = (app?.slots ?? const <DateTime>[]).where((s) => s.isAfter(DateTime.now())).toList()..sort();
            final chosen = app?.chosenSlot;
            final pick = _pick ?? chosen;
            final byDay = <String, List<DateTime>>{};
            for (final s in slots) {
              (byDay['${s.year}-${s.month}-${s.day}'] ??= []).add(s);
            }
            return Scaffold(
              appBar: AppBar(
                title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pick your interview time'),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ]),
              ),
              body: app == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                        child: Text(
                          chosen == null ? '🎉 You’re shortlisted! The recruiter shared these times. Choose one.' : '✅ Booked for ${slotText(chosen)}. You can change it below.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (slots.isEmpty) const Text('No upcoming times. The recruiter may send new ones.'),
                      for (final day in byDay.values) ...[
                        Text(slotText(day.first).split(' · ').first, style: AppTheme.display(context, size: 15)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in day)
                            ChoiceChip(
                              label: Text(slotText(s).split(' · ').last, style: const TextStyle(fontWeight: FontWeight.w800)),
                              selected: pick == s,
                              selectedColor: AppColors.green,
                              onSelected: (_) => setState(() => _pick = s),
                            ),
                        ]),
                        const SizedBox(height: 14),
                      ],
                      AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('DETAILS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                          const SizedBox(height: 6),
                          Text('📍 ${app.slotInfo['mode'] ?? 'Interview'}${app.slotInfo['where'] != null ? ' · ${app.slotInfo['where']}' : ''}'),
                          if ((app.slotInfo['duration'] ?? '').isNotEmpty) Text('⏱ ${app.slotInfo['duration']}'),
                          if ((app.slotInfo['with'] ?? '').isNotEmpty) Text('👤 ${app.slotInfo['with']}'),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      const Text('You get reminders the evening before and about an hour before.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ]),
              bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: LoadingButton(
                  label: pick == null ? 'Choose a time' : 'Confirm ${slotText(pick)}',
                  loading: _busy,
                  onPressed: pick == null || pick == chosen
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await ref.read(recruiterRepositoryProvider).chooseSlot(widget.jobId, uid, pick);
                            if (context.mounted) {
                              showMessage(context, 'Interview booked. The recruiter can see your time.');
                              Navigator.of(context).maybePop();
                            }
                          } catch (_) {
                            if (context.mounted) showMessage(context, 'Could not book. Try again.', error: true);
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
