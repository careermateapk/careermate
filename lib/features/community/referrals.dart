import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../jobs/job_models.dart';
import '../jobs/women_filter.dart' show companyKey;
import '../profile/profile_repository.dart';
import '../recruiter/posted_job.dart' show findMoneyAsk;

/// Requests a job seeker can send in 7 days, so referrers are not flooded.
const referralsPerWeek = 3;

class Referrer {
  Referrer(this.uid, this.m);
  final String uid;
  final Map<String, dynamic> m;
  String get name => m['name'] as String? ?? '';
  String get role => m['role'] as String? ?? '';
  String get company => m['company'] as String? ?? '';
  String get email => m['email'] as String? ?? '';
  String get domain => email.split('@').last;
  bool get active => m['active'] as bool? ?? true;
}

class ReferralRequest {
  ReferralRequest(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  String get fromUid => m['fromUid'] as String? ?? '';
  String get toUid => m['toUid'] as String? ?? '';
  String get fromName => m['fromName'] as String? ?? '';
  String get fromEmail => m['fromEmail'] as String? ?? '';
  String get toName => m['toName'] as String? ?? '';
  String get jobTitle => m['jobTitle'] as String? ?? '';
  String get company => m['company'] as String? ?? '';
  String get jobUrl => m['jobUrl'] as String? ?? '';
  String get message => m['message'] as String? ?? '';
  String get summary => m['summary'] as String? ?? '';
  String get status => m['status'] as String? ?? 'pending';
  DateTime? get at => (m['createdAt'] as Timestamp?)?.toDate();
}

final referrersAtProvider = StreamProvider.family<List<Referrer>, String>((ref, company) => ref
    .watch(firestoreProvider)
    .collection('referrers')
    .where('companyKey', isEqualTo: companyKey(company))
    .limit(30)
    .snapshots()
    .map((s) => s.docs.map((d) => Referrer(d.id, d.data())).where((r) => r.active).toList()));

final myReferrerProvider = StreamProvider<Referrer?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(firestoreProvider).collection('referrers').doc(uid).snapshots().map((s) => s.exists ? Referrer(s.id, s.data()!) : null);
});

final _sentProvider = StreamProvider<List<ReferralRequest>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('referral_requests')
      .where('fromUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => ReferralRequest(d.id, d.data())).toList()..sort(_newest));
});

final _receivedProvider = StreamProvider<List<ReferralRequest>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('referral_requests')
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => ReferralRequest(d.id, d.data())).toList()..sort(_newest));
});

int _newest(ReferralRequest a, ReferralRequest b) => (b.at ?? DateTime(2100)).compareTo(a.at ?? DateTime(2100));

/// Shown from a job: people at that company who offered to refer.
class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key, required this.job});
  final JobItem job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authStateProvider).value?.uid;
    final async = ref.watch(referrersAtProvider(job.company));
    final people = (async.value ?? const <Referrer>[]).where((r) => r.uid != myUid).toList();
    final sent = ref.watch(_sentProvider).value ?? const <ReferralRequest>[];
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final usedThisWeek = sent.where((r) => (r.at ?? DateTime.now()).isAfter(weekAgo)).length;
    final left = (referralsPerWeek - usedThisWeek).clamp(0, referralsPerWeek);

    return Scaffold(
      appBar: AppBar(
        title: Text('Referral at ${job.company}', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReferralsHomeScreen())), child: const Text('My referrals')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Text('People who work at ${job.company} and offered to refer. Their work email is verified.',
            style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
        const SizedBox(height: 6),
        Text('You can send $left more request${left == 1 ? '' : 's'} this week.', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (async.isLoading && people.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (people.isEmpty)
          AppCard(
            child: Text('No one from ${job.company} has offered referrals yet. Try again later, or apply directly.',
                style: const TextStyle(height: 1.45)),
          ),
        for (final p in people) ...[
          _ReferrerCard(person: p, job: job, canSend: left > 0, already: sent.any((s) => s.toUid == p.uid && s.jobUrl == job.url)),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        const Text('A referral is a favour, not a promise of a job. Never pay anyone for a referral.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _ReferrerCard extends StatelessWidget {
  const _ReferrerCard({required this.person, required this.job, required this.canSend, required this.already});
  final Referrer person;
  final JobItem job;
  final bool canSend;
  final bool already;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          CircleAvatar(
            backgroundColor: AppColors.blueTint,
            child: Text(person.name.isEmpty ? '?' : person.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(person.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (person.role.isNotEmpty) Text(person.role, style: const TextStyle(fontSize: 12.5)),
              Text('✓ Verified @${person.domain}', style: const TextStyle(fontSize: 12, color: AppColors.greenText, fontWeight: FontWeight.w700)),
            ]),
          ),
          FilledButton(
            onPressed: already || !canSend
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _AskScreen(person: person, job: job))),
            child: Text(already ? 'Asked' : 'Ask'),
          ),
        ]),
      );
}

class _AskScreen extends ConsumerStatefulWidget {
  const _AskScreen({required this.person, required this.job});
  final Referrer person;
  final JobItem job;
  @override
  ConsumerState<_AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<_AskScreen> {
  late final _msg = TextEditingController(
      text: 'Hi ${widget.person.name.split(' ').first}, I am applying for ${widget.job.title} at ${widget.job.company}. '
          'Could you please refer me if my profile fits? Thank you!');
  bool _busy = false;

  Future<void> _send() async {
    final user = ref.read(authStateProvider).value;
    final p = ref.read(profileProvider).value;
    if (user == null) return;
    if (findMoneyAsk(_msg.text) != null) {
      showMessage(context, 'Please don’t mention money.', error: true);
      return;
    }
    setState(() => _busy = true);
    final summary = p == null
        ? ''
        : [
            if (p.titles.isNotEmpty) p.titles.first,
            '${p.experienceYears.toStringAsFixed(p.experienceYears % 1 == 0 ? 0 : 1)} yrs experience',
            if (p.location.isNotEmpty) p.location,
            if (p.skills.isNotEmpty) 'Skills: ${p.skills.take(8).join(', ')}',
          ].join(' · ');
    try {
      await ref.read(firestoreProvider).collection('referral_requests').add({
        'fromUid': user.uid,
        'fromName': p?.name.isNotEmpty == true ? p!.name : (user.displayName ?? ''),
        'fromEmail': p?.email.isNotEmpty == true ? p!.email : (user.email ?? ''),
        'toUid': widget.person.uid,
        'toName': widget.person.name,
        'jobTitle': widget.job.title,
        'company': widget.job.company,
        'jobUrl': widget.job.url,
        'message': _msg.text.trim(),
        'summary': summary,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showMessage(context, 'Request sent to ${widget.person.name}.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showMessage(context, 'Could not send. Update the Firebase rules and try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Ask ${widget.person.name}')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.job.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(widget.job.company, style: const TextStyle(color: AppColors.textMuted)),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(controller: _msg, minLines: 4, maxLines: 8, maxLength: 500, decoration: const InputDecoration(labelText: 'Your message')),
          const Text('They will see your name, email, role, experience, city and top skills from your CV — not your phone number.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 16),
          LoadingButton(label: 'Send request', icon: Icons.send_rounded, loading: _busy, onPressed: _send),
        ]),
      );
}

/// Sent and received requests, plus the "I can refer" setting.
class ReferralsHomeScreen extends ConsumerWidget {
  const ReferralsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myReferrerProvider).value;
    final sent = ref.watch(_sentProvider).value ?? const <ReferralRequest>[];
    final got = ref.watch(_receivedProvider).value ?? const <ReferralRequest>[];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Referrals'),
          bottom: TabBar(tabs: [Tab(text: 'Asked by me (${sent.length})'), Tab(text: 'Asked to me (${got.length})')]),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(20), children: [
            if (sent.isEmpty)
              const AppCard(child: Text('Open any job and tap “Get a referral” to ask someone who works there.', style: TextStyle(height: 1.45))),
            for (final r in sent) ...[
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r.jobTitle} · ${r.company}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    _statusChip(r.status),
                  ]),
                  Text('Asked ${r.toName}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ]),
          ListView(padding: const EdgeInsets.all(20), children: [
            _ReferrerSetting(me: me),
            const SizedBox(height: 12),
            for (final r in got) ...[
              _ReceivedCard(r: r),
              const SizedBox(height: 10),
            ],
          ]),
        ]),
      ),
    );
  }
}

Widget _statusChip(String s) => switch (s) {
      'referred' => const StatusChip('Referred ✓', tone: ChipTone.positive),
      'declined' => const StatusChip('Not now', tone: ChipTone.neutral),
      _ => const StatusChip('Waiting', tone: ChipTone.warning),
    };

class _ReceivedCard extends ConsumerWidget {
  const _ReceivedCard({required this.r});
  final ReferralRequest r;

  Future<void> _set(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(firestoreProvider).collection('referral_requests').doc(r.id).update({'status': status, 'answeredAt': FieldValue.serverTimestamp()});
    } catch (_) {
      if (context.mounted) showMessage(context, 'Could not update. Check your connection.', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.fromName, style: const TextStyle(fontWeight: FontWeight.w800))),
            _statusChip(r.status),
          ]),
          Text('For ${r.jobTitle}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          if (r.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.summary, style: const TextStyle(fontSize: 12.5))),
          if (r.message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${r.message}”')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (r.fromEmail.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'mailto', path: r.fromEmail, query: 'subject=${Uri.encodeComponent('Referral for ${r.jobTitle}')}')),
                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                label: const Text('Ask for CV'),
              ),
            if (r.jobUrl.isNotEmpty)
              OutlinedButton(onPressed: () => launchUrl(Uri.parse(r.jobUrl), mode: LaunchMode.externalApplication), child: const Text('See job')),
            if (r.status == 'pending') ...[
              FilledButton(onPressed: () => _set(context, ref, 'referred'), child: const Text('I referred them')),
              TextButton(onPressed: () => _set(context, ref, 'declined'), child: const Text('Not now')),
            ],
          ]),
        ]),
      );
}

class _ReferrerSetting extends ConsumerStatefulWidget {
  const _ReferrerSetting({required this.me});
  final Referrer? me;
  @override
  ConsumerState<_ReferrerSetting> createState() => _ReferrerSettingState();
}

class _ReferrerSettingState extends ConsumerState<_ReferrerSetting> {
  bool _busy = false;

  Future<void> _optIn() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final email = (user.email ?? '').toLowerCase();
    final userDoc = ref.read(userDocProvider).value ?? const {};
    final p = ref.read(profileProvider).value;
    final company = TextEditingController(text: (userDoc['company'] as String?) ?? '');
    final role = TextEditingController(text: p?.titles.isNotEmpty == true ? p!.titles.first : '');
    final name = TextEditingController(text: p?.name.isNotEmpty == true ? p!.name : (user.displayName ?? ''));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Offer referrals'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name')),
            TextField(controller: company, decoration: const InputDecoration(labelText: 'Company you work at')),
            TextField(controller: role, decoration: const InputDecoration(labelText: 'Your role')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || company.text.trim().isEmpty || name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(firestoreProvider).collection('referrers').doc(user.uid).set({
        'name': name.text.trim(),
        'company': company.text.trim(),
        'companyKey': companyKey(company.text),
        'role': role.text.trim(),
        'email': email,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showMessage(context, 'Done! Job seekers can now ask you for referrals.');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not save. Update the Firebase rules and try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(bool v) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(firestoreProvider).collection('referrers').doc(uid).update({'active': v});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final email = user?.email ?? '';
    final canRefer = user != null && user.emailVerified && isCompanyEmail(email);
    final me = widget.me;
    if (me != null) {
      return AppCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: me.active,
          onChanged: _setActive,
          title: Text('I can refer at ${me.company}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(me.active ? 'Job seekers can ask you' : 'Paused — no one can ask you'),
        ),
      );
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Working somewhere? Help others get in.', style: AppTheme.display(context, size: 16)),
        const SizedBox(height: 6),
        Text(
          canRefer
              ? 'Your company email $email is verified, so you can offer referrals.'
              : 'To offer referrals, sign in with your verified company email (not Gmail/Yahoo). This keeps fake referrers out.',
          style: const TextStyle(height: 1.45),
        ),
        const SizedBox(height: 10),
        if (canRefer) LoadingButton(label: 'I can refer', icon: Icons.handshake_outlined, loading: _busy, onPressed: _optIn),
      ]),
    );
  }
}
