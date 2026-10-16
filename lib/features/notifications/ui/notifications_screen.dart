import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _svc = NotificationService.instance;
  List<AppNotification> _items = const [];
  List<AppProgress> _progress = const [];
  NotifSettings _settings = const NotifSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _svc.changes.addListener(_load);
    _load();
    _refresh();
  }

  @override
  void dispose() {
    _svc.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _svc.items();
    final progress = await _svc.progress();
    final settings = await _svc.settings();
    if (!mounted) return;
    setState(() {
      _items = items;
      _progress = progress;
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    try {
      await _svc.checkNow();
    } catch (_) {}
    await _load();
  }

  Future<void> _setSettings(NotifSettings v) async {
    setState(() => _settings = v);
    await _svc.saveSettings(v);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final today = DateTime.now();
    final todayItems = _items.where((n) => _sameDay(n.at, today)).toList();
    final older = _items.where((n) => !_sameDay(n.at, today)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_items.any((n) => !n.read)) TextButton(onPressed: _svc.markAllRead, child: const Text('Mark all read')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
                for (final (i, p) in _progress.take(3).indexed) ...[
                  FadeSlideIn(index: i, child: _Timeline(p: p)),
                  const SizedBox(height: 12),
                ],
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(children: [
                      const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      const Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('We’ll tell you when HR views your application or new jobs arrive in your categories.',
                          textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
                    ]),
                  ),
                if (todayItems.isNotEmpty) ...[_label('TODAY'), for (final n in todayItems) _tile(n)],
                if (older.isNotEmpty) ...[_label('EARLIER'), for (final n in older) _tile(n)],
                const SizedBox(height: 8),
                _label('NOTIFY ME ABOUT'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Column(children: [
                    SwitchListTile(
                      value: _settings.applications,
                      onChanged: (v) => _setSettings(_settings.copyWith(applications: v)),
                      title: const Text('My applications', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Viewed, shortlisted, interview, rejected (jobs applied on CareerMate)'),
                    ),
                    SwitchListTile(
                      value: _settings.newJobs,
                      onChanged: (v) => _setSettings(_settings.copyWith(newJobs: v)),
                      title: const Text('New jobs in my categories', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('From the categories chosen from your CV'),
                    ),
                    SwitchListTile(
                      value: _settings.quietHours,
                      onChanged: (v) => _setSettings(_settings.copyWith(quietHours: v)),
                      title: const Text('Quiet hours', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('No alerts 10 pm – 8 am'),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your phone checks for updates about once an hour, so an alert can come a little after the change. '
                  'Pull down to check now.',
                  style: TextStyle(fontSize: 11.5, color: muted, height: 1.45),
                ),
              ]),
            ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 8),
        child: Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: AppColors.textMuted)),
      );

  Widget _tile(AppNotification n) {
    final (icon, bg, fg) = switch (n.kind) {
      'shortlisted' => (Icons.check_rounded, AppColors.greenTint, AppColors.green),
      'interview' => (Icons.event_rounded, const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
      'rejected' => (Icons.info_outline_rounded, AppColors.redTint, AppColors.red),
      'viewed' => (Icons.visibility_outlined, AppColors.blueTint, AppColors.blue),
      _ => (Icons.work_outline_rounded, AppColors.amberTint, AppColors.amber),
    };
    final t = n.at;
    final time = '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
    final date = _sameDay(t, DateTime.now()) ? time : '${t.day}/${t.month} · $time';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: fg, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(n.body, style: const TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.35)),
              const SizedBox(height: 4),
              Text(date, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ),
          if (!n.read)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 6, left: 6),
              decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.p});
  final AppProgress p;

  @override
  Widget build(BuildContext context) {
    final rejected = p.status == 'rejected';
    final steps = <(String, DateTime?, bool)>[
      ('Applied', p.appliedAt, true),
      ('HR viewed', p.viewedAt, p.viewedAt != null || p.status != 'new'),
      (rejected ? 'Not selected' : 'Shortlisted', p.status == 'shortlisted' ? p.updatedAt : null,
          ['shortlisted', 'interview', 'rejected'].contains(p.status)),
      ('Interview', p.status == 'interview' ? p.updatedAt : null, p.status == 'interview'),
    ];
    final doneCount = steps.where((s) => s.$3).length;
    final (chip, tone) = switch (p.status) {
      'shortlisted' => ('Shortlisted', ChipTone.positive),
      'interview' => ('Interview', ChipTone.positive),
      'rejected' => ('Not selected', ChipTone.risk),
      _ => (p.viewedAt != null ? 'HR viewed' : 'Applied', ChipTone.info),
    };
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${p.title} · ${p.company}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          StatusChip(chip, tone: tone),
        ]),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final seg = w / steps.length;
          return SizedBox(
            height: 62,
            child: Stack(children: [
              Positioned(left: seg / 2, right: seg / 2, top: 12, child: Container(height: 3, color: AppColors.line)),
              Positioned(
                left: seg / 2,
                top: 12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (doneCount - 1).clamp(0, 3) * seg),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => Container(width: v, height: 3, color: rejected ? AppColors.red : AppColors.green),
                ),
              ),
              Row(children: [
                for (final (i, s) in steps.indexed)
                  SizedBox(
                    width: seg,
                    child: Column(children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.$3 ? (rejected && i == 2 ? AppColors.red : AppColors.green) : Theme.of(context).cardColor,
                          border: s.$3 ? null : Border.all(color: AppColors.border, width: 2.5),
                          boxShadow: s.$3 && i == doneCount - 1
                              ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.25), spreadRadius: 5)]
                              : null,
                        ),
                        child: s.$3 ? Icon(rejected && i == 2 ? Icons.close_rounded : Icons.check_rounded, size: 15, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 5),
                      Text(s.$1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      if (s.$2 != null)
                        Text('${s.$2!.day}/${s.$2!.month}', style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    ]),
                  ),
              ]),
            ]),
          );
        }),
      ]),
    );
  }
}
