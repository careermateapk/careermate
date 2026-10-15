import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const GoogleButton({super.key});

  @override
  ConsumerState<GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends ConsumerState<GoogleButton> {
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
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
    return OutlinedButton(
      onPressed: _busy ? null : _go,
      child: _busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                child: const Text('G', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.blue, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              const Text('Continue with Google'),
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
