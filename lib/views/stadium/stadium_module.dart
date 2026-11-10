// Entry point of the stadium module (opened with the `/stadiums` route).
// Models: entities/stadium/stadium.dart, API: services/stadium/stadium_api.dart.

import 'package:flutter/material.dart';

import '../../items/stadium/stadium_widgets.dart';
import '../../services/stadium/stadium_api.dart';
import 'stadium_home_screen.dart';

/// Opens the Stadium module. Guests see a sign-in prompt because every
/// stadium belongs to a real account on the API.
class StadiumModule extends StatelessWidget {
  const StadiumModule({
    this.api,
    this.isGuest = false,
    this.onSignIn,
    super.key,
  });

  final StadiumApi? api;
  final bool isGuest;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    if (!isGuest) return StadiumHomeScreen(api: api ?? StadiumApi());
    return StadiumPage(
      title: 'My stadiums',
      icon: Icons.stadium_rounded,
      child: StadiumStatusView(
        icon: Icons.lock_rounded,
        title: 'Sign in to add a stadium',
        message:
            'Stadiums, opening hours and bookings are saved to your account.',
        actionLabel: onSignIn == null ? null : 'Sign in',
        actionIcon: Icons.login_rounded,
        onAction: onSignIn == null
            ? null
            : () {
                Navigator.of(context).pop();
                onSignIn!();
              },
      ),
    );
  }
}
