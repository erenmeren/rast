import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../discovery/people_directory.dart';
import '../../core/models/models.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../safety/safety_notifier.dart';
import '../safety/sheets/person_menu_sheet.dart';
import 'threads_notifier.dart';

class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.threadId});
  final String threadId;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  StreamSubscription<String>? _failures;

  @override
  void initState() {
    super.initState();
    _failures = ref.read(threadsProvider.notifier).failures.listen((message) {
      if (mounted) showToast(context, message);
    });
  }

  @override
  void dispose() {
    _failures?.cancel();
    _composer.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (ref.read(threadsProvider.notifier).send(widget.threadId, _composer.text)) {
      _composer.clear();
      _focus.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final threads = ref.watch(threadsProvider);
    final safety = ref.watch(safetyProvider);
    Thread? thread;
    for (final t in threads) {
      if (t.id == widget.threadId) thread = t;
    }
    final person = ref.person(thread?.personId);
    if (thread == null || person == null || safety.isUnavailable(person.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/chats');
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final t = thread;
    return Scaffold(
      backgroundColor: c.conversationCanvas,
      body: SafeArea(
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: c.canvas, border: Border(bottom: BorderSide(color: c.outline))),
              child: HeaderBar(
                leading: IconCircleButton(icon: 'back', semanticLabel: 'Back to chats', background: Colors.transparent, onPressed: () => context.canPop() ? context.pop() : context.go('/chats')),
                center: Row(
                  children: [
                    Avatar(person.photo, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${person.age} · Crossed paths', style: rastStyle(size: 14, weight: 750, color: c.label)),
                          const SizedBox(height: 3),
                          Text('Your next hello.', style: rastStyle(size: 11, weight: 450, color: c.body)),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: IconCircleButton(icon: 'more', semanticLabel: 'Conversation options', background: Colors.transparent, onPressed: () => showPersonMenu(context, ref, person.id, returnTo: '/chats')),
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.l),
                children: [
                  Center(child: Text('TODAY', style: rastStyle(size: 10, weight: 700, letterSpacing: 1.3, color: c.body))),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: c.accentContainer, borderRadius: BorderRadius.circular(Radii.card)),
                          child: Center(child: RastIcon('mark', size: 22, color: c.accent)),
                        ),
                        const SizedBox(height: 12),
                        Text('Small world. Good timing.', style: rastStyle(size: 20, weight: 800, letterSpacing: -0.6, color: c.text)),
                        const SizedBox(height: 7),
                        Text('You liked each other.\nSee where a hello takes you.', textAlign: TextAlign.center, style: rastStyle(size: 12, weight: 450, height: 1.9, color: c.body)),
                      ],
                    ),
                  ),
                  for (final m in t.messages) MessageBubble(message: m),
                  if (t.messages.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Semantics(
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              _composer.text = 'Hey! How is your day going?';
                              _focus.requestFocus();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                              decoration: BoxDecoration(
                                color: c.accentContainer,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: c.isDark ? const Color(0xFF865244) : const Color(0xFFFFDACE)),
                              ),
                              child: Text('“Shall we start with a hello?”', style: rastStyle(size: 12, weight: 500, color: c.onAccentContainer)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.m),
              decoration: BoxDecoration(color: c.canvas, border: Border(top: BorderSide(color: c.outline))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: 'Your message',
                      child: TextField(
                        controller: _composer,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: maxMessageLength,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        inputFormatters: [LengthLimitingTextInputFormatter(maxMessageLength)],
                        style: rastStyle(size: 16, weight: 450, height: 1.5, color: c.text),
                        cursorColor: c.accent,
                        decoration: InputDecoration(
                          hintText: 'Say something good...',
                          hintStyle: rastStyle(size: 16, weight: 450, color: c.placeholder),
                          counterText: '',
                          filled: true,
                          fillColor: c.inputFill,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: c.inputBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: c.accent)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: c.inputBorder)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Semantics(
                    button: true,
                    label: 'Send message',
                    child: Material(
                      color: c.isDark ? c.primary : c.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _send,
                        child: const SizedBox(width: 48, height: 48, child: Center(child: RastIcon('send', size: 17, color: Colors.white))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final own = message.own;
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: own ? c.outgoingBubble : c.incomingBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(own ? 16 : 5),
            bottomRight: Radius.circular(own ? 5 : 16),
          ),
          boxShadow: own ? [BoxShadow(color: c.accent.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.text, style: rastStyle(size: 14, weight: 450, height: 1.6, color: own ? c.onOutgoingBubble : c.onIncomingBubble)),
            const SizedBox(height: 7),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message.time, style: rastStyle(size: 10, weight: 450, height: 1, color: own ? const Color(0xFFFFCFC6) : c.body)),
                if (own) ...[const SizedBox(width: 4), const RastIcon('check', size: 11, color: Color(0xFFFFCFC6))],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
