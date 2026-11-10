import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api_client.dart';
import 'auth/google_auth.dart';
import 'firebase/cloud_sync.dart';
import 'models.dart';
import 'screens/kickoff_style.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.onAuthenticated,
    this.onCancel,
    this.cloud = const NoopCloudSync(),
    this.googleAuth,
    super.key,
  });

  final ApiClient api;
  final CloudSync cloud;

  /// Shows "Continue with Google" when set.
  final GoogleAuth? googleAuth;
  final ValueChanged<UserAccount> onAuthenticated;

  /// Set when the player came here to add another account; shows a back arrow.
  final VoidCallback? onCancel;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;
  List<SavedAccount> _saved = const [];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await widget.api.savedAccounts();
      if (mounted) setState(() => _saved = saved);
    } catch (_) {}
  }

  Future<void> _continueAs(SavedAccount account) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.api.switchTo(account.id);
      if (user == null) {
        await _loadSaved();
        if (mounted) {
          setState(() => _error = 'That session expired. Please sign in.');
        }
        return;
      }
      await widget.cloud.signOut();
      if (mounted) widget.onAuthenticated(user);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not sign in: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
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

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await widget.googleAuth!.idToken();
      if (idToken == null) return; // cancelled
      final user = await widget.api.loginWithGoogle(idToken);
      await widget.cloud.signInWithGoogle(idToken);
      if (mounted) widget.onAuthenticated(user);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Google sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              email: _email.text.trim(),
              password: _password.text,
            )
          : await widget.api.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      await widget.cloud.signIn(
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
                      if (!isSignUp && widget.onCancel != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: _busy ? null : widget.onCancel,
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
                      if (widget.googleAuth != null) ...[
                        SizedBox(height: 10 * scale),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                          child: OutlinedButton.icon(
                            key: const ValueKey('auth_google'),
                            onPressed: _busy ? null : _google,
                            icon: const Icon(Icons.g_mobiledata_rounded),
                            label: const Text('Continue with Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: Size.fromHeight(52 * scale),
                              side: const BorderSide(color: Colors.white38),
                            ),
                          ),
                        ),
                      ],
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
                      if (!isSignUp)
                        for (final account in _saved)
                          TextButton(
                            key: ValueKey('continue_${account.id}'),
                            onPressed: _busy
                                ? null
                                : () => _continueAs(account),
                            child: Text(
                              'Continue as @${account.username}',
                              style: TextStyle(
                                color: KickoffColors.muted,
                                fontSize: 14 * scale,
                              ),
                            ),
                          ),
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
