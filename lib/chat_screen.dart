import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.api,
    required this.currentUser,
    required this.friend,
    super.key,
  });

  final ApiClient api;
  final UserAccount currentUser;
  final Friend friend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _ink = Color(0xFF10112F);
  static const _lime = Color(0xFFFFD21E);
  static const _night = Color(0xFF17194F);
  static const _nightPanel = Color(0xFF3D4B70);
  static const _nightRaised = Color(0xFF0866F5);
  static const _nightText = Color(0xFFEAF0E8);
  static const _nightMuted = Color(0xFFCDD8F0);

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  Timer? _pollTimer;
  int _lastMessageId = 0;
  bool _loading = true;
  bool _sending = false;
  bool _fetching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final messages = await widget.api.getMessages(
        widget.friend.id,
        after: _lastMessageId,
      );
      if (!mounted) return;
      if (messages.isNotEmpty) {
        setState(() {
          _messages.addAll(messages);
          _lastMessageId = messages.last.id;
          _loading = false;
          _error = null;
        });
        _scrollToLatest();
      } else if (_loading) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    } finally {
      _fetching = false;
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await widget.api.sendMessage(widget.friend.id, body);
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _lastMessageId = message.id;
        _controller.clear();
      });
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _night,
    appBar: AppBar(
      backgroundColor: _nightPanel,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            height: 39,
            width: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _nightRaised,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _ink, width: 2),
            ),
            child: Text(
              widget.friend.username[0].toUpperCase(),
              style: const TextStyle(color: _lime, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.friend.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Row(
                children: [
                  Icon(Icons.circle, size: 6, color: _lime),
                  SizedBox(width: 5),
                  Text(
                    'ON YOUR TEAM',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Expanded(child: _messageList()),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            decoration: const BoxDecoration(
              color: _nightPanel,
              border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Message your teammate…',
                      hintStyle: const TextStyle(
                        color: _nightMuted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: _nightRaised,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: _ink, width: 2),
                      ),
                      counterText: '',
                    ),
                    style: const TextStyle(color: _nightText),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: IconButton(
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(
                      backgroundColor: _lime,
                      foregroundColor: _night,
                      side: const BorderSide(color: _ink, width: 2),
                      disabledBackgroundColor: _lime.withValues(alpha: 0.5),
                    ),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: _night,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _messageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _lime));
    }
    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _nightText),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadMessages,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _ChatPitchPainter())),
        if (_messages.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 76,
                    width: 76,
                    decoration: BoxDecoration(
                      color: _nightRaised,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: _ink, width: 3),
                    ),
                    child: const Icon(
                      Icons.sports_soccer_rounded,
                      color: _lime,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'First words.\nFuture match stories.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _nightText,
                      fontSize: 23,
                      height: 1.15,
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You and @${widget.friend.username} are on the same team. Say hello.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _nightMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isMine = message.senderId == widget.currentUser.id;
              return Align(
                alignment: isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  margin: const EdgeInsets.only(bottom: 11),
                  padding: const EdgeInsets.fromLTRB(15, 11, 15, 9),
                  decoration: BoxDecoration(
                    color: isMine ? _lime : _nightPanel,
                    border: Border.all(color: _ink, width: 2),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMine ? 14 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ink.withValues(alpha: 0.035),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        message.body,
                        style: TextStyle(
                          color: isMine ? _night : _nightText,
                          height: 1.35,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _messageTime(message.sentAt),
                        style: TextStyle(
                          color: isMine
                              ? _night.withValues(alpha: 0.6)
                              : _nightMuted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  String _messageTime(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ChatPitchPainter extends CustomPainter {
  const _ChatPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final field = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.16,
      size.width * 0.64,
      size.height * 0.68,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(24)),
      paint,
    );
    canvas.drawLine(
      Offset(field.center.dx, field.top),
      Offset(field.center.dx, field.bottom),
      paint,
    );
    canvas.drawCircle(field.center, 40, paint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(field.left, field.center.dy),
        width: 55,
        height: 110,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(field.right, field.center.dy),
        width: 55,
        height: 110,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
