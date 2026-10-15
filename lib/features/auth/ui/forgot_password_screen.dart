import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../auth_repository.dart';
import 'auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Reset password',
      subtitle: 'We will email you a link to set a new password.',
      children: [
        AnimatedSwitcher(
          duration: AppMotion.medium,
          child: _sent
              ? Container(
                  key: const ValueKey('sent'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.greenTint, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(children: [
                    const Icon(Icons.mark_email_read_outlined, color: AppColors.greenText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'If an account exists for ${_email.text.trim()}, a reset link is on its way. Check your spam folder too.',
                        style: const TextStyle(color: AppColors.greenText, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                )
              : Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    LoadingButton(label: 'Send reset link', loading: _busy, onPressed: _submit),
                  ]),
                ),
        ),
      ],
    );
  }
}
