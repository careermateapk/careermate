import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../router/app_router.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jobs/job_models.dart';
import '../profile/cv_parser.dart';
import '../profile/profile_repository.dart';
import '../skills/skill_bank.dart';
import '../skills/skill_repository.dart';
import '../skills/ui/skill_screens.dart';
import '../tracker/tracker.dart';

/// Local state for the 30-day plan (also read by the background reminder).
class PlanStore {
  static Future<File> file() async => File('${(await getApplicationDocumentsDirectory()).path}/plan.json');

  static Future<Map<String, dynamic>> load() async {
    try {
      final f = await file();
      if (await f.exists()) return Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map);
    } catch (_) {}
    return {};
  }

  static Future<void> save(Map<String, dynamic> m) async => (await file()).writeAsString(jsonEncode(m));

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class PlanTask {
  PlanTask(this.id, this.emoji, this.title, this.subtitle, {this.action, this.autoDone = false});
  final String id;
  final String emoji;
  final String title;
  final String subtitle;
  final Future<void> Function(BuildContext context)? action;
  final bool autoDone;
}

class JobReadyPlanScreen extends ConsumerStatefulWidget {
  const JobReadyPlanScreen({super.key});
  @override
  ConsumerState<JobReadyPlanScreen> createState() => _JobReadyPlanScreenState();
}

class _JobReadyPlanScreenState extends ConsumerState<JobReadyPlanScreen> {
  Map<String, dynamic> _s = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    PlanStore.load().then((m) {
      if (!mounted) return;
      setState(() {
        _s = m;
        _loaded = true;
      });
    });
  }

  DateTime get _start => DateTime.tryParse(_s['start'] as String? ?? '') ?? DateTime.now();
  int get _day => DateTime.now().difference(DateTime(_start.year, _start.month, _start.day)).inDays + 1;
  Map<String, List<String>> get _done =>
      {for (final e in (_s['done'] as Map? ?? {}).entries) '${e.key}': List<String>.from(e.value as List)};

  Future<void> _begin() async {
    _s = {'start': DateTime.now().toIso8601String(), 'done': {}, 'hour': 19, 'startScore': ref.read(profileProvider).value?.atsScore ?? 0};
    await PlanStore.save(_s);
    setState(() {});
  }

  Future<void> _toggle(String id) async {
    final key = PlanStore.dayKey(DateTime.now());
    final done = _done;
    final list = done[key] ?? [];
    list.contains(id) ? list.remove(id) : list.add(id);
    done[key] = list;
    _s['done'] = done;
    await PlanStore.save(_s);
    setState(() {});
  }

  int _streak() {
    final done = _done;
    var streak = 0;
    var d = DateTime.now();
    // Today counts once something is done; otherwise start from yesterday.
    if ((done[PlanStore.dayKey(d)] ?? const []).isEmpty) d = d.subtract(const Duration(days: 1));
    while ((done[PlanStore.dayKey(d)] ?? const []).isNotEmpty) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<PlanTask> _tasks(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final badges = ref.watch(myBadgesProvider).value ?? const <String, SkillResult>{};
    final jobs = ref.watch(jobsProvider).value?.jobs ?? const <JobItem>[];
    final tracked = ref.watch(trackerProvider).value ?? const <TrackedJob>[];
    final today = DateTime.now();
    final appliedToday = tracked.where((t) {
      final a = t.appliedAt;
      return a != null && a.year == today.year && a.month == today.month && a.day == today.day;
    }).length;

    // Skills that matching jobs ask for but the CV doesn't show, most common first.
    final gaps = <String, int>{};
    if (profile != null) {
      for (final j in jobs.take(150)) {
        for (final s in JobMatch.of(j, profile).missingSkills) {
          gaps[s] = (gaps[s] ?? 0) + 1;
        }
      }
    }
    final gapList = gaps.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final learned = Set<String>.from(_s['learned'] as List? ?? const []);
    final gap = gapList.map((e) => e.key).where((s) => !learned.contains(s)).firstOrNull;

    final skills = (profile?.skills ?? const <String>[]).toSet();
    final test = skillTests.where((t) => !(badges[t.id]?.passed ?? false) && (badges[t.id]?.canRetry ?? true)).toList()
      ..sort((a, b) => (a.keywords.any(skills.contains) ? 0 : 1).compareTo(b.keywords.any(skills.contains) ? 0 : 1));
    final issue = (profile?.atsIssues ?? const <Map<String, String>>[]).where((i) => i['severity'] != 'ok').firstOrNull;

    return [
      if (gap != null)
        PlanTask('learn:$gap', '📺', 'Learn: ${CvParser.prettySkill(gap)} (free video)', 'Asked in ${gaps[gap]} jobs you match',
            action: (c) async {
          learned.add(gap);
          _s['learned'] = learned.toList();
          await launchUrl(Uri.https('www.youtube.com', '/results', {'search_query': '${CvParser.prettySkill(gap)} tutorial for beginners'}),
              mode: LaunchMode.externalApplication);
        }),
      if (test.isNotEmpty)
        PlanTask('test:${test.first.id}', '🛡️', 'Take the ${test.first.name} skill test', 'Earn a badge recruiters see',
            action: (c) async => Navigator.of(c).push(MaterialPageRoute(builder: (_) => SkillQuizScreen(test: test.first)))),
      PlanTask('apply3', '📨', 'Apply to 3 matching jobs', '$appliedToday done today', autoDone: appliedToday >= 3, action: (c) async => c.go(Routes.jobs)),
      if (issue != null)
        PlanTask('cv:${issue['title']}', '✍️', issue['title'] ?? 'Improve your CV', 'From your CV report', action: (c) async => c.push(Routes.atsReport)),
      PlanTask('prep', '🎤', 'Practise 1 interview answer', 'Takes 5 minutes', action: (c) async => c.go(Routes.prep)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final started = _s['start'] != null;
    return Scaffold(
      appBar: AppBar(title: const Text('30-day Job Ready plan')),
      body: started ? _plan(context) : _intro(context),
    );
  }

  Widget _intro(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
        const Text('🚀', style: TextStyle(fontSize: 54), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text('Get job-ready in 30 days', textAlign: TextAlign.center, style: AppTheme.display(context, size: 22)),
        const SizedBox(height: 10),
        const Text(
          'Every day you get 3–5 small tasks made from your CV and the jobs you match: a free video for a missing skill, a skill test, '
          'applying to jobs, fixing your CV and interview practice. Keep your streak going!',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _begin, child: const Text('Start my plan')),
      ]);

  Widget _plan(BuildContext context) {
    final tasks = _tasks(context);
    final today = _done[PlanStore.dayKey(DateTime.now())] ?? const <String>[];
    bool isDone(PlanTask t) => t.autoDone || today.contains(t.id);
    final doneCount = tasks.where(isDone).length;
    final day = _day.clamp(1, 30);
    final profile = ref.watch(profileProvider).value;
    final badges = (ref.watch(myBadgesProvider).value ?? const {}).values.where((b) => b.passed).length;
    final applied = (ref.watch(trackerProvider).value ?? const <TrackedJob>[]).where((t) => t.appliedAt != null).length;
    final hour = (_s['hour'] as num?)?.toInt() ?? 19;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
      FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF312E81)]),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_day > 30 ? 'Plan complete 🎉' : 'Day $day', style: AppTheme.display(context, size: 26, color: Colors.white))),
              Text('🔥 ${_streak()}-day streak', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (var i = 0; i < 30; i++)
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: (_done[PlanStore.dayKey(_start.add(Duration(days: i)))] ?? const []).isNotEmpty
                        ? AppColors.green
                        : i == day - 1
                            ? AppColors.blue
                            : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 16, runSpacing: 4, children: [
              Text('CV score ${_s['startScore'] ?? '–'} → ${profile?.atsScore ?? '–'}', style: const TextStyle(color: Color(0xFFC9D8FF), fontSize: 12.5)),
              Text('Badges $badges', style: const TextStyle(color: Color(0xFFC9D8FF), fontSize: 12.5)),
              Text('Applied $applied', style: const TextStyle(color: Color(0xFFC9D8FF), fontSize: 12.5)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TODAY · $doneCount of ${tasks.length} done',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: AppColors.textMuted)),
          for (final t in tasks)
            InkWell(
              onTap: t.action == null ? null : () => t.action!(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  InkWell(
                    onTap: t.autoDone ? null : () => _toggle(t.id),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone(t) ? AppColors.green : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isDone(t) ? null : Border.all(color: AppColors.border, width: 2),
                      ),
                      child: isDone(t) ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${t.emoji} ${t.title}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            decoration: isDone(t) ? TextDecoration.lineThrough : null,
                            color: isDone(t) ? AppColors.textMuted : null,
                          )),
                      Text(t.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  ),
                  if (t.action != null) const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('Daily reminder at ${hour > 12 ? hour - 12 : hour}:00 ${hour < 12 ? 'am' : 'pm'}')),
          TextButton(
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: 0));
              if (t == null) return;
              _s['hour'] = t.hour;
              await PlanStore.save(_s);
              setState(() {});
            },
            child: const Text('Change'),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      const Text('Tick a task when you finish it. Videos open YouTube search results for free tutorials.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45)),
    ]);
  }
}
