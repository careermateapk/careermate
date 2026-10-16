import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

/// Live summary written by the job collector: how many jobs each free source gave in the last run.
final jobsMetaProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final snap = await ref.watch(firestoreProvider).doc('meta/jobs').get();
  return snap.data();
});

class _SourceInfo {
  const _SourceInfo(this.initials, this.label, this.kind, this.bg, this.fg);
  final String initials;
  final String label;
  final String kind;
  final Color bg;
  final Color fg;
}

const _info = <String, _SourceInfo>{
  'Adzuna': _SourceInfo('Ad', 'Adzuna', 'Job search API (India)', Color(0xFFFEF3C7), Color(0xFFB45309)),
  'Greenhouse': _SourceInfo('Gh', 'Greenhouse', 'Company career pages', Color(0xFFEEF3FF), Color(0xFF1E4FD6)),
  'Lever': _SourceInfo('Lv', 'Lever', 'Company career pages', Color(0xFFEEF3FF), Color(0xFF1E4FD6)),
  'Ashby': _SourceInfo('As', 'Ashby', 'Company career pages', Color(0xFFEEF3FF), Color(0xFF1E4FD6)),
  'SmartRecruiters': _SourceInfo('Sr', 'SmartRecruiters', 'Company career pages', Color(0xFFEEF3FF), Color(0xFF1E4FD6)),
  'Workable': _SourceInfo('Wk', 'Workable', 'Company career pages', Color(0xFFEEF3FF), Color(0xFF1E4FD6)),
  'Recruitee': _SourceInfo('Re', 'Recruitee', 'Company career pages', Color(0xFFE0F2FE), Color(0xFF0369A1)),
  'Teamtailor': _SourceInfo('Tt', 'Teamtailor', 'Company career pages', Color(0xFFE0F2FE), Color(0xFF0369A1)),
  'Personio': _SourceInfo('Pe', 'Personio', 'Company career pages', Color(0xFFF3E8FF), Color(0xFF7E22CE)),
  'Breezy': _SourceInfo('Bz', 'Breezy', 'Company career pages', Color(0xFFF3E8FF), Color(0xFF7E22CE)),
  'Jobicy': _SourceInfo('Jb', 'Jobicy', 'Remote jobs open to India', Color(0xFFFFE4E6), Color(0xFFBE123C)),
  'Arbeitnow': _SourceInfo('Ar', 'Arbeitnow', 'Remote jobs open to India', Color(0xFFF1F5F9), Color(0xFF334155)),
};

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(jobsMetaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Where jobs come from')),
      body: meta.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (m) {
          final sources = <MapEntry<String, int>>[];
          final raw = (m?['sources'] as Map?) ?? {};
          raw.forEach((k, v) => sources.add(MapEntry('$k', ((v as Map?)?['jobs'] as num?)?.toInt() ?? 0)));
          sources.sort((a, b) => b.value.compareTo(a.value));
          final maxN = sources.isEmpty ? 1 : sources.first.value.clamp(1, 1 << 30);
          final total = (m?['total'] as num?)?.toInt() ?? 0;
          final updated = DateTime.tryParse('${m?['updatedAt'] ?? ''}')?.toLocal();
          final active = sources.where((e) => e.value > 0).length;
          return ListView(padding: const EdgeInsets.all(20), children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2F6BFF), Color(0xFF1E3FAE)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Jobs in India · last 30 days',
                      style: TextStyle(color: Color(0xFFC9D8FF), fontWeight: FontWeight.w700, fontSize: 12.5)),
                  Text('$total', style: AppTheme.display(context, size: 32, color: Colors.white)),
                  Text(
                    'from $active sources${updated == null ? '' : ' · updated ${_ago(updated)}'} · checked every 6 hours',
                    style: const TextStyle(color: Color(0xFFC9D8FF), fontSize: 12),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 1,
              child: AppCard(
                child: Column(children: [
                  for (final e in sources.where((e) => e.value > 0)) _row(e.key, e.value, maxN),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Only sources that let apps use their jobs for free are included, and each job links back to where it came from. '
              'LinkedIn, Naukri, Indeed and others open through the “Search other sites” button on every job.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
            ),
          ]);
        },
      ),
    );
  }

  static String _ago(DateTime d) {
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 60) return '$m min ago';
    if (m < 60 * 24) return '${m ~/ 60} h ago';
    return '${m ~/ (60 * 24)} days ago';
  }

  Widget _row(String key, int n, int maxN) {
    final i = _info[key] ?? _SourceInfo(key.characters.take(2).toString(), key, 'Job source', const Color(0xFFF1F3F8), const Color(0xFF5B6478));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: i.bg, borderRadius: BorderRadius.circular(11)),
          child: Text(i.initials, style: TextStyle(color: i.fg, fontWeight: FontWeight.w900, fontSize: 12.5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(i.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
              Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
            Text(i.kind, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            const SizedBox(height: 5),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: n / maxN),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: v, minHeight: 5, color: i.fg, backgroundColor: const Color(0xFFEEF1F7)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
