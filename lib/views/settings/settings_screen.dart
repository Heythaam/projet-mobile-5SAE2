import 'package:flutter/material.dart';

import '../../services/auth/account_service.dart';
import '../../entities/user/models.dart';
import '../../items/kickoff_style.dart';
import '../../services/security/app_lock.dart';
import '../../items/user/user_avatar.dart';
import '../../services/settings/theme_preference.dart';

/// Settings: edit profile, theme, security, profiles and log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.account,
    required this.user,
    required this.onLogout,
    this.onEditProfile,
    this.appLock,
    this.onSetAppLock,
    this.onSwitchAccount,
    this.onForgetAccount,
    this.onAddAccount,
    this.onOpenPeople,
    this.onResetProfile,
    super.key,
  });

  final AccountService account;
  final UserAccount user;
  final VoidCallback onLogout;
  final VoidCallback? onEditProfile;

  /// The lock setting and the code that turns it on or off (it asks the phone
  /// to check the player first). Without them Security says it is unavailable.
  final AppLockSettings? appLock;
  final Future<bool> Function(bool on)? onSetAppLock;

  final Future<bool> Function(String uid)? onSwitchAccount;
  final Future<void> Function(String uid)? onForgetAccount;
  final VoidCallback? onAddAccount;
  final VoidCallback? onOpenPeople;
  final VoidCallback? onResetProfile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dark = true;

  @override
  void initState() {
    super.initState();
    ThemePreference.loadDark().then((value) {
      if (mounted) setState(() => _dark = value);
    });
  }

  void _setDark(bool value) {
    setState(() => _dark = value);
    ThemePreference.saveDark(value);
  }

  void _open(Widget page) => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Settings',
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KickoffColors.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 52,
                height: 52,
                child: UserAvatarFace(
                  username: widget.user.username,
                  avatarId: 0,
                  size: 52,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${widget.user.username}',
                    key: const ValueKey('settings_account'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    widget.user.email,
                    style: const TextStyle(
                      color: KickoffColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (widget.onEditProfile != null)
        _Row(
          key: const ValueKey('settings_edit_profile'),
          icon: Icons.edit_rounded,
          title: 'Edit profile',
          onTap: widget.onEditProfile,
        ),
      _Row(
        key: const ValueKey('settings_theme'),
        icon: Icons.contrast_rounded,
        title: 'Theme',
        subtitle: _dark ? 'Dark mode' : 'Light mode',
        trailing: Switch(
          key: const ValueKey('theme_switch'),
          value: _dark,
          onChanged: _setDark,
        ),
        onTap: () => _setDark(!_dark),
      ),
      _Row(
        key: const ValueKey('settings_security'),
        icon: Icons.lock_outline_rounded,
        title: 'Security',
        subtitle: 'App lock',
        onTap: () => _open(
          SecurityScreen(
            appLock: widget.appLock,
            onSetAppLock: widget.onSetAppLock,
          ),
        ),
      ),
      _Row(
        key: const ValueKey('settings_profiles'),
        icon: Icons.switch_account_rounded,
        title: 'Profiles',
        subtitle: 'Switch or disconnect',
        onTap: () => _open(
          ProfilesScreen(
            account: widget.account,
            user: widget.user,
            onSwitchAccount: widget.onSwitchAccount,
            onForgetAccount: widget.onForgetAccount,
            onAddAccount: widget.onAddAccount,
            onOpenPeople: widget.onOpenPeople,
            onResetProfile: widget.onResetProfile,
          ),
        ),
      ),
      const SizedBox(height: 8),
      _Row(
        key: const ValueKey('settings_logout'),
        icon: Icons.logout_rounded,
        title: 'Log out',
        color: KickoffColors.red,
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
          widget.onLogout();
        },
      ),
    ],
  );
}

/// Turns the app lock on or off.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({this.appLock, this.onSetAppLock, super.key});

  final AppLockSettings? appLock;
  final Future<bool> Function(bool on)? onSetAppLock;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  @override
  Widget build(BuildContext context) {
    final lock = widget.appLock;
    final change = widget.onSetAppLock;
    return _Page(
      title: 'Security',
      children: [
        if (lock == null || change == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'App lock is not available on this phone.',
              style: TextStyle(color: KickoffColors.muted),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: KickoffColors.panel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile(
              key: const ValueKey('settings_app_lock'),
              title: const Text(
                'Lock the app',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Ask for fingerprint, face or screen lock when you open '
                'Kickoff.',
                style: TextStyle(color: KickoffColors.muted),
              ),
              value: lock.enabled,
              onChanged: (on) async {
                if (await change(on)) setState(() {});
              },
            ),
          ),
      ],
    );
  }
}

/// The profile in use, the other profiles signed in on this phone, and a way
/// to switch to one, disconnect one or add another.
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({
    required this.account,
    required this.user,
    this.onSwitchAccount,
    this.onForgetAccount,
    this.onAddAccount,
    this.onOpenPeople,
    this.onResetProfile,
    super.key,
  });

  final AccountService account;
  final UserAccount user;
  final Future<bool> Function(String uid)? onSwitchAccount;
  final Future<void> Function(String uid)? onForgetAccount;
  final VoidCallback? onAddAccount;
  final VoidCallback? onOpenPeople;
  final VoidCallback? onResetProfile;

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  List<RememberedAccount> _others = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await widget.account.rememberedAccounts();
      if (!mounted) return;
      setState(() {
        _others = all.where((a) => a.uid != widget.user.storageUid).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _switch(RememberedAccount account) async {
    final change = widget.onSwitchAccount;
    if (change == null) return;
    final ok = await change(account.uid);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _toast('Could not switch to @${account.username}.');
      await _load();
    }
  }

  Future<void> _disconnect(RememberedAccount account) async {
    final forget = widget.onForgetAccount;
    if (forget == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect @${account.username}?'),
        content: const Text(
          'You will need the password to sign in to it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await forget(account.uid);
    await _load();
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Profiles',
    children: [
      const _Label('Active profile'),
      _Row(
        key: const ValueKey('profile_active'),
        icon: Icons.check_circle_rounded,
        title: '@${widget.user.username}',
        subtitle: widget.user.email,
        color: KickoffColors.yellow,
      ),
      const _Label('Other profiles on this phone'),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_others.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            'No other profile is signed in on this phone.',
            style: TextStyle(color: KickoffColors.muted),
          ),
        )
      else
        for (final account in _others)
          _Row(
            key: ValueKey('profile_${account.uid}'),
            icon: Icons.person_rounded,
            title: '@${account.username}',
            subtitle: 'Tap to switch',
            onTap: () => _switch(account),
            trailing: IconButton(
              tooltip: 'Disconnect',
              onPressed: () => _disconnect(account),
              icon: const Icon(
                Icons.link_off_rounded,
                color: KickoffColors.muted,
              ),
            ),
          ),
      if (widget.onAddAccount != null)
        _Row(
          key: const ValueKey('profile_add'),
          icon: Icons.person_add_alt_1_rounded,
          title: 'Add another profile',
          onTap: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            widget.onAddAccount!();
          },
        ),
      const SizedBox(height: 8),
      if (widget.onOpenPeople != null)
        TextButton(
          key: const ValueKey('settings_people'),
          onPressed: widget.onOpenPeople,
          child: const Text('Profiles saved on this phone'),
        ),
      if (widget.onResetProfile != null)
        TextButton(
          key: const ValueKey('settings_reset_profile'),
          onPressed: widget.onResetProfile,
          child: const Text(
            'Reset profile on this phone',
            style: TextStyle(color: KickoffColors.orange),
          ),
        ),
    ],
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KickoffColors.bg,
    appBar: AppBar(
      backgroundColor: KickoffColors.bg,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(title),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: children,
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: KickoffColors.yellow,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: KickoffColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color ?? KickoffColors.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color == KickoffColors.red
                            ? KickoffColors.red
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: KickoffColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null && color != KickoffColors.red)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: KickoffColors.muted,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
