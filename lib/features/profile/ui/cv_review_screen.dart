import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../cv_parser.dart';
import '../profile_repository.dart';

/// Shows what we read from the CV so the user can correct it before saving.
class CvReviewScreen extends ConsumerStatefulWidget {
  const CvReviewScreen({super.key});

  @override
  ConsumerState<CvReviewScreen> createState() => _CvReviewScreenState();
}

class _CvReviewScreenState extends ConsumerState<CvReviewScreen> {
  late final CareerProfile _start;
  late final TextEditingController _name, _email, _phone, _location, _years;
  late List<String> _skills, _titles, _education;

  @override
  void initState() {
    super.initState();
    _start = ref.read(cvDraftProvider)?.profile ?? ref.read(profileProvider).value ?? CareerProfile();
    _name = TextEditingController(text: _start.name);
    _email = TextEditingController(text: _start.email);
    _phone = TextEditingController(text: _start.phone);
    _location = TextEditingController(text: _start.location);
    _years = TextEditingController(text: _start.experienceYears == 0 ? '0' : _start.experienceYears.toString());
    _skills = [..._start.skills];
    _titles = [..._start.titles];
    _education = [..._start.education];
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _location, _years]) {
      c.dispose();
    }
    super.dispose();
  }

  void _continue() {
    final years = double.tryParse(_years.text.trim().replaceAll(',', '.')) ?? 0;
    final updated = _start.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      location: _location.text.trim(),
      experienceYears: years < 0 ? 0 : years,
      skills: _skills,
      titles: _titles,
      education: _education,
    );
    final draft = ref.read(cvDraftProvider);
    ref.read(cvDraftProvider.notifier).set(CvDraft(profile: updated, text: draft?.text ?? '', fileName: draft?.fileName ?? updated.resumeFileName));
    context.push(Routes.cvCategories);
  }

  @override
  Widget build(BuildContext context) {
    final fromCv = ref.read(cvDraftProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Check your details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              FadeSlideIn(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_outlined, color: AppColors.blueDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fromCv
                            ? 'We read these from your CV. Fix anything that is wrong — nothing is saved until you continue.'
                            : 'Edit your details. Changes update your job categories.',
                        style: const TextStyle(color: AppColors.blueDark, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(index: 1, child: _section(context, 'About you', [
                _field(_name, 'Full name', Icons.person_outline_rounded),
                _field(_email, 'Email', Icons.mail_outline_rounded, type: TextInputType.emailAddress),
                _field(_phone, 'Mobile number', Icons.phone_outlined, type: TextInputType.phone),
                _field(_location, 'City', Icons.location_on_outlined),
                _field(_years, 'Total work experience (years)', Icons.work_history_outlined,
                    type: const TextInputType.numberWithOptions(decimal: true), help: 'Use 0 if you are a fresher.'),
              ])),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 2,
                child: _ChipEditor(
                  title: 'Skills',
                  hint: 'Add a skill you really have',
                  values: _skills,
                  display: CvParser.prettySkill,
                  onChanged: (v) => setState(() => _skills = v),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 3,
                child: _ChipEditor(
                  title: 'Job titles you have held',
                  hint: 'e.g. sales executive',
                  values: _titles,
                  display: CvParser.prettySkill,
                  onChanged: (v) => setState(() => _titles = v),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 4,
                child: _ChipEditor(
                  title: 'Education',
                  hint: 'e.g. B.Com',
                  values: _education,
                  display: (s) => s,
                  onChanged: (v) => setState(() => _education = v),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: _continue,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Looks right — continue'),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> fields) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: AppTheme.display(context, size: 16)),
          const SizedBox(height: 12),
          for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 10), child: f),
        ]),
      );

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? type, String? help}) => TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), helperText: help),
      );
}

class _ChipEditor extends StatefulWidget {
  const _ChipEditor({required this.title, required this.hint, required this.values, required this.display, required this.onChanged});
  final String title;
  final String hint;
  final List<String> values;
  final String Function(String) display;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<_ChipEditor> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final v = _input.text.trim().toLowerCase();
    if (v.isEmpty || widget.values.contains(v)) return;
    widget.onChanged([...widget.values, v]);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: AppTheme.display(context, size: 16))),
          Text('${widget.values.length}', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        if (widget.values.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Nothing found. Add yours below.', style: TextStyle(color: AppColors.textMuted)),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in widget.values)
            InputChip(
              label: Text(widget.display(v)),
              onDeleted: () => widget.onChanged(widget.values.where((x) => x != v).toList()),
              deleteButtonTooltipMessage: 'Remove',
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _input,
              onSubmitted: (_) => _add(),
              decoration: InputDecoration(hintText: widget.hint, isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _add, icon: const Icon(Icons.add_rounded), tooltip: 'Add'),
        ]),
      ]),
    );
  }
}
