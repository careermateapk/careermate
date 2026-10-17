import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../profile/taxonomy.dart';
import '../job_post.dart';
import '../post_reader.dart';

/// A job post shared from LinkedIn/WhatsApp (or pasted): read it, check it, then add it for everyone.
class ShareJobScreen extends ConsumerStatefulWidget {
  const ShareJobScreen({super.key, this.text = '', this.imagePath});
  final String text;

  /// A screenshot shared into the app (read with OCR).
  final String? imagePath;

  @override
  ConsumerState<ShareJobScreen> createState() => _ShareJobScreenState();
}

class _ShareJobScreenState extends ConsumerState<ShareJobScreen> {
  late final _input = TextEditingController(text: widget.text);
  final _title = TextEditingController();
  final _location = TextEditingController();
  SharedPost? _post;
  List<PostCheck>? _checks;
  bool _checking = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _readImage(widget.imagePath!));
    } else if (widget.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  bool _reading = false;

  Future<void> _readImage(String path) async {
    setState(() => _reading = true);
    try {
      final text = await PostReader.fromImage(path);
      if (!mounted) return;
      if (text.trim().length < 40) {
        showMessage(context, 'Couldn’t read enough text in that picture. Try a clearer screenshot of the post.', error: true);
        return;
      }
      _input.text = text;
      await _run();
    } catch (_) {
      if (mounted) showMessage(context, 'Couldn’t read that picture.', error: true);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final f = File('${(await getTemporaryDirectory()).path}/post_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(bytes);
    await _readImage(f.path);
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) setState(() => _input.text = d!.text!);
  }

  Future<void> _run() async {
    var text = _input.text.trim();
    final link = RegExp(r'https?://\S+').firstMatch(text)?.group(0);
    final onlyLink = link != null && text.replaceAll(link, '').trim().length < 40;
    if (onlyLink) {
      setState(() => _reading = true);
      final fetched = await PostReader.fromLink(link);
      if (!mounted) return;
      setState(() => _reading = false);
      if (fetched.replaceAll(link, '').trim().length >= 60) {
        _input.text = fetched;
        text = fetched;
      } else {
        final pick = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('This post needs a LinkedIn login'),
            content: const Text(
                'We couldn’t read it from the link, because LinkedIn shows it only to signed-in members.\n\n'
                'Easy way: take a screenshot of the post, then pick it here — CareerMate reads the text from the picture.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Pick screenshot')),
            ],
          ),
        );
        if (pick == true) await _pickScreenshot();
        return;
      }
    }
    if (text.length < 40) {
      showMessage(context, 'Paste the full job post text.', error: true);
      return;
    }
    final p = SharedPost.parse(text);
    setState(() {
      _post = p;
      _checks = null;
      _checking = true;
      _title.text = p.title;
      _location.text = p.location;
    });
    final checks = await ref.read(communityRepositoryProvider).check(p);
    if (mounted) setState(() {
      _checks = checks;
      _checking = false;
    });
  }

  SharedPost _edited() {
    final p = _post!;
    return SharedPost(
      raw: p.raw,
      title: _title.text.trim(),
      location: _location.text.trim(),
      experience: p.experience,
      qualification: p.qualification,
      email: p.email,
      phone: p.phone,
      link: p.link,
      source: p.source,
      subIds: p.subIds,
      skills: p.skills,
    );
  }

  Future<void> _publish() async {
    final uid = ref.read(authStateProvider).value?.uid;
    final checks = _checks;
    if (uid == null || checks == null) return;
    final p = _edited();
    if (p.title.isEmpty) {
      showMessage(context, 'Add the job title first.', error: true);
      return;
    }
    if (p.subIds.isEmpty) {
      showMessage(context, 'We could not tell the job category from this post, so it can’t be listed yet.', error: true);
      return;
    }
    setState(() => _publishing = true);
    try {
      final repo = ref.read(communityRepositoryProvider);
      if (await repo.exists(p.id)) {
        if (mounted) showMessage(context, 'This job is already on CareerMate. Thanks!');
      } else {
        await repo.publish(p, uid: uid, passed: checks.where((c) => c.result == CheckResult.ok).length, total: checks.length);
        if (mounted) showMessage(context, 'Added! People looking for ${subCategoryById(p.subIds.first)?.name ?? 'this kind of'} jobs will see it.');
      }
      if (mounted) context.go(Routes.jobs);
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString().contains('permission') ? 'Update the Firebase rules first (see the latest rules file).' : 'Could not add the job. Try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    final checks = _checks;
    final bad = checks?.any((c) => c.result == CheckResult.bad) ?? false;
    final passed = checks?.where((c) => c.result == CheckResult.ok).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p == null ? 'Share a job post' : 'Checking this job'),
          if (p != null)
            Text('Shared from ${p.source}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 140), children: [
        if (p == null) ...[
          const AppCard(
            child: Text(
              'Saw a job on LinkedIn or WhatsApp? Share the post link or a screenshot to CareerMate, or paste the text here. '
              'We check it, then show it to everyone looking for that kind of job.',
              style: TextStyle(height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _input, minLines: 8, maxLines: 16, decoration: const InputDecoration(hintText: 'Paste the job post here')),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste_rounded), label: const Text('Paste')),
              TextButton.icon(
                onPressed: _reading ? null : _pickScreenshot,
                icon: const Icon(Icons.image_search_rounded),
                label: const Text('Read from screenshot'),
              ),
            ]),
          ),
          if (_reading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
                SizedBox(width: 10),
                Text('Reading the post…'),
              ]),
            ),
        ] else ...[
          FadeSlideIn(
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('WHAT WE READ FROM THE POST',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextField(controller: _title, decoration: const InputDecoration(labelText: 'Job title')),
                const SizedBox(height: 10),
                TextField(controller: _location, decoration: const InputDecoration(labelText: 'City')),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (p.experience.isNotEmpty) StatusChip(p.experience),
                  if (p.qualification.isNotEmpty) StatusChip(p.qualification),
                  for (final s in p.subIds.take(2)) StatusChip(subCategoryById(s)?.name ?? s, tone: ChipTone.info),
                ]),
                if (p.email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Apply by email: ${p.email}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(
                    child: Text('AUTHENTICITY CHECK',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: AppColors.textMuted)),
                  ),
                  if (checks != null)
                    StatusChip(
                      bad ? 'Not safe to list' : passed >= checks.length - 1 ? 'Looks genuine · $passed/${checks.length}' : 'Be careful · $passed/${checks.length}',
                      tone: bad ? ChipTone.risk : passed >= checks.length - 1 ? ChipTone.positive : ChipTone.warning,
                    ),
                ]),
                const SizedBox(height: 6),
                if (_checking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Row(children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                      SizedBox(width: 12),
                      Text('Checking email, website and warning signs…'),
                    ]),
                  ),
                for (final (i, c) in (checks ?? const <PostCheck>[]).indexed)
                  FadeSlideIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (c.result) {
                              CheckResult.ok => AppColors.greenTint,
                              CheckResult.warn => AppColors.amberTint,
                              CheckResult.bad => AppColors.redTint,
                            },
                          ),
                          child: Icon(
                            switch (c.result) {
                              CheckResult.ok => Icons.check_rounded,
                              CheckResult.warn => Icons.priority_high_rounded,
                              CheckResult.bad => Icons.close_rounded,
                            },
                            size: 15,
                            color: switch (c.result) {
                              CheckResult.ok => AppColors.green,
                              CheckResult.warn => AppColors.amber,
                              CheckResult.bad => AppColors.red,
                            },
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(c.detail, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            bad
                ? 'This post shows a serious warning sign, so it can’t be added for others. Don’t pay anyone for a job.'
                : 'Only add posts you saw yourself. Others can report a job as fake; reported jobs are hidden.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
          ),
          TextButton(onPressed: () => setState(() => _post = null), child: const Text('Edit the post text')),
        ],
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: p == null
            ? LoadingButton(label: 'Check this job', icon: Icons.verified_user_outlined, onPressed: _run)
            : LoadingButton(
                label: 'Add to CareerMate',
                loading: _publishing,
                onPressed: (checks == null || bad) ? null : _publish,
              ),
      ),
    );
  }
}
