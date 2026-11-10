import 'package:flutter/material.dart';

import 'entities/user/models.dart';
import 'services/awards/local_awards.dart';
import 'services/challenge/challenge_cloud.dart';
import 'services/challenge/challenge_repository.dart';
import 'services/friends/friends_service.dart';
import 'services/match/match_controller.dart';
import 'services/stadium/stadium_api.dart';
import 'services/tournament/tournament_service.dart';
import 'services/user/user_profile_controller.dart';
import 'views/challenge/challenges_dashboard_screen.dart';
import 'views/friends/friends_screen.dart';
import 'views/home/placeholder_screen.dart';
import 'views/match/match_home_screen.dart';
import 'views/stadium/stadium_module.dart';
import 'views/tournament/tournaments_list_screen.dart';
import 'views/user/people_screen.dart';

/// Names of the module screens opened with `Navigator.pushNamed`.
///
/// Each route reads what it needs from `settings.arguments`, like the
/// "navigation with parameters" lesson: the caller passes the arguments, the
/// route builder in [appRoutes] reads them with `ModalRoute.of(context)`.
abstract final class AppRoutes {
  static const challenges = '/challenges';
  static const match = '/match';
  static const tournaments = '/tournaments';
  static const friends = '/friends';
  static const stadiums = '/stadiums';
  static const awards = '/awards';
  static const people = '/people';
}

/// Arguments of [AppRoutes.challenges].
class ChallengesArgs {
  const ChallengesArgs({
    required this.cloud,
    required this.user,
    this.isGuest = false,
  });

  final ChallengeCloud cloud;
  final UserAccount user;
  final bool isGuest;
}

/// Arguments of [AppRoutes.friends].
class FriendsArgs {
  const FriendsArgs({required this.friends, required this.user});

  final FriendsService friends;
  final UserAccount user;
}

/// Arguments of [AppRoutes.stadiums].
class StadiumsArgs {
  const StadiumsArgs({this.api, this.isGuest = false, this.onSignIn});

  final StadiumApi? api;
  final bool isGuest;
  final VoidCallback? onSignIn;
}

/// Arguments of [AppRoutes.awards].
class AwardsArgs {
  const AwardsArgs({required this.profile, this.localAwards = const []});

  final GamificationProfile? profile;
  final List<LocalAward> localAwards;
}

T _args<T>(BuildContext context) =>
    ModalRoute.of(context)!.settings.arguments! as T;

/// The `routes:` map of the app.
final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.challenges: (context) {
    final args = _args<ChallengesArgs>(context);
    return ChallengesDashboardScreen(
      repository: SqliteChallengeRepository(null, args.cloud),
      user: args.user,
      isGuest: args.isGuest,
    );
  },
  AppRoutes.match: (context) =>
      MatchHomeScreen(controller: _args<MatchController>(context)),
  AppRoutes.tournaments: (context) =>
      TournamentsListScreen(service: _args<TournamentService>(context)),
  AppRoutes.friends: (context) {
    final args = _args<FriendsArgs>(context);
    return FriendsScreen(friends: args.friends, user: args.user);
  },
  AppRoutes.stadiums: (context) {
    final args = _args<StadiumsArgs>(context);
    return StadiumModule(
      api: args.api,
      isGuest: args.isGuest,
      onSignIn: args.onSignIn,
    );
  },
  AppRoutes.awards: (context) {
    final args = _args<AwardsArgs>(context);
    return AwardsScreen(
      profile: args.profile,
      localAwards: args.localAwards,
    );
  },
  AppRoutes.people: (context) =>
      PeopleScreen(controller: _args<UserProfileController>(context)),
};
