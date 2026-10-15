import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../category_matcher.dart';
import '../cv_parser.dart';
import '../profile_repository.dart';
import '../taxonomy.dart';

/// Main job category and sub-categories suggested from the CV.
/// The user can untick suggestions or add any other sub-category.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  late final CareerProfile _profile;
  late final CategoryResult _result;
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = ref.read(cvDraftProvider)?.profile ?? ref.read(profileProvider).value ?? CareerProfile();
    _result = const CategoryMatcher().match(skills: _profile.skills, titles: _profile.titles);
    final suggested = _result.subs.where((s) => s.strength >= 55).take(5).map((s) => s.sub.id);
    _selected = _profile.subCategoryIds.isNotEmpty ? {..._profile.subCategoryIds} : {...suggested};
  }

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _save() async {
    if (_selected.isEmpty) {
      showMessage(context, 'Choose at least one sub-category.', error: true);
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() => _saving = true);
    final firstSub = _result.subs.where((s) => _selected.contains(s.sub.id)).map((s) => s.category.id).firstOrNull;
    final mainId = (_result.main != null && _result.main!.subs.any((s) => _selected.contains(s.id)))
        ? _result.main!.id
        : (firstSub ?? categoryOfSub(_selected.first)?.id);
    try {
      await ref.read(profileRepositoryProvider).save(
            user.uid,
            _profile.copyWith(categoryId: mainId, subCategoryIds: _selected.toList()),
          );
      ref.read(cvDraftProvider.notifier).set(null);
      if (mounted) {
        showMessage(context, 'Profile saved.');
        context.go(Routes.atsReport);
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not save. Check your internet and try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _browseAll() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (c, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Text('All categories', style: AppTheme.display(context, size: 18)),
              const SizedBox(height: 8),
              for (final cat in jobCategories)
                ExpansionTile(
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${cat.subs.where((s) => _selected.contains(s.id)).length} selected'),
                  children: [
                    for (final s in cat.subs)
                      CheckboxListTile(
                        value: _selected.contains(s.id),
                        title: Text(s.name),
                        onChanged: (_) {
                          _toggle(s.id);
                          setSheet(() {});
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final main = _result.main;
    final extra = _selected.where((id) => !_result.subs.any((s) => s.sub.id == id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Your job categories')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.category_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('MAIN CATEGORY · FROM YOUR CV',
                            style: TextStyle(color: Color(0xFFA9B6D6), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
                        const SizedBox(height: 2),
                        Text(main?.name ?? 'Not clear yet', style: AppTheme.display(context, size: 20, color: Colors.white)),
                        Text(
                          '${_profile.experienceYears == 0 ? 'Fresher' : '${_profile.experienceYears} yrs experience'} · ${_profile.skills.length} skills',
                          style: const TextStyle(color: Color(0xFFC9D3EA), fontSize: 12.5),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              if (_result.subs.isEmpty)
                const AppCard(
                  child: Text(
                    'We could not match your CV to a category yet. Add more skills or job titles on the previous screen, or choose categories below.',
                    style: TextStyle(color: AppColors.textBody, height: 1.5),
                  ),
                )
              else ...[
                Text('Suggested sub-categories', style: AppTheme.display(context, size: 16)),
                const SizedBox(height: 4),
                const Text('Based on the skills and job titles in your CV. Tap to add or remove.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 10),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < _result.subs.length; i++)
                      FadeSlideIn(index: i + 1, child: _SubRow(match: _result.subs[i], selected: _selected.contains(_result.subs[i].sub.id), onTap: () => _toggle(_result.subs[i].sub.id))),
                  ]),
                ),
              ],
              if (extra.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final id in extra)
                    InputChip(label: Text(subCategoryById(id)?.name ?? id), onDeleted: () => _toggle(id)),
                ]),
              ],
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: _browseAll, icon: const Icon(Icons.add_rounded), label: const Text('Add another category')),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: LoadingButton(label: 'Save ${_selected.length} categories', loading: _saving, onPressed: _save, icon: Icons.check_rounded),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  const _SubRow({required this.match, required this.selected, required this.onTap});
  final SubMatch match;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = match.strength >= 75 ? AppColors.green : match.strength >= 55 ? AppColors.blue : AppColors.amber;
    final evidence = [...match.matchedTitles, ...match.matchedSkills].take(4).map(CvParser.prettySkill).join(', ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: selected ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? AppColors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: selected ? AppColors.blue : AppColors.border, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(match.sub.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('From: $evidence', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: match.strength / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: AppMotion.curve,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 6, color: color, backgroundColor: AppColors.line),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Text('${match.strength}%', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      ),
    );
  }
}
