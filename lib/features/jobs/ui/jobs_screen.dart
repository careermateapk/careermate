import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/profile_repository.dart';
import '../job_models.dart';
import 'other_sites.dart';

enum _Filter { all, remote, myCity, fresher, official }

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final jobsAsync = ref.watch(jobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find jobs'), actions: [
        IconButton(
          tooltip: 'Where jobs come from',
          icon: const Icon(Icons.hub_outlined),
          onPressed: () => context.push(Routes.sources),
        ),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: profile == null || profile.subCategoryIds.isEmpty
              ? _NeedProfile()
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(jobsProvider.future),
                  child: jobsAsync.when(
                    loading: () => const _LoadingList(),
                    error: (e, _) => _Message(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load jobs',
                      body: e.toString().contains('permission')
                          ? 'The database rules need updating. Paste the new rules in Firebase → Firestore → Rules.'
                          : 'Check your internet connection and pull down to try again.',
                    ),
                    data: (data) => _list(context, profile, data),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, CareerProfile profile, JobsData data) {
    final city = profile.location.toLowerCase().trim();
    final q = _query.toLowerCase();
    final matches = data.jobs.map((j) => JobMatch.of(j, profile)).where((m) {
      final j = m.job;
      if (q.isNotEmpty && !('${j.title} ${j.company} ${j.location}'.toLowerCase().contains(q))) return false;
      return switch (_filter) {
        _Filter.all => true,
        _Filter.remote => j.remote,
        _Filter.myCity => city.isNotEmpty && j.location.toLowerCase().contains(city),
        _Filter.fresher => j.looksFresherFriendly,
        _Filter.official => j.official,
      };
    }).toList()
      ..sort((a, b) {
        if (a.job.isCareerMate != b.job.isCareerMate) return a.job.isCareerMate ? -1 : 1;
        return b.score.compareTo(a.score);
      });

    final updated = data.updatedAt;
    final updatedText = updated == null ? 'not collected yet' : 'updated ${_ago(updated)}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search title, company or city',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _Filter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(switch (f) {
                    _Filter.all => 'All',
                    _Filter.remote => 'Remote',
                    _Filter.myCity => profile.location.isEmpty ? 'My city' : profile.location,
                    _Filter.fresher => 'Fresher / intern',
                    _Filter.official => 'Company sites only',
                  }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: updated == null ? AppColors.amber : AppColors.green, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${matches.length} jobs · last 30 days · $updatedText',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 12),
        if (data.jobs.isEmpty)
          const _Message(
            icon: Icons.hourglass_top_rounded,
            title: 'Jobs are being collected',
            body: 'We gather new jobs from company career sites every few hours. Pull down to refresh later.',
          )
        else if (matches.isEmpty)
          const _Message(icon: Icons.filter_alt_off_rounded, title: 'No jobs for this filter', body: 'Try another filter or clear your search.')
        else
          for (var i = 0; i < matches.length; i++) ...[
            FadeSlideIn(index: i < 8 ? i : 8, child: _JobCard(match: matches[i])),
            const SizedBox(height: 10),
          ],
        if (data.jobs.isNotEmpty && data.jobs.any((j) => j.isAdzuna))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Some jobs by Adzuna.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
      ],
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} days ago';
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.match});
  final JobMatch match;

  @override
  Widget build(BuildContext context) {
    final j = match.job;
    final color = match.score >= 70 ? AppColors.green : match.score >= 50 ? AppColors.blue : AppColors.amber;
    final tint = match.score >= 70 ? AppColors.greenTint : match.score >= 50 ? AppColors.blueTint : AppColors.amberTint;
    final initial = (j.company.isNotEmpty ? j.company : j.title).characters.first.toUpperCase();
    return AppCard(
      onTap: () => context.push(Routes.jobDetail, extra: match),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(14)),
            child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${j.company} · ${j.location}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${match.score}%', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
              Text('match', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 9)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (j.scamFlags.isNotEmpty) const StatusChip('Suspicious: asks for money', tone: ChipTone.risk),
          if (j.isCareerMate)
            const StatusChip('Posted on CareerMate', tone: ChipTone.info)
          else
            StatusChip(j.official ? 'Company careers page' : 'via ${j.sourceName}', tone: j.official ? ChipTone.positive : ChipTone.info),
          if (j.remote) const StatusChip('Remote'),
          if (j.looksFresherFriendly) const StatusChip('Fresher-friendly'),
          if (j.employmentType != null && j.employmentType!.isNotEmpty) StatusChip(j.employmentType!),
        ]),
        const SizedBox(height: 8),
        Text(postedText(j), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 92,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.push(Routes.jobDetail, extra: match),
              child: const Text('View job', maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: OtherSitesButton(job: j)),
        ]),
      ]),
    );
  }
}

String postedText(JobItem j) {
  final d = j.postedAt;
  if (d == null) return 'Publish date unknown';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final label = j.dateKind == 'updated' ? 'Updated' : 'Posted';
  final days = j.ageDays ?? 0;
  final ago = days == 0 ? 'today' : days == 1 ? 'yesterday' : '$days days ago';
  return '$label ${d.day} ${m[d.month - 1]} · $ago';
}

class _NeedProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Message(
        icon: Icons.description_outlined,
        title: 'Upload your CV first',
        body: 'We use your CV to choose your job categories and show jobs that match you.',
        action: FilledButton(onPressed: () => context.go(Routes.cv), child: const Text('Upload CV')),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(26)),
          child: Icon(icon, size: 40, color: AppColors.blue),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: AppTheme.display(context, size: 19)),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, height: 1.5)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Shimmer(height: i == 0 ? 52 : 110),
          ),
      ],
    );
  }
}

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.height});
  final double height;
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _c.value - 0.6, 0),
            end: Alignment(-1 + 2 * _c.value + 0.6, 0),
            colors: const [AppColors.line, Color(0xFFF7F9FD), AppColors.line],
          ),
        ),
      ),
    );
  }
}
