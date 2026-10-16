import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/category_matcher.dart';
import '../../profile/cv_parser.dart';
import '../../profile/taxonomy.dart';
import '../posted_job.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key, this.existing});
  final PostedJob? existing;

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _city, _expMin, _expMax, _salMin, _salMax, _desc, _skillInput;
  String _workMode = 'onsite';
  List<String> _skills = [];
  List<String> _subIds = [];
  String? _catId;
  bool _manualCategory = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final doc = ref.read(userDocProvider).value ?? const {};
    _title = TextEditingController(text: e?.title ?? '');
    _city = TextEditingController(text: e?.city ?? (doc['companyCity'] as String? ?? ''));
    _expMin = TextEditingController(text: e == null ? '0' : '${e.expMin}');
    _expMax = TextEditingController(text: e == null ? '2' : '${e.expMax}');
    _salMin = TextEditingController(text: e?.salaryMinLakh?.toString() ?? '');
    _salMax = TextEditingController(text: e?.salaryMaxLakh?.toString() ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _skillInput = TextEditingController();
    _workMode = e?.workMode ?? 'onsite';
    _skills = [...?e?.skills];
    _subIds = [...?e?.subIds];
    _catId = e?.catId;
    _manualCategory = e != null;
  }

  @override
  void dispose() {
    for (final c in [_title, _city, _expMin, _expMax, _salMin, _salMax, _desc, _skillInput]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Picks the category from the title, skills and description.
  void _autoCategory() {
    if (_manualCategory) return;
    final text = '${_title.text}\n${_desc.text}\n${_skills.join(', ')}'.toLowerCase();
    final skills = <String>{..._skills};
    final titles = <String>[];
    for (final c in jobCategories) {
      for (final s in c.subs) {
        for (final k in s.skills) {
          if (CvParser.containsWord(text, k)) skills.add(k);
        }
        for (final t in s.titles) {
          if (CvParser.containsWord(_title.text.toLowerCase(), t)) titles.add(t);
        }
      }
    }
    final r = const CategoryMatcher().match(skills: skills.toList(), titles: titles);
    setState(() {
      _subIds = r.subs.take(2).map((s) => s.sub.id).toList();
      _catId = r.main?.id ?? (r.subs.isNotEmpty ? r.subs.first.category.id : null);
    });
  }

  void _addSkill() {
    final v = _skillInput.text.trim().toLowerCase();
    if (v.isEmpty || _skills.contains(v)) return;
    setState(() => _skills = [..._skills, v]);
    _skillInput.clear();
    _autoCategory();
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (c, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          for (final cat in jobCategories)
            ExpansionTile(
              title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              children: [for (final s in cat.subs) ListTile(title: Text(s.name), onTap: () => Navigator.pop(c, s.id))],
            ),
        ]),
      ),
    );
    if (picked == null) return;
    setState(() {
      _manualCategory = true;
      _subIds = [picked];
      _catId = categoryOfSub(picked)?.id;
    });
  }

  Future<void> _save({required bool publish}) async {
    if (publish && !_form.currentState!.validate()) return;
    if (publish && _subIds.isEmpty) {
      showMessage(context, 'Choose a job category.', error: true);
      return;
    }
    final money = findMoneyAsk('${_title.text}\n${_desc.text}');
    if (money != null) {
      showMessage(context, 'Jobs cannot ask candidates for money ("$money"). Please remove it.', error: true);
      return;
    }
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final doc = ref.read(userDocProvider).value ?? const {};
    final job = PostedJob(
      id: widget.existing?.id ?? '',
      recruiterUid: user.uid,
      company: (doc['company'] as String?) ?? '',
      contactEmail: user.email ?? '',
      title: _title.text.trim(),
      catId: _catId,
      subIds: _subIds,
      workMode: _workMode,
      city: _city.text.trim(),
      expMin: int.tryParse(_expMin.text.trim()) ?? 0,
      expMax: int.tryParse(_expMax.text.trim()) ?? 0,
      salaryMinLakh: double.tryParse(_salMin.text.trim()),
      salaryMaxLakh: double.tryParse(_salMax.text.trim()),
      skills: _skills,
      description: _desc.text.trim(),
      status: publish ? 'live' : 'draft',
      createdAt: widget.existing?.createdAt,
    );
    setState(() => _saving = true);
    try {
      try {
        await ref.read(recruiterRepositoryProvider).save(job);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        // A just-verified email may not be in the sign-in token yet: refresh it once and retry.
        await user.getIdToken(true);
        await ref.read(recruiterRepositoryProvider).save(job);
      }
      if (!mounted) return;
      showMessage(context, publish ? 'Job published. Matching job seekers can see it now.' : 'Draft saved.');
      context.pop();
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().contains('permission')
              ? 'Not allowed yet. Verify your work email and make sure the latest database rules are published.'
              : 'Could not save. Check your internet and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = _subIds.isEmpty ? null : subCategoryById(_subIds.first);
    final cat = _catId == null ? null : categoryById(_catId!);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8, left: 2),
          child: Text(t, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: muted)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Post a job' : 'Edit job'),
        actions: [TextButton(onPressed: _saving ? null : () => _save(publish: false), child: const Text('Save draft'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [
                label('JOB TITLE'),
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Accounts Executive'),
                  onChanged: (_) => _autoCategory(),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Enter the job title' : null,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickCategory,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.blueDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sub == null ? 'Category: tap to choose' : 'Category: ${cat?.name ?? ''} › ${sub.name}',
                          style: const TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                      const Text('Change', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ]),
                  ),
                ),
                label('WORK MODE'),
                Wrap(spacing: 8, children: [
                  for (final m in const [('onsite', 'On-site'), ('hybrid', 'Hybrid'), ('remote', 'Remote')])
                    ChoiceChip(label: Text(m.$2), selected: _workMode == m.$1, onSelected: (_) => setState(() => _workMode = m.$1)),
                ]),
                label('CITY'),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Pune'),
                  validator: (v) => (_workMode != 'remote' && (v == null || v.trim().isEmpty)) ? 'Enter the city' : null,
                ),
                label('EXPERIENCE (YEARS)'),
                Row(children: [
                  Expanded(child: _numField(_expMin, 'From', required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_expMax, 'To', required: true)),
                ]),
                label('SALARY (₹ LAKH PER YEAR, OPTIONAL)'),
                Row(children: [
                  Expanded(child: _numField(_salMin, 'Min', decimal: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_salMax, 'Max', decimal: true)),
                ]),
                label('KEY SKILLS'),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in _skills)
                    InputChip(
                      label: Text(CvParser.prettySkill(s)),
                      onDeleted: () {
                        setState(() => _skills = _skills.where((x) => x != s).toList());
                        _autoCategory();
                      },
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _skillInput,
                      onSubmitted: (_) => _addSkill(),
                      decoration: const InputDecoration(hintText: 'Add a skill, e.g. Tally', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _addSkill, icon: const Icon(Icons.add_rounded), tooltip: 'Add skill'),
                ]),
                label('DESCRIPTION'),
                TextFormField(
                  controller: _desc,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 4000,
                  onChanged: (_) => _autoCategory(),
                  decoration: const InputDecoration(hintText: 'What will the person do? What do they need? Timings, benefits…'),
                  validator: (v) => (v == null || v.trim().length < 40) ? 'Write at least a few lines (40+ characters)' : null,
                ),
                Row(children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.green),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Jobs that ask candidates for money are not allowed.', style: TextStyle(fontSize: 12, color: muted))),
                ]),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: LoadingButton(label: widget.existing?.isLive == true ? 'Save changes' : 'Publish job', loading: _saving, onPressed: () => _save(publish: true)),
      ),
    );
  }

  Widget _numField(TextEditingController c, String hint, {bool required = false, bool decimal = false}) => TextFormField(
        controller: c,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(hintText: hint),
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return required ? 'Required' : null;
          return (decimal ? double.tryParse(t) : int.tryParse(t)) == null ? 'Numbers only' : null;
        },
      );
}
