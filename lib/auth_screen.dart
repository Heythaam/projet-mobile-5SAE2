import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';

const _ink = Color(0xFF12251D);
const _pitch = Color(0xFF164A35);
const _lime = Color(0xFFD6F36A);
const _paper = Color(0xFFF7F7F1);
const _muted = Color(0xFF78827A);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.onAuthenticated,
    super.key,
  });

  final ApiClient api;
  final ValueChanged<UserAccount> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _PitchHeader(registering: _registering),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _registering ? 'Get in the game.' : 'You’re up.',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _registering
                                ? 'Create your player profile to meet your team.'
                                : 'Pick up where your team left off.',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 23),
                          if (_registering) ...[
                            _fieldLabel('PLAYER NAME'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _username,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.none,
                              decoration: _fieldDecoration(
                                'e.g. alex_striker',
                                Icons.alternate_email_rounded,
                              ),
                              validator: (value) {
                                final username = value?.trim() ?? '';
                                if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$')
                                    .hasMatch(username)) {
                                  return 'Use 3-20 letters, numbers, or underscores.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                          ],
                          _fieldLabel('EMAIL ADDRESS'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: _fieldDecoration(
                              'you@example.com',
                              Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),
                          _fieldLabel('PASSWORD'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: _fieldDecoration(
                              _registering
                                  ? 'At least 8 characters'
                                  : 'Your password',
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                color: _muted,
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (_registering && password.length < 8) {
                                return 'Use at least 8 characters.';
                              }
                              if (password.isEmpty) {
                                return 'Enter your password.';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 13),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECE8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFAD382C),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _ink,
                                foregroundColor: _lime,
                                disabledBackgroundColor: _ink.withValues(
                                  alpha: 0.6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      height: 21,
                                      width: 21,
                                      child: CircularProgressIndicator(
                                        color: _lime,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _registering
                                              ? 'Create my profile'
                                              : 'Sign in',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _registering = !_registering;
                                      _error = null;
                                    }),
                              style: TextButton.styleFrom(
                                foregroundColor: _pitch,
                              ),
                              child: Text(
                                _registering
                                    ? 'Already on the team? Sign in'
                                    : 'New to the team? Create an account',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }

  static Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _muted,
      fontSize: 10,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w800,
    ),
  );

  static InputDecoration _fieldDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA5ADA6), fontSize: 14),
        prefixIcon: Icon(icon, color: _pitch, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE6E9E2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE6E9E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _pitch, width: 1.5),
        ),
      );
}

class _PitchHeader extends StatelessWidget {
  const _PitchHeader({required this.registering});

  final bool registering;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 270,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B6042), Color(0xFF0D2B20)],
            ),
          ),
        ),
        const CustomPaint(painter: _StadiumPainter()),
        Positioned(
          top: 21,
          left: 24,
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: _ink,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'KICKOFF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _lime,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  registering ? 'YOUR NEXT TEAM' : 'MATCHDAY READY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 26,
          bottom: 25,
          right: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                registering ? 'YOUR PEOPLE.' : 'THE GAME',
                style: const TextStyle(
                  color: _lime,
                  fontSize: 11,
                  letterSpacing: 3.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                registering ? 'YOUR PITCH.' : 'IS BETTER',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 43,
                  height: 0.99,
                  letterSpacing: -2.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                registering ? 'START HERE.' : 'TOGETHER.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 43,
                  height: 0.99,
                  letterSpacing: -2.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 28,
          bottom: 44,
          child: Transform.rotate(
            angle: -0.18,
            child: const Icon(
              Icons.sports_soccer_rounded,
              size: 51,
              color: _lime,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StadiumPainter extends CustomPainter {
  const _StadiumPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          _lime.withValues(alpha: 0.14),
          _lime.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.83, size.height * 0.45),
          radius: 120,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.45),
      120,
      glow,
    );

    final field = Rect.fromLTWH(
      size.width * 0.38,
      size.height * 0.31,
      size.width * 0.78,
      size.height * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(20)),
      line,
    );
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      line,
    );
    canvas.drawCircle(field.center, 38, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(field.left, field.center.dy),
        width: 70,
        height: 115,
      ),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.44),
      3,
      Paint()..color = _lime.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
