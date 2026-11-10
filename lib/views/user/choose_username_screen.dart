import 'package:flutter/material.dart';

import '../../services/auth/account_service.dart';
import '../../entities/user/models.dart';
import '../../items/kickoff_style.dart';

/// Shown once, right after signing up: the player picks a username that no
/// one else has.
class ChooseUsernameScreen extends StatefulWidget {
  const ChooseUsernameScreen({
    required this.account,
    required this.onDone,
    required this.onLogout,
    super.key,
  });

  final AccountService account;
  final ValueChanged<UserAccount> onDone;
  final VoidCallback onLogout;

  @override
  State<ChooseUsernameScreen> createState() => _ChooseUsernameScreenState();
}

class _ChooseUsernameScreenState extends State<ChooseUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.account.setUsername(_username.text.trim());
      if (mounted) widget.onDone(user);
    } on AccountException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the cloud.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Choose your username',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This is how friends find you. It must be one nobody else '
                  'is using.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KickoffColors.muted),
                ),
                const SizedBox(height: 24),
                PillField(
                  key: const ValueKey('choose_username'),
                  controller: _username,
                  hint: 'Username',
                  icon: Icons.alternate_email_rounded,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (!RegExp(
                      r'^[a-zA-Z0-9_]{3,20}$',
                    ).hasMatch(value?.trim() ?? '')) {
                      return 'Use 3-20 letters, numbers, or underscores.';
                    }
                    return null;
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const ValueKey('choose_username_error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: KickoffColors.orange),
                    ),
                  ),
                const SizedBox(height: 20),
                ChunkyButton(
                  key: const ValueKey('choose_username_submit'),
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _submit,
                ),
                TextButton(
                  onPressed: _busy ? null : widget.onLogout,
                  child: const Text(
                    'Sign out',
                    style: TextStyle(color: KickoffColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
