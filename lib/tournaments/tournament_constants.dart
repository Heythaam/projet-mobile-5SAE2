// The team convention (agents/code-writer.md) names constants in UPPER_SNAKE.
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

/// API paths for the Tournaments module. The base URL comes from
/// `API_BASE_URL` through `ApiClient`; only relative paths live here.
abstract final class TournamentEndpoints {
  static const LIST = '/tournaments';
  static const REQUEST_TIMEOUT = Duration(seconds: 15);

  static String detail(int id) => '$LIST/$id';

  /// POST joins and DELETE leaves.
  static String join(int id) => '$LIST/$id/join';

  /// DELETE withdraws a captain's team together with its players.
  static String disband(int id) => '${join(id)}?disband=true';
  static String transferCaptaincy(int id) => '$LIST/$id/transfer-captaincy';

  /// DELETE marks the "team disbanded" notice as seen.
  static String disbandNotice(int id) => '$LIST/$id/disband-notice';
  static String standings(int id) => '$LIST/$id/standings';
  static String bracket(int id) => '$LIST/$id/bracket';
  static String teamRequest(int id, int teamId) =>
      '$LIST/$id/teams/$teamId/request';
  static String requests(int id) => '$LIST/$id/requests';
  static String request(int id, int requestId) =>
      '$LIST/$id/requests/$requestId';
  static String team(int id, int teamId) => '$LIST/$id/teams/$teamId';
  static String member(int id, int teamId, int memberId) =>
      '$LIST/$id/teams/$teamId/members/$memberId';
  static String profile(int userId) => '/users/$userId/profile';
  static const PENDING_REQUESTS = '/me/tournament-requests';
}

/// Reason codes the API sends with some errors (`{"error", "code"}`).
abstract final class TournamentErrorCodes {
  static const TEAM_WITHDRAWN = 'team_withdrawn';
  static const NOT_CAPTAIN = 'not_captain';
  static const TRANSFER_CLOSED = 'transfer_closed';
  static const PLAYER_NOT_ON_TEAM = 'player_not_on_team';
}

/// Status colours from agents/ux-designer.md, used on the Kickoff palette
/// (AGENTS.md) so tournament screens match the rest of the app.
abstract final class TournamentColors {
  static const SUCCESS = Color(0xFF4CAF50);
  static const ERROR = Color(0xFFF44336);
  static const UPCOMING = Color(0xFF6EA8FF);
  static const FINISHED = Color(0xFF9E9E9E);

  /// Red for text on Kickoff panels; [ERROR] is too dark to read there
  /// (WCAG AA needs 4.5:1, this gives 4.6:1 on `panel`).
  static const ERROR_TEXT = Color(0xFFFF8A80);

  /// Green for text on Kickoff panels; [SUCCESS] gives only 3.8:1 on `panel`,
  /// this gives 5.2:1.
  static const SUCCESS_TEXT = Color(0xFF81C784);

  /// Destructive button fill and bottom edge, white text at 7:1.
  static const DANGER = Color(0xFFA32D2D);
  static const DANGER_EDGE = Color(0xFF6E1D1D);
}

/// Component sizes from agents/ux-designer.md, in logical pixels before
/// `kickoffScale` is applied.
abstract final class TournamentSizes {
  static const CARD_RADIUS = 12.0;
  static const CARD_PADDING = 16.0;
  static const MIN_TAP = 48.0;
  static const SCREEN_TITLE = 22.0;
  static const CARD_TITLE = 16.0;
  static const BODY = 14.0;
  static const CAPTION = 12.0;
  static const SKELETON_CARDS = 3;

  /// Up to this many detail tabs share the width; more scroll sideways.
  static const FIXED_TABS = 3;

  /// Bracket layout: card width, the gap holding connector lines, and the
  /// space between cards in the first round.
  static const BRACKET_CARD_WIDTH = 184.0;
  static const BRACKET_CONNECTOR = 28.0;
  static const BRACKET_SLOT_GAP = 12.0;
  static const BRACKET_LINE = 2.0;
  static const SHEET_RADIUS = 22.0;

  /// Tall sheets (team, profile, requests) use this share of the screen.
  static const SHEET_HEIGHT = 0.7;
  static const TEAM_NAME_MIN_LENGTH = 3;
  static const TEAM_NAME_MAX_LENGTH = 30;
}

/// User-facing copy for the Tournaments module.
abstract final class TournamentStrings {
  static const TITLE = 'Tournaments';
  static const STANDINGS = 'Standings';
  static const BRACKET = 'Bracket';
  static const EMPTY_BRACKET = 'No bracket yet';
  static const EMPTY_BRACKET_HINT =
      'The bracket appears once the draw is made.';
  static const TBD = 'TBD';
  static const BYE = 'Bye';
  static const MATCH_SCHEDULED = 'Scheduled';
  static const MATCH_NOT_SCHEDULED = 'Not scheduled';
  static const MATCH_CANCELLED = 'Cancelled';
  static const MATCH_PLAYED = 'Full time';
  static const MATCH_PENALTIES = 'Won on penalties';
  static const MATCH_ADVANCES = 'Advances';
  static const GROUP_STAGE = 'Group stage';
  static const ROUND_FINAL = 'Final';
  static const ROUND_SEMI_FINALS = 'Semi-finals';
  static const ROUND_QUARTER_FINALS = 'Quarter-finals';
  static const ROUND_OF_16 = 'Round of 16';
  static const ABOUT = 'About';
  static const TEAMS = 'Teams';
  static const BACK = 'Back';
  static const RETRY = 'Try again';
  static const SEARCH = 'Search tournaments';
  static const CLOSE_SEARCH = 'Close search';
  static const SEARCH_HINT = 'Tournament name';

  static const FILTER_ALL = 'All';
  static const STATUS_UPCOMING = 'Upcoming';
  static const STATUS_ACTIVE = 'Active';
  static const STATUS_FINISHED = 'Finished';
  static const STATUS_CANCELLED = 'Cancelled';
  static const STATUS_FULL = 'Full';

  static const FORMAT_KNOCKOUT = 'Knockout';
  static const FORMAT_LEAGUE = 'League';
  static const FORMAT_GROUPS_KNOCKOUT = 'Groups + Knockout';
  static const FORMAT_ROUND_ROBIN = 'Round robin';

  static const JOIN = 'Join tournament';
  static const JOIN_NOW = 'Join now';
  static const VIEW_DETAILS = 'View details';
  static const JOINED = 'Joined';
  static const FULL = 'Tournament full';
  static const NOT_OPEN = 'Registration closed';
  static const JOIN_SUCCESS = 'You joined the tournament.';
  static const SIGN_IN_TO_JOIN = 'Sign in again to join this tournament.';
  static const TEAM_NAME_TITLE = 'Name your team';
  static const TEAM_NAME_HINT = 'Team name';
  static const TEAM_NAME_RULES =
      "Letters, numbers, spaces and ' . _ - are allowed.";
  static const TEAM_NAME_LENGTH = 'Use 3 to 30 characters.';
  static const TEAM_NAME_CHARACTERS =
      "Use letters or numbers, plus spaces and ' . _ -";
  static const CONFIRM_JOIN = 'Join';
  static const CANCEL = 'Cancel';
  static const LEAVE = 'Leave tournament';
  static const LEAVE_TITLE = 'Leave this tournament?';
  static const CONFIRM_LEAVE = 'Leave';
  static const STAY = 'Stay';
  static const LEAVE_SUCCESS = 'You left the tournament.';
  static const SIGN_IN_TO_LEAVE = 'Sign in again to leave this tournament.';
  static const LEAVE_TEAM = 'Leave team';
  static const LEAVE_TEAM_TITLE = 'Leave your team?';
  static const LEAVE_TEAM_SUCCESS = 'You left your team.';
  static const TRANSFER_CAPTAINCY = 'Transfer captaincy';
  static const TRANSFER_HINT =
      'Pick the player who will lead the team. You stay on it as a player.';
  static const TRANSFER_EMPTY = 'No players to choose from';
  static const TRANSFER_EMPTY_HINT =
      'Only players already on your team can become captain.';
  static const DISBAND_TEAM = 'Disband team';
  static const DISBAND_TITLE = 'Disband your team?';
  static const CONFIRM_DISBAND = 'Disband';
  static const DISBAND_SUCCESS = 'Your team was disbanded.';
  static const TEAM_DISBANDED_NOTICE = 'Your team was disbanded by the captain';
  static const TEAM_DISBANDED_HINT =
      'You can join another team or create your own. Tap to dismiss.';
  static const TRANSFER_TEAM_WITHDRAWN =
      'Your team is no longer in this tournament.';
  static const TRANSFER_NOT_CAPTAIN = 'You are no longer the captain.';
  static const TRANSFER_CLOSED =
      'The tournament has started, so captaincy can no longer change.';
  static const TRANSFER_PLAYER_GONE =
      'That player is no longer on your team. Pick someone else.';
  static const SIGN_IN_AGAIN = 'Sign in again to continue.';

  static const REQUEST_TO_JOIN = 'Request to join';
  static const REQUEST_PENDING = 'Request pending ⏳';
  static const REQUEST_DECLINED = 'Declined';
  static const REQUEST_EXPIRED = 'Request expired';
  static const REQUEST_SENT = 'Request sent to the captain.';
  static const TEAM_FULL = 'Team full';
  static const YOUR_TEAM = 'Your team';
  static const TEAM_MEMBER = 'Team member';
  static const JOIN_REQUESTS = 'Join requests';
  static const JOIN_REQUESTS_EMPTY = 'No requests right now';
  static const JOIN_REQUESTS_EMPTY_HINT =
      'Players who ask to join your team show up here.';
  static const ACCEPT = 'Accept';
  static const DECLINE = 'Decline';
  static const CLOSE = 'Close';
  static const REQUEST_ACCEPTED = 'Player added to your team.';
  static const REQUEST_DECLINED_MESSAGE = 'Request declined.';
  static const REQUEST_REMOVED = 'Removed';
  static const VIEW_TEAM = 'View team';
  static const VIEW_PROFILE = 'View profile';
  static const CAPTAIN = 'Captain';
  static const PLAYERS = 'Players';
  static const TEAM_STATS = 'Team stats';
  static const STAT_PLAYERS = 'Players';
  static const STAT_TOTAL_XP = 'Total XP';
  static const STAT_AVERAGE_LEVEL = 'Avg level';
  static const STAT_POINTS = 'Points';
  static const STAT_RECORD = 'W-D-L';
  static const STAT_GOALS = 'Goals';
  static const NO_MATCHES_PLAYED = 'No matches played yet.';
  static const REMOVE_PLAYER = 'Remove player';
  static const REMOVE_PLAYER_TITLE = 'Remove this player?';
  static const CONFIRM_REMOVE = 'Remove';
  static const KEEP = 'Keep';
  static const PLAYER_REMOVED = 'Player removed from your team.';
  static const PROFILE_XP = 'XP';
  static const PROFILE_STREAK = 'Streak';
  static const PROFILE_BEST_STREAK = 'Best streak';
  static const PROFILE_ACHIEVEMENTS = 'Achievements';
  static const PROFILE_MATCHES = 'Recent matches';
  static const PROFILE_NO_ACHIEVEMENTS = 'No achievements unlocked yet.';
  static const RESULT_WIN = 'W';
  static const RESULT_DRAW = 'D';
  static const RESULT_LOSS = 'L';
  static const PENDING_REQUEST_FALLBACK = 'your pending request';

  static const EMPTY_LIST = 'No tournaments yet';
  static const EMPTY_LIST_HINT = 'New tournaments will show up here.';
  static const EMPTY_SEARCH = 'No matching tournaments';
  static const EMPTY_SEARCH_HINT = 'Try another name or filter.';
  static const EMPTY_TEAMS = 'No teams have joined yet.';
  static const EMPTY_STANDINGS = 'Standings appear once teams join.';
  static const NO_DESCRIPTION = 'No description provided.';

  static const LABEL_FORMAT = 'Format';
  static const LABEL_LOCATION = 'Location';
  static const LABEL_PRIZE = 'Prize';
  static const LABEL_TEAMS = 'Teams';
  static const LABEL_ORGANIZER = 'Organizer';

  static const COLUMN_POSITION = '#';
  static const COLUMN_TEAM = 'Team';
  static const COLUMN_PLAYED = 'P';
  static const COLUMN_WINS = 'W';
  static const COLUMN_DRAWS = 'D';
  static const COLUMN_LOSSES = 'L';
  static const COLUMN_GOAL_DIFFERENCE = 'GD';
  static const COLUMN_POINTS = 'Pts';
  static const MEDALS = ['🥇', '🥈', '🥉'];

  static const ERROR_LOAD_LIST = 'Could not load tournaments.';
  static const ERROR_LOAD_DETAIL = 'Could not load this tournament.';
  static const ERROR_LOAD_STANDINGS = 'Could not load standings.';
  static const ERROR_LOAD_BRACKET = 'Could not load the bracket.';
  static const ERROR_JOIN = 'Could not join this tournament.';
  static const ERROR_LEAVE = 'Could not leave this tournament.';
  static const ERROR_REQUEST = 'Could not send the request.';
  static const ERROR_LOAD_REQUESTS = 'Could not load join requests.';
  static const ERROR_ANSWER = 'Could not answer this request.';
  static const ERROR_LOAD_TEAM = 'Could not load this team.';
  static const ERROR_REMOVE = 'Could not remove this player.';
  static const ERROR_TRANSFER = 'Could not transfer captaincy.';
  static const ERROR_DISBAND = 'Could not disband your team.';
  static const ERROR_DISMISS_NOTICE = 'Could not dismiss this notice.';
  static const ERROR_LOAD_PROFILE = 'Could not load this profile.';
  static const ERROR_PENDING_COUNT = 'Could not load join requests.';
  static const ERROR_TIMEOUT = 'The server took too long to respond.';
  static const ERROR_INVALID_RESPONSE =
      'The server returned an unexpected tournament response.';

  static const MONTHS = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String teamsCount(int current, int max) => '$current/$max teams';

  static String roundName(int roundsFromEnd, int round) =>
      switch (roundsFromEnd) {
        0 => ROUND_FINAL,
        1 => ROUND_SEMI_FINALS,
        2 => ROUND_QUARTER_FINALS,
        3 => ROUND_OF_16,
        _ => 'Round $round',
      };

  static String groupTitle(String? group) =>
      group == null ? GROUP_STAGE : 'Group $group';

  static String shortDate(DateTime date) {
    final local = date.toLocal();
    return '${MONTHS[local.month - 1]} ${local.day}';
  }

  /// Screen-reader summary of a bracket match.
  static String bracketMatchLabel({
    required String roundName,
    required int position,
    required String home,
    required String away,
    int? homeScore,
    int? awayScore,
    String? winner,
  }) {
    final score = homeScore == null || awayScore == null
        ? '$home versus $away'
        : '$home $homeScore, $away $awayScore';
    final result = winner == null ? '' : ' $winner advances.';
    return '$roundName, match $position: $score.$result';
  }

  static String playersCount(int players, int teamSize) =>
      '$players/$teamSize players';

  static String requestSentOn(DateTime date) {
    final local = date.toLocal();
    return 'Sent ${MONTHS[local.month - 1]} ${local.day}';
  }

  /// Large counts are capped so badges keep their size.
  static String requestsBadge(int count) =>
      count > MAX_BADGE_COUNT ? '$MAX_BADGE_COUNT+' : '$count';
  static const MAX_BADGE_COUNT = 9;

  static String pendingRequestsLabel(int count) =>
      count == 1 ? '1 request' : '${requestsBadge(count)} requests';

  static String homeRequestsTitle(int count) => count == 1
      ? '1 join request waiting'
      : '${requestsBadge(count)} join requests waiting';
  static const HOME_REQUESTS_HINT = 'Players want to join your team.';
  static const OPEN_TOURNAMENTS = 'Open';

  static String cancelPendingWarning(String? teamName) =>
      'This will cancel ${teamName == null ? PENDING_REQUEST_FALLBACK : 'your pending request to $teamName'}. Continue?';

  static String captainLine(String name) => '$CAPTAIN: $name';

  static String playerLine(int level, int xp, int streak) =>
      'Lv $level · $xp XP · 🔥 $streak';

  static String confirmRemoveMessage(String player, String team) =>
      '$player will leave $team and cannot ask to join it again.';

  static String profileRank(String rank, int level) => '$rank · Level $level';

  static String matchScore(int goalsFor, int goalsAgainst) =>
      '$goalsFor – $goalsAgainst';

  static String matchOpponent(
    String opponent,
    String tournament,
    DateTime? playedAt,
  ) {
    final line = 'vs $opponent · $tournament';
    if (playedAt == null) return line;
    final local = playedAt.toLocal();
    return '$line · ${MONTHS[local.month - 1]} ${local.day}';
  }

  static String joinRequestsLabel(int count) =>
      '$JOIN_REQUESTS: $count pending';

  static String confirmJoinMessage(String name) =>
      'You will captain this team in $name. Other teams will see its name.';

  static String confirmLeaveTeamMessage(String team) =>
      'You will leave $team. You can ask a team to take you while '
      'registration is open.';

  static String confirmDisbandMessage(String team, int players) =>
      'All ${players == 1 ? '1 player' : '$players players'} will be '
      'removed and $team withdrawn from the tournament. This cannot be undone.';

  static String makeCaptain(String player) => 'Make $player captain';

  static String transferSuccess(String player) => '$player is now the captain.';

  static String confirmLeaveMessage(String name) =>
      'Your team will be removed from $name and its spot freed. '
      'You can join again while registration is open.';

  static String teamNameCounter(int length) =>
      '$length/${TournamentSizes.TEAM_NAME_MAX_LENGTH}';

  static String dateRange(DateTime start, DateTime end) {
    String day(DateTime date) => '${MONTHS[date.month - 1]} ${date.day}';
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    if (localStart.year == localEnd.year &&
        localStart.month == localEnd.month &&
        localStart.day == localEnd.day) {
      return '${day(localStart)}, ${localStart.year}';
    }
    return '${day(localStart)} – ${day(localEnd)}, ${localEnd.year}';
  }
}
