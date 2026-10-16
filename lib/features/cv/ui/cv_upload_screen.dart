import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/cv_analysis.dart';
import '../../profile/profile_repository.dart';
import '../../profile/text_extractor.dart';
import '../cv_repository.dart';
import '../local_cv.dart';
import 'cv_scan_screen.dart';

enum _Phase { idle, reading, uploading, analysing, done }

class CvUploadScreen extends ConsumerStatefulWidget {
  const CvUploadScreen({super.key});

  @override
  ConsumerState<CvUploadScreen> createState() => _CvUploadScreenState();
}

class _CvUploadScreenState extends ConsumerState<CvUploadScreen> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;
  String? _fileName;

  Future<void> _pickAndUpload() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    setState(() {
      _error = null;
      _phase = _Phase.reading;
    });
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: AppConfig.allowedCvExtensions);
      if (file == null) {
        setState(() => _phase = _Phase.idle);
        return;
      }
      final bytes = await file.readAsBytes();
      setState(() {
        _fileName = file.name;
        _phase = _Phase.uploading;
        _progress = 0;
      });
      await ref.read(cvRepositoryProvider).upload(
            uid: user.uid,
            fileName: file.name,
            bytes: bytes,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      // Keep a copy on this phone so it can be attached to emails.
      try {
        await ref.read(localCvProvider).save(file.name, bytes);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _phase = _Phase.analysing);
      final extracted = await const TextExtractor().extractSmart(file.name, bytes);
      final text = extracted.text;
      if (text.trim().length < 80) {
        if (mounted) {
          setState(() {
            _phase = _Phase.done;
            _error = 'Your CV was saved, but we could not read text in it. It may be a scanned photo. '
                'Please upload a PDF or DOCX made in Word or Google Docs.';
          });
        }
        return;
      }
      final draft = draftFromText(text,
          fileName: file.name, fallbackEmail: user.email ?? '', fallbackName: user.displayName ?? '', usedOcr: extracted.usedOcr);
      ref.read(cvDraftProvider.notifier).set(CvDraft(profile: draft, text: text, fileName: file.name));
      if (!mounted) return;
      await CvScanScreen.show(context, profile: draft, fileName: file.name);
      if (!mounted) return;
      setState(() => _phase = _Phase.done);
      context.push(Routes.cvReview);
    } on TextExtractionException catch (e) {
      if (mounted) setState(() {
        _phase = _Phase.done;
        _error = 'Your CV was saved, but: ${e.message}';
      });
    } on CvUploadException catch (e) {
      if (mounted) setState(() {
        _phase = _Phase.idle;
        _error = e.message;
      });
    } catch (e) {
      if (mounted) setState(() {
        _phase = _Phase.idle;
        _error = 'Could not open or upload the file. Please try again.';
      });
    }
  }

  Future<void> _delete() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete your CV?'),
        content: const Text('The file and its details will be permanently deleted. You can upload a new one anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(cvRepositoryProvider).deleteAll(user.uid);
      await ref.read(profileRepositoryProvider).delete(user.uid);
      await ref.read(localCvProvider).delete();
      if (mounted) {
        setState(() => _phase = _Phase.idle);
        showMessage(context, 'CV deleted.');
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not delete. Check your internet and try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentCvProvider).value;
    final busy = _phase == _Phase.reading || _phase == _Phase.uploading || _phase == _Phase.analysing;

    return Scaffold(
      appBar: AppBar(title: const Text('Your CV')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              FadeSlideIn(
                child: _DropZone(
                  phase: _phase,
                  progress: _progress,
                  fileName: _fileName,
                  onPick: busy ? null : _pickAndUpload,
                  hasCurrent: current != null,
                ),
              ),
              AnimatedSize(
                duration: AppMotion.medium,
                curve: AppMotion.curve,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.redTint, borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.redText),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.redText, fontWeight: FontWeight.w700))),
                          ]),
                        ),
                      ),
              ),
              if (current != null) ...[
                const SizedBox(height: 18),
                FadeSlideIn(index: 1, child: _CurrentCvCard(record: current, onReplace: busy ? null : _pickAndUpload, onDelete: busy ? null : _delete)),
              ],
              if (ref.watch(profileProvider).value != null) ...[
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 2,
                  child: Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(Routes.atsReport),
                        icon: const Icon(Icons.insights_rounded),
                        label: const Text('CV report'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(Routes.cvReview),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit details'),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: AppCard(
                  onTap: () => context.push(Routes.cvMaker),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2F6BFF), Color(0xFF7C3AED)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Make a new CV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text('40 templates · PDF, Word or TXT', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              const FadeSlideIn(index: 2, child: _WhatHappensNext()),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 3,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConfig.uploadCvToCloud
                          ? 'Your CV is private. Only you can open it — it is never shared through a public link. You can delete it anytime.'
                          : 'Your CV file stays on this device. Only its name and size are saved to your account.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.45),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  const _DropZone({required this.phase, required this.progress, required this.onPick, required this.hasCurrent, this.fileName});

  final _Phase phase;
  final double progress;
  final VoidCallback? onPick;
  final bool hasCurrent;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (phase) {
      _Phase.idle => Column(key: const ValueKey('idle'), children: [
          const _FloatingDoc(),
          const SizedBox(height: 14),
          Text(hasCurrent ? 'Upload a newer CV' : 'Upload your CV', style: AppTheme.display(context, size: 19)),
          const SizedBox(height: 4),
          const Text('PDF or DOCX · up to 5 MB', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPick,
            style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Choose file'),
          ),
        ]),
      _Phase.reading => const Column(key: ValueKey('read'), children: [
          SizedBox(height: 30),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Opening file…', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 30),
        ]),
      _Phase.analysing => Column(key: const ValueKey('an'), children: [
          const SizedBox(height: 16),
          const _ScanningDoc(),
          const SizedBox(height: 16),
          Text('Reading your CV…', style: AppTheme.display(context, size: 18)),
          const SizedBox(height: 4),
          const Text('Finding your skills, experience and education', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
        ]),
      _Phase.uploading => Column(key: const ValueKey('up'), children: [
          const SizedBox(height: 10),
          Text('${(progress * 100).round()}%', style: AppTheme.display(context, size: 34, color: AppColors.blue)),
          const SizedBox(height: 6),
          Text('Uploading ${fileName ?? 'CV'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: AppMotion.fast,
              builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10, backgroundColor: AppColors.line),
            ),
          ),
          const SizedBox(height: 10),
        ]),
      _Phase.done => Column(key: const ValueKey('done'), children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 14),
          Text('CV uploaded', style: AppTheme.display(context, size: 19)),
          const SizedBox(height: 4),
          const Text('Your details were read. Check and confirm them on the next screen.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onPick, style: OutlinedButton.styleFrom(minimumSize: const Size(200, 48)), child: const Text('Upload a different file')),
        ]),
    };

    return AppCard(
      padding: const EdgeInsets.all(22),
      child: CustomPaint(
        painter: _DashedBorder(color: AppColors.blue.withValues(alpha: 0.45)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
          child: SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: AppMotion.medium,
              switchInCurve: AppMotion.curve,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: child),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingDoc extends StatefulWidget {
  const _FloatingDoc();
  @override
  State<_FloatingDoc> createState() => _FloatingDocState();
}

class _FloatingDocState extends State<_FloatingDoc> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)), child: child),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(22)),
        child: const Icon(Icons.description_rounded, color: AppColors.blue, size: 38),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _CurrentCvCard extends StatelessWidget {
  const _CurrentCvCard({required this.record, required this.onReplace, required this.onDelete});
  final CvRecord record;
  final VoidCallback? onReplace;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final kb = (record.sizeBytes / 1024).round();
    final date = record.uploadedAt;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.redTint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                '$kb KB${date != null ? ' · uploaded ${date.day}/${date.month}/${date.year}' : ''}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ]),
          ),
          const StatusChip('Current', tone: ChipTone.positive),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: onReplace, child: const Text('Replace'))),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Delete'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _WhatHappensNext extends StatelessWidget {
  const _WhatHappensNext();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, String t, String s, bool ready) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(i, color: ready ? AppColors.green : AppColors.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(s, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ]),
            ),
          ]),
        );
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What happens next', style: AppTheme.display(context, size: 16)),
        const SizedBox(height: 6),
        row(Icons.cloud_done_outlined, 'Secure upload', 'Checked for type, size and password protection', true),
        row(Icons.auto_awesome_outlined, 'We scan your CV', 'Skills, experience, education and city', true),
        row(Icons.fact_check_outlined, 'You confirm the details', 'Nothing is saved to your profile without your OK', false),
      ]),
    );
  }
}


class _ScanningDoc extends StatefulWidget {
  const _ScanningDoc();
  @override
  State<_ScanningDoc> createState() => _ScanningDocState();
}

class _ScanningDocState extends State<_ScanningDoc> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 80,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border, width: 2)),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final w in [0.7, 1.0, 1.0, 0.8, 1.0, 0.6])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: FractionallySizedBox(widthFactor: w, child: Container(height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)))),
            ),
        ]),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Positioned(
            left: 0,
            right: 0,
            top: 52 * _c.value,
            child: Container(height: 3, decoration: BoxDecoration(color: AppColors.green, boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 8)])),
          ),
        ),
      ]),
    );
  }
}
