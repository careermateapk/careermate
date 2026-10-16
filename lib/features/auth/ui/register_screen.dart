import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../router/app_router.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';
import '../auth_repository.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _company = TextEditingController();
  final _designation = TextEditingController();
  final _city = TextEditingController();
  final _website = TextEditingController();
  UserRole _role = UserRole.seeker;
  bool _hide = true;
  bool _agreed = false;
  bool _nudge = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _company.dispose();
    _designation.dispose();
    _city.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _nudge = true);
      showMessage(
          context,
          _role == UserRole.recruiter
              ? 'Please confirm you will post only real jobs.'
              : 'Please accept the privacy policy to continue.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            role: _role,
            company: _role == UserRole.recruiter
                ? {
                    'company': _company.text.trim(),
                    'designation': _designation.text.trim(),
                    'companyCity': _city.text.trim(),
                    'companyWebsite': _website.text.trim(),
                  }
                : const {},
          );
      if (mounted) showMessage(context, 'Account created! We sent a verification link to your email.');
    } on AuthFailure catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _consent() {
    final warn = _nudge && !_agreed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: warn ? const Color(0xFFFFF5F5) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warn ? const Color(0xFFFCA5A5) : Colors.transparent, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CheckboxListTile(
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          controlAffinity: ListTileControlAffinity.leading,
          side: warn ? const BorderSide(color: Color(0xFFDC2626), width: 2) : null,
          title: Text(
            _role == UserRole.recruiter
                ? 'I will post only real jobs and never ask candidates for money.'
                : 'I agree that my CV and profile are stored securely to find jobs for me. I can delete them anytime.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (warn)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFB91C1C)),
              SizedBox(width: 6),
              Text('Tick the box above to continue',
                  style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700, fontSize: 12.5)),
            ]),
          ),
      ]),
    );
  }

  void _blocked() {
    setState(() => _nudge = true);
    showMessage(context, 'Please tick the agreement box first, then continue with Google.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'I am a',
      children: [
        RolePicker(value: _role, onChanged: (r) => setState(() => _role = r)),
        const SizedBox(height: 14),
        _consent(),
        if (_role == UserRole.seeker) ...[
          GoogleButton(enabled: _agreed, onBlocked: _blocked),
          const OrDivider(),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppColors.amberTint, borderRadius: BorderRadius.circular(14)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.verified_user_outlined, color: AppColors.amberText, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Use your company email. We verify every recruiter so job seekers stay safe from fake jobs.',
                    style: TextStyle(color: AppColors.amberText, fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.45)),
              ),
            ]),
          ),
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: _role == UserRole.recruiter ? 'Work email' : 'Email',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                ),
                validator: (v) {
                  final e = validateEmail(v);
                  if (e != null) return e;
                  if (_role == UserRole.recruiter && !isCompanyEmail(v!)) return 'Use your company email, not Gmail/Yahoo/Outlook';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters, with a letter and a number',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hide ? 'Show password' : 'Hide password',
                    icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hide = !_hide),
                  ),
                ),
                validator: (v) {
                  final s = v ?? '';
                  if (s.length < 8) return 'Use at least 8 characters';
                  if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
                    return 'Use letters and numbers';
                  }
                  return null;
                },
              ),
              if (_role == UserRole.recruiter) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('COMPANY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _company,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Company name', prefixIcon: Icon(Icons.business_outlined)),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your company name' : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _designation,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Your role'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'City'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _website,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Company website (optional)', prefixIcon: Icon(Icons.language_rounded)),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 8),
        LoadingButton(label: _role == UserRole.recruiter ? 'Create recruiter account' : 'Create account', loading: _busy, onPressed: _submit),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Already have an account?'),
          TextButton(onPressed: () => context.go(Routes.login), child: const Text('Log in')),
        ]),
      ],
    );
  }
}
