import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'models.dart';
import 'screens/kickoff_style.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.onAuthenticated,
    required this.onGuest,
    super.key,
  });

  final ApiClient api;
  final ValueChanged<UserAccount> onAuthenticated;
  final VoidCallback onGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _showSignUp() {
    setState(() {
      _registering = true;
      _error = null;
    });
  }

  void _showSignIn() {
    setState(() {
      _registering = false;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _registering
          ? await widget.api.register(
              username: _username.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await widget.api.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      if (mounted) widget.onAuthenticated(user);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not connect to the server: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _registering;
    final scale = kickoffScale(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: KickoffColors.bg,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: KickoffColors.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: KickoffColors.bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      if (isSignUp)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back to sign in',
                            onPressed: _busy ? null : _showSignIn,
                            constraints: BoxConstraints(
                              minWidth: 56 * scale,
                              minHeight: 56 * scale,
                            ),
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: KickoffColors.muted,
                              size: 22 * scale,
                            ),
                          ),
                        ),
                      SizedBox(height: constraints.maxHeight * 0.04),
                      Column(
                        children: [
                          const KickoffLogoTile(),
                          if (!isSignUp) ...[
                            SizedBox(height: 10 * scale),
                            Text(
                              'KICKOFF',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13 * scale,
                                letterSpacing: 4 * scale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: constraints.maxHeight * 0.07),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (isSignUp) ...[
                                PillField(
                                  controller: _username,
                                  hint: 'Player name',
                                  icon: Icons.alternate_email_rounded,
                                  validator: (value) {
                                    final username = value?.trim() ?? '';
                                    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$')
                                        .hasMatch(username)) {
                                      return 'Use 3-20 letters, numbers, or underscores.';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 12 * scale),
                              ],
                              PillField(
                                controller: _email,
                                hint: 'Email',
                                icon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(email)) {
                                    return 'Enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 12 * scale),
                              PillField(
                                controller: _password,
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscurePassword,
                                textInputAction: isSignUp
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                onSubmitted: isSignUp ? null : (_) => _submit(),
                                suffix: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  constraints: BoxConstraints(
                                    minWidth: 56 * scale,
                                    minHeight: 56 * scale,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: KickoffColors.muted,
                                    size: 22 * scale,
                                  ),
                                ),
                                validator: (value) {
                                  final password = value ?? '';
                                  if (isSignUp && password.length < 8) {
                                    return 'Use at least 8 characters.';
                                  }
                                  if (password.isEmpty) {
                                    return 'Enter password.';
                                  }
                                  return null;
                                },
                              ),
                              if (isSignUp) ...[
                                SizedBox(height: 12 * scale),
                                PillField(
                                  controller: _confirmation,
                                  hint: 'Confirm',
                                  icon: Icons.verified_user_outlined,
                                  obscureText: _obscureConfirmation,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  suffix: IconButton(
                                    tooltip: _obscureConfirmation
                                        ? 'Show confirmation'
                                        : 'Hide confirmation',
                                    constraints: BoxConstraints(
                                      minWidth: 56 * scale,
                                      minHeight: 56 * scale,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmation =
                                          !_obscureConfirmation,
                                    ),
                                    icon: Icon(
                                      _obscureConfirmation
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: KickoffColors.muted,
                                      size: 22 * scale,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value != _password.text) {
                                      return 'Passwords do not match.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                        child: ChunkyButton(
                          key: const ValueKey('auth_submit'),
                          label: isSignUp ? 'Create account' : 'Sign in',
                          icon: isSignUp
                              ? Icons.arrow_forward_rounded
                              : Icons.login_rounded,
                          onPressed: _busy ? null : _submit,
                          busy: _busy,
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 8 * scale),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFFB7AB),
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 12 * scale,
                          right: 12 * scale,
                          bottom: 24 * scale,
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: Size(56 * scale, 56 * scale),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12 * scale,
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : isSignUp
                              ? _showSignIn
                              : _showSignUp,
                          child: Text(
                            isSignUp
                                ? 'Have an account? Sign in'
                                : 'New here? Sign up',
                            style: TextStyle(
                              color: KickoffColors.yellow,
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (!isSignUp)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12 * scale),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: Size(56 * scale, 56 * scale),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale,
                              ),
                            ),
                            onPressed: _busy ? null : widget.onGuest,
                            child: Text(
                              'Continue as guest',
                              style: TextStyle(
                                color: KickoffColors.muted,
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
