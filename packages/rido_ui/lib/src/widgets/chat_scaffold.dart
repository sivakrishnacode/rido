import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:rido_data/rido_data.dart';

import '../format.dart';
import '../theme/rido_colors.dart';
import '../theme/rido_tokens.dart';
import 'rido_avatar.dart';

/// In-trip chat (P-14; the driver app uses the same screen): masked-number header,
/// an optional trip strip, message bubbles, horizontally scrolling quick replies and an input.
/// The owner keeps [messages] and appends on [onSend].
class ChatScaffold extends StatefulWidget {
  const ChatScaffold({
    super.key,
    required this.peerName,
    required this.peerInitials,
    required this.messages,
    required this.quickReplies,
    required this.onSend,
    this.onCall,
    this.stripIcon,
    this.stripText,
  });

  final String peerName;
  final String peerInitials;
  final List<ChatMessage> messages;
  final List<String> quickReplies;
  final ValueChanged<String> onSend;
  final VoidCallback? onCall;

  /// "Grey Activa · TN 37 AB 4521 · arriving in 3 min"
  final IconData? stripIcon;
  final String? stripText;

  @override
  State<ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends State<ChatScaffold> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(ChatScaffold old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final v = (text ?? _controller.text).trim();
    if (v.isEmpty) return;
    widget.onSend(v);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Scaffold(
      backgroundColor: RidoColors.background,
      appBar: AppBar(
        backgroundColor: RidoColors.surface,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Symbols.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            RidoAvatar(initials: widget.peerInitials, size: 44, tone: AvatarTone.navy),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.peerName, style: t.h2, overflow: TextOverflow.ellipsis),
                  Row(children: [
                    const Icon(Symbols.lock_rounded, size: 14, color: RidoColors.navy500),
                    const SizedBox(width: 4),
                    Flexible(child: Text('Number hidden for privacy', style: t.caption, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onCall != null)
            IconButton(
              tooltip: 'Call ${widget.peerName}',
              onPressed: widget.onCall,
              icon: const Icon(Symbols.call_rounded, fill: 1, color: RidoColors.coral600),
            ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: Column(
        children: [
          if (widget.stripText != null)
            Container(
              width: double.infinity,
              color: RidoColors.coral50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(widget.stripIcon ?? Symbols.two_wheeler_rounded, size: 20, color: RidoColors.coral600),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.stripText!, style: t.bodySmallMedium, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                Center(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Today', style: t.caption))),
                for (final m in widget.messages) _Bubble(message: m),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            color: RidoColors.surface,
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final q in widget.quickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => _send(q),
                        backgroundColor: RidoColors.coral50,
                        side: const BorderSide(color: RidoColors.coral100),
                        shape: const StadiumBorder(),
                        labelStyle: t.bodySmallMedium.copyWith(color: RidoColors.coral600, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            color: RidoColors.surface,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.paddingOf(context).bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-input'),
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(borderRadius: RidoRadii.pillRadius, borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: RidoRadii.pillRadius, borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: RidoRadii.pillRadius,
                        borderSide: BorderSide(color: RidoColors.coral600, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: RidoColors.coral600,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Send',
                    onPressed: _send,
                    icon: const Icon(Symbols.send_rounded, fill: 1, color: Colors.white),
                    constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final me = message.fromMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: me ? RidoColors.coral600 : RidoColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(message.text, style: t.body.copyWith(color: me ? Colors.white : RidoColors.navy900)),
            ),
          ),
          const SizedBox(height: 4),
          Text(me ? '${formatTime(message.sentAt)} · Seen' : formatTime(message.sentAt), style: t.caption),
        ],
      ),
    );
  }
}
