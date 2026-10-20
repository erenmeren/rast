import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';

enum SwipeDirection { like, pass }

/// Photo-first card. Horizontal drags like or pass; taps on the photo edges
/// page the album; a drag suppresses the tap that ends it.
class ProfileCard extends StatefulWidget {
  const ProfileCard({
    super.key,
    required this.person,
    required this.photoIndex,
    required this.onPrev,
    required this.onNext,
    required this.onMenu,
    required this.onDetail,
    required this.onSwipe,
  });

  final Person person;
  final int photoIndex;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onMenu;
  final VoidCallback onDetail;
  final void Function(SwipeDirection direction) onSwipe;

  @override
  State<ProfileCard> createState() => ProfileCardState();
}

class ProfileCardState extends State<ProfileCard> with SingleTickerProviderStateMixin {
  double _dx = 0;
  bool _dragging = false;
  bool _flying = false;
  DateTime? _suppressTapsUntil;
  late final AnimationController _fly = AnimationController(vsync: this, duration: rastPageDuration);

  static const double _commitDistance = 85;
  static const double _stampFull = 130;

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (_flying) return;
    setState(() {
      _dx += d.delta.dx;
      if (!_dragging && _dx.abs() > 12) _dragging = true;
    });
  }

  Future<void> _onEnd(DragEndDetails d) async {
    if (_flying) return;
    final dx = _dx;
    if (_dragging) _suppressTapsUntil = DateTime.now().add(const Duration(milliseconds: 350));
    if (dx.abs() > _commitDistance) {
      await flyOut(dx > 0 ? SwipeDirection.like : SwipeDirection.pass);
    } else {
      setState(() {
        _dx = 0;
        _dragging = false;
      });
    }
  }

  /// Animate off screen then report the swipe. Also used by the buttons.
  Future<void> flyOut(SwipeDirection direction) async {
    if (_flying) return;
    setState(() => _flying = true);
    final from = _dx;
    final to = (direction == SwipeDirection.like ? 1.4 : -1.4) * (context.size?.width ?? 320);
    _fly.reset();
    final tween = Tween<double>(begin: from, end: to).animate(CurvedAnimation(parent: _fly, curve: rastEase));
    void listen() => setState(() => _dx = tween.value);
    _fly.addListener(listen);
    await _fly.forward();
    _fly.removeListener(listen);
    if (!mounted) return;
    widget.onSwipe(direction);
    setState(() {
      _dx = 0;
      _dragging = false;
      _flying = false;
    });
  }

  bool get _tapsSuppressed => _suppressTapsUntil != null && DateTime.now().isBefore(_suppressTapsUntil!);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = widget.person;
    final frame = albumOf(p)[widget.photoIndex % 4];
    final progress = (_dx.abs() / _stampFull).clamp(0.0, 1.0);
    final opacity = _flying ? (1 - (_dx.abs() / 400)).clamp(0.0, 1.0) : 1.0;
    return GestureDetector(
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => setState(() {
        _dx = 0;
        _dragging = false;
      }),
      child: Transform.translate(
        offset: Offset(_dx, 0),
        child: Transform.rotate(
          angle: _dx / 23 * 3.14159 / 180,
          child: Opacity(
            opacity: opacity,
            child: Semantics(
              label: 'Fictional profile, age ${p.age}',
              child: Container(
                decoration: BoxDecoration(
                  color: c.isDark ? const Color(0xFF2D2C33) : const Color(0xFFACA499),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: c.isDark ? const Color(0x44000000) : const Color(0x0B12121A), blurRadius: 15, offset: const Offset(0, 6))],
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.scale(
                      scale: frame.zoom,
                      child: PhotoImage(frame.src, alignment: frame.alignment),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          stops: [0, 0.49, 1],
                          colors: [Color(0xCC141416), Color(0x00000000), Color(0x0A000000)],
                        ),
                      ),
                    ),
                    // Photo paging zones (outer halves, leaving the controls free).
                    Positioned(
                      left: 0,
                      top: 20,
                      bottom: 116,
                      width: constraints.maxWidth / 2,
                      child: _HitZone(key: const Key('card-prev'), label: 'Previous photo', onTap: () { if (!_tapsSuppressed) widget.onPrev(); }),
                    ),
                    Positioned(
                      right: 0,
                      top: 20,
                      bottom: 116,
                      width: constraints.maxWidth / 2,
                      child: _HitZone(key: const Key('card-next'), label: 'Next photo', onTap: () { if (!_tapsSuppressed) widget.onNext(); }),
                    ),
                    Positioned(
                      left: 11,
                      right: 11,
                      top: 10,
                      child: Semantics(
                        key: Key('photo-indicator-${widget.photoIndex % 4}'),
                        label: 'Photo ${widget.photoIndex % 4 + 1} of 4',
                        child: Row(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Expanded(
                                child: Container(
                                  height: 3,
                                  margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                                  decoration: BoxDecoration(
                                    color: i == widget.photoIndex % 4 ? Colors.white : const Color(0x4AFFFFFF),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      left: 14,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0x23131313),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: const Color(0x38FFFFFF)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const RastIcon('mark', size: 13, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Text('You crossed paths', style: rastStyle(size: 10, weight: 650, color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Profile options',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onMenu,
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                child: Container(
                                  width: 29,
                                  height: 29,
                                  decoration: const BoxDecoration(color: Color(0x22222222), shape: BoxShape.circle),
                                  child: const Center(child: RastIcon('more', size: 17, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 19,
                      bottom: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(ageLabel(p.age), style: rastStyle(size: 46, weight: 800, height: 1, letterSpacing: -1.5, color: Colors.white)),
                                    const SizedBox(width: 8),
                                    Text('years old', style: rastStyle(size: 12, weight: 500, color: const Color(0xB3FFFFFF))),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Text('A familiar stranger.', style: rastStyle(size: 18, weight: 650, height: 1.3, letterSpacing: -0.4, color: Colors.white)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const RastIcon('mark', size: 12, color: Color(0xE0FFFFFF)),
                                    const SizedBox(width: 5),
                                    Text('A real-life crossing', style: rastStyle(size: 11, weight: 450, color: const Color(0xE0FFFFFF))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'View profile',
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: widget.onDetail,
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                child: Container(
                                  width: 29,
                                  height: 29,
                                  decoration: BoxDecoration(color: const Color(0x0DFFFFFF), shape: BoxShape.circle, border: Border.all(color: const Color(0x70FFFFFF))),
                                  child: const Center(child: RastIcon('arrowUp', size: 15, color: Colors.white)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (progress > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: const Alignment(0, -0.2),
                            child: Opacity(
                              opacity: progress,
                              child: Transform.rotate(
                                angle: -10 * 3.14159 / 180,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0x40FA634F),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: _dx > 0 ? const Color(0xFFFF987E) : Colors.white, width: 3),
                                  ),
                                  child: Text(
                                    _dx > 0 ? 'LIKE' : 'PASS',
                                    style: rastStyle(size: 27, weight: 800, letterSpacing: 2, color: _dx > 0 ? const Color(0xFFFF987E) : Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                )),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HitZone extends StatelessWidget {
  const _HitZone({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap),
      );
}
