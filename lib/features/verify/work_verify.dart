import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../profile/profile_repository.dart';

/// Web page a manager opens to confirm (GitHub Pages, free).
const verifyPageUrl = 'https://careermateapk.github.io/careermate/verify.html';

class WorkCheck {
  WorkCheck(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  String get company => m['company'] as String? ?? '';
  String get role => m['role'] as String? ?? '';
  String get from => m['from'] as String? ?? '';
  String get to => m['to'] as String? ?? '';
  String get email => m['email'] as String? ?? '';
  String get managerName => m['managerName'] as String? ?? '';
  String get domain => email.split('@').last;
  String get status => m['status'] as String? ?? 'pending';
  String get link => '$verifyPageUrl?id=$id&e=${Uri.encodeComponent(email)}';
}

final myWorkChecksProvider = StreamProvider<List<WorkCheck>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('work_checks')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => WorkCheck(d.id, d.data())).toList());
});

/// Confirmed jobs for any user — what recruiters see on an application.
final verifiedWorkProvider = StreamProvider.family<List<WorkCheck>, String>((ref, uid) => ref
    .watch(firestoreProvider)
    .collection('work_checks')
    .where('uid', isEqualTo: uid)
    .where('status', isEqualTo: 'confirmed')
    .snapshots()
    .map((s) => s.docs.map((d) => WorkCheck(d.id, d.data())).toList()));

/// Chips for the recruiter's applicant card.
class VerifiedWorkChips extends ConsumerWidget {
  const VerifiedWorkChips({super.key, required this.uid});
  final String uid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(verifiedWorkProvider(uid)).value ?? const <WorkCheck>[];
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final w in list) StatusChip('✅ ${w.role} at ${w.company} · confirmed by @${w.domain}', tone: ChipTone.positive),
    ]);
  }
}

Future<void> _emailManager(WorkCheck w, String myName) => launchUrl(Uri(
      scheme: 'mailto',
      path: w.email,
      query: 'subject=${Uri.encodeComponent('Please confirm I worked at ${w.company}')}'
          '&body=${Uri.encodeComponent('Hi ${w.managerName.split(' ').first},\n\n'
              'I am applying for jobs on CareerMate. Could you please confirm that I worked at ${w.company} as ${w.role} (${w.from} – ${w.to})?\n\n'
              'It takes one minute — open this link and confirm with your work email:\n${w.link}\n\n'
              'Thank you!\n$myName')}',
    ));

class VerifyExperienceScreen extends ConsumerWidget {
  const VerifyExperienceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myWorkChecksProvider).value ?? const <WorkCheck>[];
    final name = ref.watch(profileProvider).value?.name ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify my experience')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AddWorkCheck())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add a job'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Get a ✅ Verified badge', style: AppTheme.display(context, size: 16)),
            const SizedBox(height: 6),
            const Text(
              'Your old manager confirms your job with their company email. Recruiters then see “Confirmed by @company.com” on your application.',
              style: TextStyle(height: 1.45),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final w in list) ...[
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${w.role} · ${w.company}', style: const TextStyle(fontWeight: FontWeight.w800))),
                switch (w.status) {
                  'confirmed' => const StatusChip('✅ Verified', tone: ChipTone.positive),
                  'declined' => const StatusChip('Not confirmed', tone: ChipTone.risk),
                  _ => const StatusChip('Waiting', tone: ChipTone.warning),
                },
              ]),
              Text('${w.from} – ${w.to} · ${w.managerName} (${w.email})', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              if (w.status == 'pending') ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  FilledButton.icon(
                    onPressed: () => _emailManager(w, name),
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: const Text('Email again'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: w.link));
                      if (context.mounted) showMessage(context, 'Link copied. Send it on WhatsApp too.');
                    },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copy link'),
                  ),
                ]),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => ref.read(firestoreProvider).collection('work_checks').doc(w.id).delete(),
                  child: const Text('Remove', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _AddWorkCheck extends ConsumerStatefulWidget {
  const _AddWorkCheck();
  @override
  ConsumerState<_AddWorkCheck> createState() => _AddWorkCheckState();
}

class _AddWorkCheckState extends ConsumerState<_AddWorkCheck> {
  final _company = TextEditingController();
  final _role = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController(text: 'Present');
  final _mName = TextEditingController();
  final _mEmail = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final email = _mEmail.text.trim().toLowerCase();
    if ([_company, _role, _from, _mName].any((c) => c.text.trim().isEmpty)) {
      showMessage(context, 'Please fill all the details.', error: true);
      return;
    }
    if (!isCompanyEmail(email)) {
      showMessage(context, 'Use your manager’s company email (not Gmail/Yahoo).', error: true);
      return;
    }
    if (email == (user.email ?? '').toLowerCase()) {
      showMessage(context, 'This must be your manager’s email, not yours.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final doc = await ref.read(firestoreProvider).collection('work_checks').add({
        'uid': user.uid,
        'name': ref.read(profileProvider).value?.name ?? user.displayName ?? '',
        'company': _company.text.trim(),
        'role': _role.text.trim(),
        'from': _from.text.trim(),
        'to': _to.text.trim(),
        'managerName': _mName.text.trim(),
        'email': email,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      final snap = await doc.get();
      if (!mounted) return;
      await _emailManager(WorkCheck(doc.id, snap.data() ?? {}), ref.read(profileProvider).value?.name ?? '');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not save. Update the Firebase rules and try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add a job to verify')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company')),
          const SizedBox(height: 10),
          TextField(controller: _role, decoration: const InputDecoration(labelText: 'Your role there')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'From', hintText: 'Jan 2021'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _to, decoration: const InputDecoration(labelText: 'To'))),
          ]),
          const SizedBox(height: 16),
          const Text('MANAGER / HR WHO CAN CONFIRM', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          TextField(controller: _mName, decoration: const InputDecoration(labelText: 'Their name')),
          const SizedBox(height: 10),
          TextField(
            controller: _mEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Their company email', hintText: 'name@company.com'),
          ),
          const SizedBox(height: 8),
          const Text('Next, your Gmail opens with a ready message and link. You check it and press Send.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 16),
          LoadingButton(label: 'Save & email manager', icon: Icons.send_rounded, loading: _busy, onPressed: _save),
        ]),
      );
}
