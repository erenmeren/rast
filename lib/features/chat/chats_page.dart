import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../discovery/people_directory.dart';
import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../discovery/eligibility.dart';
import '../premium/premium_notifier.dart';
import 'threads_notifier.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  bool _unreadOnly = false;

  void _open(Thread t) {
    ref.read(threadsProvider.notifier).markRead(t.id);
    context.push('/chats/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = ref.watch(visibleThreadsProvider);
    final threads = _unreadOnly ? all.where((t) => t.unread > 0).toList() : all;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(action: 'settings', premium: ref.watch(premiumProvider), onAction: () => context.go('/profile/location')),
              Semantics(header: true, child: Text('Chats', style: RastText.sectionTitle(c))),
              const SizedBox(height: 9),
              Text('Keep a good thing going.', style: rastStyle(size: 12, weight: 450, color: c.body)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
                child: Row(
                  children: [
                    _Tab(label: 'All messages', count: all.length, active: !_unreadOnly, onTap: () => setState(() => _unreadOnly = false)),
                    const SizedBox(width: 24),
                    _Tab(label: 'Unread', active: _unreadOnly, onTap: () => setState(() => _unreadOnly = true)),
                  ],
                ),
              ),
              const SizedBox(height: 21),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('YOUR CONNECTIONS', style: RastText.eyebrow(c, color: c.isDark ? c.body : const Color(0xFFAAAAB5))),
                  RastIcon('mark', size: 17, color: c.accent),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 104,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  children: [
                    for (final t in all.take(4))
                      if (ref.person(t.personId) case final p?)
                        Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Semantics(
                            button: true,
                            label: 'Open chat with ${ageLabel(p.age)} years old',
                            child: GestureDetector(
                              onTap: () => _open(t),
                              child: Column(
                                children: [
                                  Avatar(p.photo, size: 57, highlighted: true),
                                  const SizedBox(height: 8),
                                  Text('${ageLabel(p.age)} years old', style: rastStyle(size: 12, weight: 600, color: c.isDark ? c.body : const Color(0xFF777783))),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('MESSAGES', style: RastText.eyebrow(c, color: c.isDark ? c.body : const Color(0xFFAAAAB5))),
              if (threads.isEmpty)
                const EmptyState(icon: 'chat', title: 'It starts with a hello.', text: 'Your conversations will appear here.')
              else
                for (final t in threads)
                  if (ref.person(t.personId) case final p?) _Row(thread: t, person: p, onTap: () => _open(t)),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RastIcon('lock', size: 12, color: c.isDark ? c.body : const Color(0xFF81818E)),
                  const SizedBox(width: 7),
                  Text('A good conversation takes two.', style: rastStyle(size: 11, weight: 450, color: c.isDark ? c.body : const Color(0xFF81818E))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap, this.count});
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.text : (c.isDark ? const Color(0xFFAFA5B5) : const Color(0xFF7B7B87));
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? c.accent : Colors.transparent, width: 3))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: rastStyle(size: 14, weight: active ? 750 : 600, color: fg)),
              if (count != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(color: c.accentContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text('$count', style: rastStyle(size: 9, weight: 700, color: c.accent)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.thread, required this.person, required this.onTap});
  final Thread thread;
  final Person person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = thread.last;
    return Semantics(
      button: true,
      child: InkWell(
        key: Key('thread-${thread.id}'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))),
          child: Row(
            children: [
              Avatar(person.photo, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${ageLabel(person.age)} · Crossed paths', style: rastStyle(size: 15, weight: 750, color: c.isDark ? c.label : const Color(0xFF4A4A56))),
                    const SizedBox(height: 7),
                    Text(last?.text ?? 'A new match. Say hello.', maxLines: 1, overflow: TextOverflow.ellipsis, style: rastStyle(size: 13, weight: 450, color: c.isDark ? c.body : const Color(0xFF7A7A87))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(last?.time ?? 'Now', style: rastStyle(size: 10, weight: 450, color: c.isDark ? c.body : const Color(0xFF898996))),
                  if (thread.unread > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: c.isDark ? c.primary : c.accent, shape: BoxShape.circle),
                      child: Center(child: Text('${thread.unread}', style: rastStyle(size: 8, weight: 750, color: Colors.white))),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
