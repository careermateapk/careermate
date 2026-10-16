import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../cv/local_cv.dart';
import '../../profile/profile_repository.dart';
import '../../profile/text_extractor.dart';
import '../doc_builders.dart';
import '../pdf_builder.dart';
import '../resume_data.dart';
import '../templates.dart';
import 'template_thumb.dart';

/// The CV being made. Loaded from this phone, or started from the user's profile and CV.
class ResumeNotifier extends AsyncNotifier<ResumeData> {
  @override
  Future<ResumeData> build() async {
    final saved = await ResumeStore.load();
    if (saved != null) return saved;
    final profile = ref.read(profileProvider).value;
    if (profile == null) return ResumeData();
    var text = '';
    try {
      final path = ref.read(localCvProvider).path;
      if (path != null) {
        final f = File(path);
        text = (await const TextExtractor().extractSmart(f.uri.pathSegments.last, await f.readAsBytes())).text;
      }
    } catch (_) {}
    return ResumeData.fromProfile(profile, cvText: text);
  }

  Future<void> edit(void Function(ResumeData d) change) async {
    final d = state.value;
    if (d == null) return;
    change(d);
    state = AsyncData(d);
    await ResumeStore.save(d);
  }

  Future<void> restartFromProfile() async {
    await ResumeStore.clear();
    ref.invalidateSelf();
  }
}

final resumeProvider = AsyncNotifierProvider<ResumeNotifier, ResumeData>(ResumeNotifier.new);

// ======================================================================= gallery

class ResumeGalleryScreen extends ConsumerStatefulWidget {
  const ResumeGalleryScreen({super.key});
  @override
  ConsumerState<ResumeGalleryScreen> createState() => _ResumeGalleryScreenState();
}

class _ResumeGalleryScreenState extends ConsumerState<ResumeGalleryScreen> {
  String _cat = resumeCategories.first;

  @override
  Widget build(BuildContext context) {
    final list = resumeTemplates.where((t) => t.category == _cat).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CV maker'),
          Text('40 templates · filled from your CV', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
            children: [
              for (final c in resumeCategories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$c · ${resumeTemplates.where((t) => t.category == c).length}'),
                    selected: _cat == c,
                    onSelected: (_) => setState(() => _cat = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.62,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return FadeSlideIn(
                index: i < 8 ? i : 8,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showTemplatePreview(context, t),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Hero(tag: 'tpl-${t.id}', child: TemplateThumb(t: t)),
                    const SizedBox(height: 8),
                    Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text('${t.twoColumn ? 'Two-column' : 'One-column'}${t.atsBest ? ' · ATS best' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ======================================================================= preview sheet

Future<void> showTemplatePreview(BuildContext context, ResumeTemplate t) => Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, _, _) => _TemplatePreview(t: t),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );

class _TemplatePreview extends ConsumerStatefulWidget {
  const _TemplatePreview({required this.t});
  final ResumeTemplate t;
  @override
  ConsumerState<_TemplatePreview> createState() => _TemplatePreviewState();
}

class _TemplatePreviewState extends ConsumerState<_TemplatePreview> {
  late int _color = widget.t.color;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(resumeProvider).value;
    final previewData = (data == null || data.name.isEmpty) ? ResumeData.sample() : data;
    final t = widget.t;
    return Scaffold(
      backgroundColor: const Color(0xFF1A2340),
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey('$_color-${t.id}'),
              build: (_) => ResumePdf(previewData, t, color: _color).build(),
              useActions: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              maxPageWidth: 520,
              scrollViewDecoration: const BoxDecoration(color: Color(0xFF1A2340)),
              pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: Text(t.name, style: AppTheme.display(context, size: 22))),
                Text(t.category, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMuted)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in resumeColors)
                    GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: _color == c ? Color(c) : Colors.transparent, width: 2),
                          boxShadow: _color == c ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 8)] : null,
                        ),
                        child: _color == c ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              _Feature(ok: true, text: t.atsBest ? 'ATS Optimized' : 'ATS friendly (real text, no pictures)'),
              _Feature(ok: t.twoColumn, text: t.twoColumn ? 'Two-column resume' : 'One-column resume'),
              const _Feature(ok: true, text: 'Editable sample content'),
              const _Feature(ok: true, text: 'Download in PDF, Word DOCX or TXT'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: data == null
                      ? null
                      : () async {
                          await ref.read(resumeProvider.notifier).edit((d) {
                            d.templateId = t.id;
                            d.color = _color;
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            context.push(Routes.cvMakerEdit);
                          }
                        },
                  child: const Text('Use this template'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.ok, required this.text});
  final bool ok;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(ok ? Icons.check_rounded : Icons.remove_rounded, size: 20, color: ok ? null : AppColors.textMuted),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ======================================================================= editor

class ResumeEditorScreen extends ConsumerStatefulWidget {
  const ResumeEditorScreen({super.key});
  @override
  ConsumerState<ResumeEditorScreen> createState() => _ResumeEditorScreenState();
}

class _ResumeEditorScreenState extends ConsumerState<ResumeEditorScreen> {
  static const _steps = ['Contact', 'Summary', 'Experience', 'Education', 'Skills', 'Extras'];
  int _step = 0;

  void _set(void Function(ResumeData d) f) => ref.read(resumeProvider.notifier).edit(f);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(resumeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit your CV'),
          if (async.value != null)
            Text(templateById(async.value!.templateId).name,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
        actions: [
          IconButton(tooltip: 'Change template', icon: const Icon(Icons.style_outlined), onPressed: () => context.push(Routes.cvMaker)),
        ],
      ),
      body: async.when(
        loading: () => const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Filling the template from your CV…'),
          ]),
        ),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (d) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _step = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(children: [
                        AnimatedContainer(
                          duration: AppMotion.medium,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _step ? AppColors.blue : AppColors.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          child: Text(_steps[i],
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: i == _step ? null : AppColors.textMuted)),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              child: KeyedSubtree(key: ValueKey(_step), child: _stepView(d)),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context.push(Routes.cvMakerFinal),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const FittedBox(child: Text('Preview')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => _step < _steps.length - 1 ? setState(() => _step++) : context.push(Routes.cvMakerFinal),
              child: FittedBox(child: Text(_step < _steps.length - 1 ? 'Next: ${_steps[_step + 1]}' : 'Finish & preview')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stepView(ResumeData d) {
    Widget field(String label, String value, void Function(ResumeData d, String v) onChanged,
            {int lines = 1, String? hint, TextInputType? type}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            initialValue: value,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 6,
            keyboardType: type,
            decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
            onChanged: (v) => _set((d) => onChanged(d, v)),
          ),
        );
    final pad = const EdgeInsets.fromLTRB(20, 8, 20, 30);
    switch (_step) {
      case 0:
        return ListView(padding: pad, children: [
          field('Full name', d.name, (d, v) => d.name = v),
          field('Job title shown under your name', d.headline, (d, v) => d.headline = v, hint: 'e.g. Accounts Manager'),
          field('Mobile', d.phone, (d, v) => d.phone = v, type: TextInputType.phone),
          field('Email', d.email, (d, v) => d.email = v, type: TextInputType.emailAddress),
          field('City', d.city, (d, v) => d.city = v),
          field('LinkedIn or website (optional)', d.link, (d, v) => d.link = v),
        ]);
      case 1:
        return ListView(padding: pad, children: [
          field('Professional summary', d.summary, (d, v) => d.summary = v,
              lines: 5, hint: '2–3 lines: your experience, strongest skills and the role you want. Only true facts.'),
          const Text('Tip: mention years of experience and 2–3 key skills. Never add numbers you can’t prove.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ]);
      case 2:
        return ListView(padding: pad, children: [
          for (final (i, j) in d.jobs.indexed)
            _ItemCard(
              key: ValueKey('job-$i-${d.jobs.length}'),
              title: j.role.isEmpty ? 'Job ${i + 1}' : j.role,
              subtitle: [j.company, j.dates].where((s) => s.isNotEmpty).join(' · '),
              onDelete: () => _set((d) => d.jobs.removeAt(i)),
              children: [
                field('Job title', j.role, (d, v) => d.jobs[i].role = v),
                field('Company', j.company, (d, v) => d.jobs[i].company = v),
                field('City', j.city, (d, v) => d.jobs[i].city = v),
                Row(children: [
                  Expanded(child: field('Start', j.start, (d, v) => d.jobs[i].start = v, hint: 'Jan 2022')),
                  const SizedBox(width: 10),
                  Expanded(child: field('End', j.end, (d, v) => d.jobs[i].end = v, hint: 'Present')),
                ]),
                field('Points (one per line)', j.bullets.join('\n'),
                    (d, v) => d.jobs[i].bullets = v.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                    lines: 4, hint: 'Start with an action word: Managed…, Prepared…, Reduced…'),
              ],
            ),
          OutlinedButton.icon(
            onPressed: () => _set((d) => d.jobs.add(ResumeJob())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another job'),
          ),
        ]);
      case 3:
        return ListView(padding: pad, children: [
          for (final (i, e) in d.education.indexed)
            _ItemCard(
              key: ValueKey('edu-$i-${d.education.length}'),
              title: e.degree.isEmpty ? 'Education ${i + 1}' : e.degree,
              subtitle: [e.school, e.dates].where((s) => s.isNotEmpty).join(' · '),
              onDelete: () => _set((d) => d.education.removeAt(i)),
              children: [
                field('Degree / course', e.degree, (d, v) => d.education[i].degree = v),
                field('College / university', e.school, (d, v) => d.education[i].school = v),
                field('City', e.city, (d, v) => d.education[i].city = v),
                Row(children: [
                  Expanded(child: field('Start', e.start, (d, v) => d.education[i].start = v, hint: '2017')),
                  const SizedBox(width: 10),
                  Expanded(child: field('End', e.end, (d, v) => d.education[i].end = v, hint: '2020')),
                ]),
              ],
            ),
          OutlinedButton.icon(
            onPressed: () => _set((d) => d.education.add(ResumeEdu())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add education'),
          ),
        ]);
      case 4:
        return ListView(padding: pad, children: [
          field('Skills (comma separated)', d.skills.join(', '),
              (d, v) => d.skills = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(), lines: 3),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final s in d.skills) StatusChip(s, tone: ChipTone.info)]),
        ]);
      default:
        return ListView(padding: pad, children: [
          field('Languages (comma separated)', d.languages.join(', '),
              (d, v) => d.languages = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()),
          field('Certifications (one per line)', d.certifications.join('\n'),
              (d, v) => d.certifications = v.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(), lines: 3),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Start again from my CV?'),
                  content: const Text('Your edits here will be replaced with details from your confirmed profile.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Start again')),
                  ],
                ),
              );
              if (ok == true) await ref.read(resumeProvider.notifier).restartFromProfile();
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Start again from my CV'),
          ),
        ]);
    }
  }
}

class _ItemCard extends StatefulWidget {
  const _ItemCard({super.key, required this.title, required this.subtitle, required this.children, required this.onDelete});
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback onDelete;
  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (widget.subtitle.isNotEmpty) Text(widget.subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                    ]),
                  ),
                ),
              ),
              IconButton(tooltip: _open ? 'Close' : 'Edit', icon: Icon(_open ? Icons.expand_less_rounded : Icons.edit_outlined), onPressed: () => setState(() => _open = !_open)),
              IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red), onPressed: widget.onDelete),
            ]),
            if (_open) Padding(padding: const EdgeInsets.fromLTRB(0, 4, 8, 4), child: Column(children: widget.children)),
          ]),
        ),
      );
}

// ======================================================================= final preview & download

enum _Format { pdf, docx, txt }

class ResumeFinalScreen extends ConsumerStatefulWidget {
  const ResumeFinalScreen({super.key});
  @override
  ConsumerState<ResumeFinalScreen> createState() => _ResumeFinalScreenState();
}

class _ResumeFinalScreenState extends ConsumerState<ResumeFinalScreen> {
  _Format _format = _Format.pdf;
  bool _busy = false;

  String _fileBase(ResumeData d) {
    final n = d.name.trim().isEmpty ? 'My' : d.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return '${n}_CV';
  }

  Future<(Uint8List, String, String)> _file(ResumeData d) async {
    final t = templateById(d.templateId);
    final base = _fileBase(d);
    return switch (_format) {
      _Format.pdf => (await ResumePdf(d, t).build(), '$base.pdf', 'application/pdf'),
      _Format.docx => (buildDocx(d, t), '$base.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
      _Format.txt => (Uint8List.fromList(buildTxt(d).codeUnits.map((c) => c > 255 ? 63 : c).toList()), '$base.txt', 'text/plain'),
    };
  }

  Future<void> _save(ResumeData d) async {
    setState(() => _busy = true);
    try {
      final (bytes, name, mime) = await _file(d);
      final path = await FlutterFileDialog.saveFile(params: SaveFileDialogParams(data: bytes, fileName: name, mimeTypesFilter: [mime]));
      if (mounted && path != null) showMessage(context, 'Saved $name to your phone.');
    } catch (e) {
      if (mounted) showMessage(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(ResumeData d) async {
    setState(() => _busy = true);
    try {
      // Sharing sends the PDF (best for WhatsApp/email). Word and TXT files are saved with "Save to phone".
      final bytes = await ResumePdf(d, templateById(d.templateId)).build();
      await Printing.sharePdf(bytes: bytes, filename: '${_fileBase(d)}.pdf');
    } catch (e) {
      if (mounted) showMessage(context, 'Could not share: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useForJobs(ResumeData d) async {
    final bytes = await ResumePdf(d, templateById(d.templateId)).build();
    await ref.read(localCvProvider).save('${_fileBase(d)}.pdf', bytes);
    if (mounted) showMessage(context, 'This CV will now be attached when you email recruiters.');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(resumeProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Final preview'),
          Text('Check everything before downloading', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              build: (_) => ResumePdf(d, templateById(d.templateId)).build(),
              useActions: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              maxPageWidth: 600,
            ),
      bottomNavigationBar: d == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 20)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Download as', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final f in _Format.values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: f == _Format.txt ? 0 : 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _format = f),
                            child: AnimatedContainer(
                              duration: AppMotion.fast,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _format == f ? AppColors.blueTint : null,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _format == f ? AppColors.blue : AppColors.border, width: _format == f ? 2 : 1.5),
                              ),
                              child: Column(children: [
                                Text(f.name.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: switch (f) {
                                        _Format.pdf => AppColors.red,
                                        _Format.docx => AppColors.blue,
                                        _Format.txt => AppColors.textBody,
                                      },
                                    )),
                                Text(
                                  switch (f) {
                                    _Format.pdf => 'Best for applying',
                                    _Format.docx => 'Edit in Word',
                                    _Format.txt => 'Plain text forms',
                                  },
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  if (_format != _Format.pdf)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _format == _Format.docx
                            ? 'The Word file uses a simple one-column layout in your colour so it stays easy to edit.'
                            : 'Plain text has no design — use it for online forms that ask you to paste your CV.',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: LoadingButton(label: 'Save to phone', icon: Icons.download_rounded, loading: _busy, onPressed: () => _save(d)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _share(d),
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const FittedBox(child: Text('Share PDF')),
                      ),
                    ),
                  ]),
                  TextButton(onPressed: () => _useForJobs(d), child: const Text('Use this CV when emailing recruiters')),
                ]),
              ),
            ),
    );
  }
}
