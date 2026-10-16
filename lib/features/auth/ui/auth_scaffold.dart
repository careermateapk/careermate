import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../auth_repository.dart';

/// Shared layout for login, register and password reset:
/// navy header with the logo, then a white sheet with the form.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.showBack = false});

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, c) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Row(children: [
                        if (showBack)
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            tooltip: 'Back',
                          ),
                        const Spacer(),
                      ]),
                    ),
                    const BrandLogo(size: 72),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(minHeight: c.maxHeight * 0.66),
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          FadeSlideIn(child: Text(title, style: AppTheme.display(context, size: 26))),
                          const SizedBox(height: 6),
                          FadeSlideIn(
                            index: 1,
                            child: Text(subtitle,
                                style: TextStyle(fontSize: 14.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
                          ),
                          const SizedBox(height: 24),
                          for (var i = 0; i < children.length; i++) FadeSlideIn(index: i + 2, child: children[i]),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// "Continue with Google" button.
class GoogleButton extends ConsumerStatefulWidget {
  const GoogleButton({super.key, this.allowNewAccount = true, this.enabled = true, this.onBlocked});

  /// False on the login page: new Google emails must register first.
  final bool allowNewAccount;

  /// False until the sign-up consent box is ticked. Tapping then calls [onBlocked] instead of signing in.
  final bool enabled;
  final VoidCallback? onBlocked;

  @override
  ConsumerState<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends ConsumerState<GoogleButton> {
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle(allowNewAccount: widget.allowNewAccount);
    } on AuthCancelled catch (e) {
      if (mounted) {
        showMessage(context, e.detail.isEmpty ? 'Google sign-in was closed.' : 'Google sign-in was closed: ${e.detail}');
      }
    } on AuthFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } catch (e) {
      if (mounted) showMessage(context, 'Google sign-in error: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.enabled;
    return OutlinedButton(
      onPressed: _busy ? null : (locked ? widget.onBlocked : _go),
      style: locked
          ? OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFA0A8BA),
              backgroundColor: const Color(0x0F8A93A8),
            )
          : null,
      child: _busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                child: Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: locked ? const Color(0xFFA0A8BA) : AppColors.blue, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text(locked ? 'Continue with Google (tick the box first)' : 'Continue with Google', overflow: TextOverflow.ellipsis)),
            ]),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: muted, fontWeight: FontWeight.w700))),
        const Expanded(child: Divider()),
      ]),
    );
  }
}

String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email';
  return null;
}

/// Two cards: Job seeker / Recruiter.
class RolePicker extends StatelessWidget {
  const RolePicker({super.key, required this.value, required this.onChanged});
  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _RoleCard(
          selected: value == UserRole.seeker,
          icon: Icons.search_rounded,
          iconBg: AppColors.blue,
          iconFg: Colors.white,
          title: 'Job seeker',
          subtitle: 'Find jobs that match your CV',
          onTap: () => onChanged(UserRole.seeker),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _RoleCard(
          selected: value == UserRole.recruiter,
          icon: Icons.person_add_alt_1_rounded,
          iconBg: AppColors.amberTint,
          iconFg: AppColors.amber,
          title: 'Recruiter',
          subtitle: 'Post jobs and find candidates',
          onTap: () => onChanged(UserRole.recruiter),
        ),
      ),
    ]);
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.curve,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue.withValues(alpha: 0.08) : scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? AppColors.blue : scheme.outline, width: selected ? 2 : 1.5),
            boxShadow: selected ? [BoxShadow(color: AppColors.blue.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))] : null,
          ),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconFg, size: 22),
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.65))),
            ]),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: AppMotion.medium,
                curve: Curves.easeOutBack,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
