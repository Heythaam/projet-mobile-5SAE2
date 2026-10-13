import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../kickoff_style.dart';
import 'match_create_screens.dart';
import 'match_lobby_screen.dart';
import 'match_mock_data.dart';
import 'match_widgets.dart';

const _joinCodeLength = 5;
const _publicListPadding = EdgeInsets.all(16);
const _allowedJoinCodeCharacters = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

class MatchJoinScreen extends StatefulWidget {
  const MatchJoinScreen({required this.controller, super.key});

  final MatchDemoController controller;

  @override
  State<MatchJoinScreen> createState() => _MatchJoinScreenState();
}

class _MatchJoinScreenState extends State<MatchJoinScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  late final AnimationController _shakeController;
  int _tab = 0;
  bool _invalid = false;
  bool _joining = false;
  bool _creatingFromEmpty = false;
  Timer? _invalidTimer;

  String get _enteredCode => _codeController.text;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _codeController.addListener(_onCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tab == 0) _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _invalidTimer?.cancel();
    _shakeController.dispose();
    _codeController
      ..removeListener(_onCodeChanged)
      ..dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => Scaffold(
      backgroundColor: KickoffColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(child: _tab == 0 ? _codeTab() : _publicTab()),
            _hiddenCodeField(),
          ],
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Semantics(
            label: 'Back to Match Home',
            button: true,
            child: IconButton(
              tooltip: 'Back to Match Home',
              onPressed: _handleBack,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: KickoffColors.muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: PillToggle(selectedIndex: _tab, onChanged: _selectTab),
          ),
        ),
      ],
    ),
  );

  Widget _codeTab() => Column(
    children: [
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final shift = _shakeController.isAnimating
                ? 8 *
                      (1 - _shakeController.value) *
                      ((_shakeController.value * 32).round().isEven ? 1 : -1)
                : 0.0;
            return Transform.translate(offset: Offset(shift, 0), child: child);
          },
          child: GestureDetector(
            onTap: _codeFocusNode.requestFocus,
            child: CodeBoxes(code: _enteredCode, invalid: _invalid),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ChunkyButton(
          label: 'Join',
          icon: Icons.login_rounded,
          onPressed: !_joining && _enteredCode.length == _joinCodeLength
              ? _joinByCode
              : null,
        ),
      ),
    ],
  );

  Widget _hiddenCodeField() => SizedBox(
    width: 1,
    height: 1,
    child: Opacity(
      opacity: 0,
      child: TextField(
        controller: _codeController,
        focusNode: _codeFocusNode,
        autofocus: false,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        maxLength: _joinCodeLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) {
            final upper = newValue.text.toUpperCase();
            final filtered = upper
                .split('')
                .where(_allowedJoinCodeCharacters.contains)
                .take(_joinCodeLength)
                .join();
            return TextEditingValue(
              text: filtered,
              selection: TextSelection.collapsed(offset: filtered.length),
            );
          }),
        ],
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '',
        ),
        showCursor: false,
        onSubmitted: (_) {
          if (_enteredCode.length == _joinCodeLength) _joinByCode();
        },
      ),
    ),
  );

  Widget _publicTab() => RefreshIndicator(
    onRefresh: () async {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) setState(() {});
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _publicListPadding,
      children: [
        if (widget.controller.publicMatches.isEmpty)
          SizedBox(
            height: 240,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No public matches yet',
                  style: TextStyle(
                    color: KickoffColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _creatingFromEmpty ? null : _startCreateFromEmpty,
                  child: const Text('Create one'),
                ),
              ],
            ),
          )
        else
          for (final listing in widget.controller.publicMatches)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MatchRow(
                match: listing.match,
                timeLabel: listing.timeLabel,
                onJoin: () => _joinPublicMatch(listing.match),
              ),
            ),
      ],
    ),
  );

  void _onCodeChanged() {
    if (!mounted) return;
    setState(() {
      _invalid = false;
      _joining = false;
    });
  }

  void _selectTab(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    if (tab == 0) {
      _codeFocusNode.requestFocus();
    } else {
      _codeFocusNode.unfocus();
    }
  }

  void _handleBack() {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      _codeFocusNode.unfocus();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _joinByCode() {
    if (_joining) return;
    _joining = true;
    final found = widget.controller.findMatchByCode(_enteredCode);
    if (found == null) {
      _showInvalidCode();
      return;
    }
    if (found.players >= found.capacity &&
        !widget.controller.hasJoined(found)) {
      _joining = false;
      _showMessage('This match is full');
      return;
    }
    final joined = widget.controller.hasJoined(found)
        ? found
        : widget.controller.joinByCode(_enteredCode);
    if (joined != null) {
      _openLobby(joined);
    } else {
      _joining = false;
    }
  }

  void _joinPublicMatch(MatchHomeMatch match) {
    if (_joining) return;
    _joining = true;
    final joined = widget.controller.joinPublicMatch(match);
    if (joined != null) {
      _openLobby(joined);
    } else {
      _joining = false;
    }
  }

  Future<void> _startCreateFromEmpty() async {
    if (_creatingFromEmpty) return;
    setState(() => _creatingFromEmpty = true);
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StadiumPickScreen(controller: widget.controller),
      ),
    );
    final match = widget.controller.upcomingMatch;
    if (!mounted) return;
    setState(() => _creatingFromEmpty = false);
    if (created == true && match != null) _openLobby(match);
  }

  void _openLobby(MatchHomeMatch match) {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => MatchLobbyScreen(match: match)),
    );
  }

  void _showInvalidCode() {
    _invalidTimer?.cancel();
    setState(() => _invalid = true);
    _shakeController.forward(from: 0);
    _invalidTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _invalid = false;
          _joining = false;
        });
      }
    });
    _showMessage('No match with this code');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
