import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../../account/account_service.dart';
import '../../auth/auth_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: const Text(
            'This deletes your login, profile, uploaded CV and all saved data. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(accountServiceProvider).deleteAccount();
    } on AuthFailure catch (e) {
      if (context.mounted) showMessage(context, e.message, error: true);
    } catch (_) {
      if (context.mounted) showMessage(context, 'Could not delete the account. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              FadeSlideIn(
                child: AppCard(
                  child: Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.navy,
                      foregroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                      child: const Icon(Icons.person_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user?.displayName ?? 'Your account', style: AppTheme.display(context, size: 17)),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.textMuted)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_outlined)),
                        ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 2,
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
                      onTap: () => _logout(context, ref),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: AppColors.red),
                      title: const Text('Delete account and all data',
                          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.red)),
                      subtitle: const Text('Removes your CV, profile and login'),
                      onTap: () => _deleteAccount(context, ref),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('${AppConfig.appName} · version 0.1.0',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
