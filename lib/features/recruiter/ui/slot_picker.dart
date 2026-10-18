import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';

String slotText(DateTime d) {
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${wd[d.weekday - 1]} ${d.day} ${mo[d.month - 1]} · $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}

/// Recruiter chooses up to 6 interview times and how the interview happens.
Future<(List<DateTime>, Map<String, String>)?> pickInterviewSlots(BuildContext context,
    {List<DateTime> initial = const [], Map<String, String> info = const {}}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SlotSheet(initial: initial, info: info),
  );
}

class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.initial, required this.info});
  final List<DateTime> initial;
  final Map<String, String> info;
  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late final List<DateTime> _slots = [...widget.initial.where((s) => s.isAfter(DateTime.now()))];
  late String _mode = widget.info['mode'] ?? 'Video call';
  late final _duration = TextEditingController(text: widget.info['duration'] ?? '30 minutes');
  late final _with = TextEditingController(text: widget.info['with'] ?? '');
  late final _where = TextEditingController(text: widget.info['where'] ?? '');

  Future<void> _add() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 60)), initialDate: now.add(const Duration(days: 1)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 0));
    if (t == null) return;
    final slot = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    if (slot.isBefore(now)) {
      if (mounted) showMessage(context, 'Choose a time in the future.', error: true);
      return;
    }
    setState(() => _slots
      ..add(slot)
      ..sort());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Offer interview times', style: AppTheme.display(context, size: 19)),
          const SizedBox(height: 4),
          const Text('The candidate picks one. Both of you get reminders.'),
          const SizedBox(height: 12),
          for (final (i, s) in _slots.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available_rounded),
              title: Text(slotText(s), style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _slots.removeAt(i))),
            ),
          if (_slots.length < 6)
            OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add_rounded), label: Text(_slots.isEmpty ? 'Add a time' : 'Add another time')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final m in ['Video call', 'Phone call', 'In office'])
              ChoiceChip(label: Text(m), selected: _mode == m, onSelected: (_) => setState(() => _mode = m)),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _duration, decoration: const InputDecoration(labelText: 'Duration & round', hintText: '45 minutes · Technical round')),
          const SizedBox(height: 10),
          TextField(controller: _with, decoration: const InputDecoration(labelText: 'Interviewer (optional)', hintText: 'Priya S., Accounts Manager')),
          if (_mode == 'In office') ...[
            const SizedBox(height: 10),
            TextField(controller: _where, decoration: const InputDecoration(labelText: 'Office address')),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _slots.isEmpty
                ? null
                : () => Navigator.pop(context, (
                      _slots,
                      {
                        'mode': _mode,
                        'duration': _duration.text.trim(),
                        if (_with.text.trim().isNotEmpty) 'with': _with.text.trim(),
                        if (_mode == 'In office' && _where.text.trim().isNotEmpty) 'where': _where.text.trim(),
                      }
                    )),
            child: Text('Send ${_slots.length} time${_slots.length == 1 ? '' : 's'} to candidate'),
          ),
        ]),
      ),
    );
  }
}
