import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/person.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import 'story_controller.dart';
import 'story_model.dart';
import 'story_palette.dart';

/// The 1:1 illustrated city with every overlay layer. Pure presentation.
class StoryScene extends StatelessWidget {
  const StoryScene({super.key, required this.controller});
  final StoryController controller;

  @override
  Widget build(BuildContext context) {
    final p = StoryPalette.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final f = controller.displayFrame;
        final stage = controller.frame.stage;
        final t = f.time;
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, 338.0);
            final scale = side / 360;
            return Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    color: p.sceneBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: p.sceneBorder),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: 1 - 0.91 * during(t, 10200, 11000),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            RepaintBoundary(child: CustomPaint(painter: _WorldPainter(p, scale))),
                            CustomPaint(painter: _ActorsPainter(p, scale, f)),
                          ],
                        ),
                      ),
                      _SceneTag(stage: stage, palette: p),
                      _Layer(
                        opacity: 1 - during(t, 10200, 10600),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 13),
                            child: Text('AN ILLUSTRATED CROSSING · NOT A LIVE MAP',
                                textAlign: TextAlign.center,
                                style: rastStyle(size: 8, weight: 650, letterSpacing: 0.8, height: 1.3, color: p.isDarkPalette ? const Color(0xFFB7A894) : const Color(0xFF8A8379))),
                          ),
                        ),
                      ),
                      _Layer(
                        opacity: (f.crossed ? 1 : 0) * (1 - during(t, 6400, 6900)),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 41),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                              decoration: BoxDecoration(
                                color: p.isDarkPalette ? const Color(0xF5382720) : const Color(0xF5FFFAF2),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: p.isDarkPalette ? const Color(0xFF8B5A43) : Colors.white),
                                boxShadow: const [BoxShadow(color: Color(0x186E5138), blurRadius: 18, offset: Offset(0, 5))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RastIcon('mark', size: 17, color: p.coral),
                                  const SizedBox(width: 8),
                                  Text('Your paths just crossed.', style: rastStyle(size: 12, weight: 750, color: p.isDarkPalette ? const Color(0xFFFFCEB0) : const Color(0xFF8A4D36))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _Layer(
                        opacity: during(t, 6500, 7100) * (1 - during(t, 10300, 10600)),
                        child: _FitOverlay(p),
                      ),
                      _Layer(
                        opacity: during(t, 10600, 11100) * (1 - during(t, 15900, 16400)),
                        child: _WaitLayer(p, f),
                      ),
                      _Layer(
                        opacity: during(t, 16400, 17100) * (1 - during(t, 21200, 21800)),
                        child: _DiscoverLayer(p, lift: 1 - during(t, 16400, 17400)),
                      ),
                      _Layer(
                        opacity: during(t, 21300, 22000),
                        child: _HelloLayer(p, yourLike: during(t, 22400, 22900), theirLike: during(t, 23600, 24100), message: during(t, 24800, 25600)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

extension on StoryPalette {
  bool get isDarkPalette => paper == StoryPalette.dark.paper;
}

class _Layer extends StatelessWidget {
  const _Layer({required this.opacity, required this.child});
  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final o = bounded(opacity);
    if (o <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(child: Opacity(opacity: o, child: child));
  }
}

class _SceneTag extends StatelessWidget {
  const _SceneTag({required this.stage, required this.palette});
  final int stage;
  final StoryPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Positioned(
      top: 16,
      left: 16,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.isDarkPalette ? const Color(0xF226221F) : const Color(0xEDFCFAF6),
                border: Border.all(color: p.isDarkPalette ? const Color(0xFF645041) : const Color(0xFFDDD4C8)),
              ),
              child: Center(child: Text((stage + 1).toString().padLeft(2, '0'), style: rastStyle(size: 10, weight: 800, color: p.isDarkPalette ? const Color(0xFFE8C6A9) : const Color(0xFF6D5B4A)))),
            ),
            const SizedBox(width: 8),
            Text(howSteps[stage].scene, style: rastStyle(size: 9, weight: 750, letterSpacing: 1, color: p.isDarkPalette ? const Color(0xFFC7B5A3) : const Color(0xFF756E65))),
          ],
        ),
      ),
    );
  }
}

class _FitOverlay extends StatelessWidget {
  const _FitOverlay(this.p);
  final StoryPalette p;

  Widget _check(String text, double shift) => Transform.translate(
        offset: Offset(shift, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: p.isDarkPalette ? const Color(0xF7302821) : const Color(0xF7FFFCF7),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: p.isDarkPalette ? const Color(0xFF625248) : const Color(0xFFF9F6EF)),
            boxShadow: const [BoxShadow(color: Color(0x15685641), blurRadius: 16, offset: Offset(0, 5))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: p.checkBg, shape: BoxShape.circle),
                child: Center(child: RastIcon('check', size: 14, color: p.checkFg)),
              ),
              const SizedBox(width: 9),
              Text(text, style: rastStyle(size: 12, weight: 700, color: p.isDarkPalette ? const Color(0xFFEAD3BC) : const Color(0xFF514941))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.54, 1],
          colors: [Colors.transparent, p.isDarkPalette ? const Color(0x88202125) : const Color(0x88F2EFEA)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 39),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _check('You fit their preferences', -22),
          const SizedBox(height: 8),
          _check('They fit yours', 28),
        ],
      ),
    );
  }
}

class _WaitLayer extends StatelessWidget {
  const _WaitLayer(this.p, this.f);
  final StoryPalette p;
  final HowFrame f;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 45, 15, 17),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('A LITTLE TIME FOR PRIVACY', style: rastStyle(size: 9, weight: 800, letterSpacing: 1.35, color: p.kicker)),
          const SizedBox(height: 7),
          SizedBox(
            width: 158,
            height: 158,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _ClockPainter(p, f.wait)),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RastIcon('lock', size: 17, color: p.isDarkPalette ? const Color(0xFFD0B7A6) : const Color(0xFFD0B7A6)),
                    const SizedBox(height: 6),
                    Text(minuteClock(f.remaining), style: rastStyle(size: 34, weight: 650, letterSpacing: -1.2, height: 1, color: p.clockText).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(height: 8),
                    Text('HOURS : MINUTES', style: rastStyle(size: 7, weight: 650, letterSpacing: 1.1, color: p.clockSub)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _delayChip('You', '1h', longer: false),
              const SizedBox(width: 11),
              RastIcon('arrow', size: 17, color: p.isDarkPalette ? const Color(0xFFBE9874) : const Color(0xFFAA9784)),
              const SizedBox(width: 11),
              _delayChip('Them', '2h', longer: true),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RastIcon('clock', size: 12, color: p.isDarkPalette ? const Color(0xFFC3AB92) : const Color(0xFF8A8176)),
              const SizedBox(width: 5),
              Text('Time fast-forwarded · 2h is the default', style: rastStyle(size: 9, weight: 450, color: p.isDarkPalette ? const Color(0xFFC3AB92) : const Color(0xFF8A8176))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _delayChip(String who, String hours, {required bool longer}) {
    final dark = p.isDarkPalette;
    final border = longer ? (dark ? const Color(0xFFBA7851) : const Color(0xFFE5B49C)) : (dark ? const Color(0xFF625142) : const Color(0xFFDFD8CE));
    final bg = longer ? (dark ? const Color(0xFF4A3022) : const Color(0xFFFBE5D8)) : (dark ? const Color(0xFF2E2822) : const Color(0xFFFFFCF6));
    final fg = longer ? (dark ? const Color(0xFFEEBC96) : const Color(0xFF905E45)) : (dark ? const Color(0xFFC9B397) : const Color(0xFF7C7267));
    final strong = longer ? (dark ? const Color(0xFFFFD0A5) : const Color(0xFFA85232)) : (dark ? const Color(0xFFECD2B4) : const Color(0xFF585148));
    return Container(
      constraints: const BoxConstraints(minHeight: 31),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(who, style: rastStyle(size: 11, weight: 450, color: fg)),
          const SizedBox(width: 12),
          Text(hours, style: rastStyle(size: 13, weight: 800, color: strong)),
        ],
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter(this.p, this.wait);
  final StoryPalette p;
  final double wait;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 70 / 160;
    canvas.drawCircle(c + const Offset(0, 9), r, Paint()..color = const Color(0x0D30291F)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(c, r, Paint()..color = p.clockFace);
    canvas.drawCircle(c, r, Paint()..color = p.clockTrack..style = PaintingStyle.stroke..strokeWidth = 4);
    final sweep = 2 * math.pi * (1 - wait);
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        sweep,
        false,
        Paint()..color = p.clockProgress..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(c, size.width * 57 / 160, Paint()..color = p.clockFace);
    canvas.drawCircle(c, size.width * 57 / 160, Paint()..color = const Color(0x13FFFFFF)..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.wait != wait || old.p != p;
}

class _DiscoverLayer extends StatelessWidget {
  const _DiscoverLayer(this.p, {required this.lift});
  final StoryPalette p;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final dark = p.isDarkPalette;
    Widget paper(double angle, Offset shift, Color bg, Color border, int z) => Transform.translate(
          offset: shift,
          child: Transform.rotate(
            angle: angle * math.pi / 180,
            child: Container(
              width: 157,
              height: 208,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(17), border: Border.all(color: border, width: 3)),
            ),
          ),
        );
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                paper(-9, const Offset(-9, 1), dark ? const Color(0xFF42352A) : const Color(0xFFDDD0C0), dark ? const Color(0xFF6A5542) : const Color(0xFFFFF9EF), 1),
                paper(7, const Offset(9, 0), dark ? const Color(0xFF61412F) : const Color(0xFFF4DFCD), dark ? const Color(0xFF9C6E4D) : const Color(0xFFFFF9EF), 2),
                Transform.translate(
                  offset: Offset(0, 38 / 2 + lift * 40),
                  child: Transform.rotate(
                    angle: lift * -6 * math.pi / 180,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 157,
                      height: 208,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: dark ? const Color(0xFFA78667) : Colors.white, width: 4),
                        boxShadow: const [BoxShadow(color: Color(0x23574230), blurRadius: 25, offset: Offset(0, 15))],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PhotoImage(portrait(1), alignment: const Alignment(0, -0.2)),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0, 0.3, 0.47, 1],
                                colors: [Color(0x22000000), Color(0x00000000), Color(0x00000000), Color(0xC9161719)],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 7,
                            left: 8,
                            right: 8,
                            child: Row(
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      margin: EdgeInsets.only(left: i == 0 ? 0 : 3),
                                      decoration: BoxDecoration(color: i == 0 ? Colors.white : const Color(0x70FFFFFF), borderRadius: BorderRadius.circular(2)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 13,
                            right: 10,
                            bottom: 15,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('27', style: rastStyle(size: 26, weight: 800, height: 1, letterSpacing: -0.8, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('You crossed paths.', style: rastStyle(size: 9, weight: 550, color: const Color(0xD9FFFFFF))),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 11,
                            bottom: 26,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(color: Color(0xFFF27257), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))]),
                              child: const Center(child: RastIcon('heart', size: 16, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 54,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(color: p.pillBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.pillBorder)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RastIcon('check', size: 13, color: dark ? const Color(0xFFEFBA8B) : const Color(0xFF9B6B47)),
                  const SizedBox(width: 6),
                  Text('Ready in Discover', style: rastStyle(size: 10, weight: 750, color: p.pillFg)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HelloLayer extends StatelessWidget {
  const _HelloLayer(this.p, {required this.yourLike, required this.theirLike, required this.message});
  final StoryPalette p;
  final double yourLike;
  final double theirLike;
  final double message;

  Widget _person(String src, double angle, {required double like, required bool other}) {
    final dark = p.isDarkPalette;
    return SizedBox(
      width: 100,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: angle * math.pi / 180,
            child: Container(
              width: 88,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(46), bottom: Radius.circular(31)),
                border: Border.all(color: dark ? const Color(0xFFA88867) : const Color(0xFFFFFAF5), width: 4),
                boxShadow: const [BoxShadow(color: Color(0x2078614A), blurRadius: 19, offset: Offset(0, 8))],
              ),
              clipBehavior: Clip.antiAlias,
              child: PhotoImage(src, alignment: const Alignment(0, -0.3)),
            ),
          ),
          Positioned(
            right: other ? null : -4,
            left: other ? -4 : null,
            bottom: 0,
            child: Opacity(
              opacity: bounded(like),
              child: Transform.rotate(
                angle: (other ? 8 : -8) * math.pi / 180,
                child: Transform.scale(
                  scale: 0.7 + 0.3 * bounded(like),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: other ? p.stampOther : const Color(0xFFE87053),
                      shape: BoxShape.circle,
                      border: Border.all(color: dark ? const Color(0xFF30231B) : const Color(0xFFFFF9F1), width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x269F5C34), blurRadius: 9, offset: Offset(0, 4))],
                    ),
                    child: const Center(child: RastIcon('heart', size: 17, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = p.isDarkPalette;
    final captionColor = dark ? const Color(0xFFE1BA91) : const Color(0xFF8B6550);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 52, 18, 17),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('YOUR MOVE. THEIR MOVE.', style: rastStyle(size: 9, weight: 800, letterSpacing: 1.35, color: p.kicker)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _person(portrait(7), -7, like: yourLike, other: false),
              const SizedBox(width: 10),
              _person(portrait(1), 7, like: theirLike, other: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 100, child: Opacity(opacity: 0.3 + 0.7 * bounded(yourLike), child: Text('Your like', textAlign: TextAlign.center, style: rastStyle(size: 12, weight: 750, color: captionColor)))),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: Opacity(opacity: 0.3 + 0.7 * bounded(theirLike), child: Text('Their like', textAlign: TextAlign.center, style: rastStyle(size: 12, weight: 750, color: captionColor)))),
            ],
          ),
          const SizedBox(height: 20),
          Opacity(
            opacity: bounded(message),
            child: Transform.translate(
              offset: Offset(0, (1 - bounded(message)) * 15),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 284),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: p.cardBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: p.cardBorder),
                  boxShadow: const [BoxShadow(color: Color(0x166B5134), blurRadius: 19, offset: Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    ClipOval(child: SizedBox(width: 33, height: 33, child: PhotoImage(portrait(1), alignment: const Alignment(0, -0.3)))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR NEXT HELLO', maxLines: 1, overflow: TextOverflow.ellipsis, style: rastStyle(size: 7, weight: 800, letterSpacing: 0.9, color: p.cardMuted)),
                          const SizedBox(height: 4),
                          Text('Hey. Coffee sometime?', maxLines: 1, overflow: TextOverflow.ellipsis, style: rastStyle(size: 12, weight: 650, height: 1.2, color: p.cardText)),
                        ],
                      ),
                    ),
                    RastIcon('chat', size: 19, color: dark ? const Color(0xFFEBB784) : const Color(0xFFBD7B58)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Path _svgPath(String d) => parseSvgPathData(d);

/// Static city: blocks, buildings, roads, park. Painted once.
class _WorldPainter extends CustomPainter {
  const _WorldPainter(this.p, this.scale);
  final StoryPalette p;
  final double scale;

  static final List<Path> _blocks = [
    'M-12 18H161Q175 18 175 32V124Q175 137 160 137H91L-12 108Z',
    'M278 -12H377V144H268Q257 144 259 126Z',
    'M-15 303 139 263Q152 260 156 274L174 378H-15Z',
    'M260 247 378 211V376H263Q250 376 250 362V263Q250 250 260 247Z',
  ].map(_svgPath).toList();
  static final List<Path> _buildings = [
    'M13 36h49v42h-49z',
    'M74 35h81v64h-81z',
    'M282 14h62v42h-62z',
    'M280 69h58v48h-58z',
    'm280 272 55-16 12 48-58 11Z',
    'm19 318 48-13 10 44-46 12Z',
  ].map(_svgPath).toList();
  static final Path _road1 = _svgPath('M-28 250C63 258 113 208 173 210S285 190 389 146');
  static final Path _road2 = _svgPath('M236-28C259 79 207 116 216 205S202 310 210 389');
  static final Path _crosswalk1 = _svgPath('M183 97h54m-54 8h52m-54 8h52m-53 8h51');
  static final Path _crosswalk2 = _svgPath('m281 163 14 42m-5-46 14 42m-5-47 14 43m-5-47 14 43');
  static final Path _park = _svgPath('M20 126 124 153Q146 159 140 174L91 192Q45 208 18 192Z');

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 360, 360), Paint()..color = p.sceneBg);
    final grain = Paint()..color = p.grain.withValues(alpha: 0.35);
    for (var y = 1.0; y < 360; y += 9) {
      for (var x = 1.0; x < 360; x += 9) {
        canvas.drawCircle(Offset(x, y), 0.65, grain);
      }
    }
    final blockFill = Paint()..color = p.block;
    final blockStroke = Paint()..color = p.blockStroke..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final b in _blocks) {
      canvas.drawPath(b, blockFill);
      canvas.drawPath(b, blockStroke);
    }
    final bFill = Paint()..color = p.building;
    final bStroke = Paint()..color = p.buildingStroke..style = PaintingStyle.stroke..strokeWidth = 1;
    for (var i = 0; i < _buildings.length; i++) {
      final path = i < 4 ? (Path()..addRRect(RRect.fromRectAndRadius(_buildings[i].getBounds(), const Radius.circular(5)))) : _buildings[i];
      canvas.drawPath(path, bFill);
      canvas.drawPath(path, bStroke);
    }
    canvas.drawPath(_road1, Paint()..color = p.road..style = PaintingStyle.stroke..strokeWidth = 64);
    canvas.drawPath(_road2, Paint()..color = p.road..style = PaintingStyle.stroke..strokeWidth = 58);
    final dashed = Paint()..color = p.roadLine..style = PaintingStyle.stroke..strokeWidth = 1.5;
    _drawDashed(canvas, _road1, dashed, 4, 9);
    _drawDashed(canvas, _road2, dashed, 4, 9);
    final cross = Paint()..color = p.crosswalk.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 5;
    canvas.drawPath(_crosswalk1, cross);
    canvas.drawPath(_crosswalk2, cross);
    canvas.drawPath(_park, Paint()..color = p.park);
    final tree = Paint()..color = p.tree;
    final treeStroke = Paint()..color = p.treeStroke..style = PaintingStyle.stroke..strokeWidth = 1;
    for (final (cx, cy, r) in [(33.0, 159.0, 12.0), (68.0, 170.0, 10.0), (108.0, 163.0, 9.0), (308.0, 339.0, 12.0), (326.0, 324.0, 9.0)]) {
      canvas.drawCircle(Offset(cx, cy), r, tree);
      canvas.drawCircle(Offset(cx, cy), r, treeStroke);
    }
    final bench = Paint()..color = p.bench;
    for (final (x, y, deg) in [(86.0, 133.0, 16.0), (281.0, 232.0, -15.0)]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(deg * math.pi / 180);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 18, 4), const Radius.circular(2)), bench);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) => old.p != p || old.scale != scale;
}

void _drawDashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
      d += dash + gap;
    }
  }
}

/// Radius circle, connection line and the two people. Repaints per frame.
class _ActorsPainter extends CustomPainter {
  const _ActorsPainter(this.p, this.scale, this.f);
  final StoryPalette p;
  final double scale;
  final HowFrame f;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    final a = f.a;
    final b = f.b;
    canvas.drawCircle(a, 80, Paint()..color = p.radiusFill.withValues(alpha: f.crossed ? 0.14 : 0.095));
    _drawDashed(canvas, Path()..addOval(Rect.fromCircle(center: a, radius: 80)), Paint()..color = p.radiusLine..style = PaintingStyle.stroke..strokeWidth = 1.4, 4, 5);
    _drawDashed(canvas, Path()..moveTo(a.dx, a.dy)..lineTo(a.dx + 80, a.dy), Paint()..color = p.radiusMeasure..style = PaintingStyle.stroke..strokeWidth = 1, 2, 3);
    _text(canvas, '20 m', a + const Offset(43, -7), 10, 750, p.radiusText, TextAlign.left);
    if (f.crossed) {
      _drawDashed(canvas, Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), Paint()..color = p.connection..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round, 3, 4);
    }
    _person(canvas, a, p.personA, 'You', 40, p.personALabelBg, p.personALabelFg);
    _person(canvas, b, p.personB, 'Someone', 68, p.personBLabelBg, p.personBLabelFg);
  }

  void _person(Canvas canvas, Offset c, Color body, String label, double labelWidth, Color labelBg, Color labelFg) {
    canvas.drawCircle(c + const Offset(0, 4), 23, Paint()..color = const Color(0x26343038)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(c, 23, Paint()..color = Colors.white);
    canvas.drawCircle(c, 19.5, Paint()..color = body);
    canvas.drawCircle(c + const Offset(0, -5), 5.5, Paint()..color = Colors.white);
    final shoulders = Path()
      ..moveTo(c.dx - 10, c.dy + 12)
      ..arcToPoint(Offset(c.dx + 10, c.dy + 12), radius: const Radius.circular(10));
    canvas.drawPath(shoulders, Paint()..color = Colors.white);
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(c.dx - labelWidth / 2, c.dy + 30, labelWidth, 21), const Radius.circular(10.5));
    canvas.drawRRect(rect, Paint()..color = labelBg);
    _text(canvas, label, Offset(c.dx, c.dy + 44), 10, 700, labelFg, TextAlign.center);
  }

  void _text(Canvas canvas, String s, Offset baseline, double size, int weight, Color color, TextAlign align) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: rastStyle(size: size, weight: weight, color: color, height: 1)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = align == TextAlign.center ? baseline.dx - tp.width / 2 : baseline.dx;
    tp.paint(canvas, Offset(dx, baseline.dy - tp.height * 0.8));
  }

  @override
  bool shouldRepaint(_ActorsPainter old) => old.f.time != f.time || old.p != p || old.scale != scale;
}

/// Minimal SVG path parser for the commands used by the story
/// (M, L, H, V, C, S, Q, Z and their relative forms).
Path parseSvgPathData(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsQqZz]|-?\d*\.?\d+(?:e-?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  var cur = Offset.zero;
  var start = Offset.zero;
  Offset? lastCtrl;
  double num() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp(r'[A-Za-z]').hasMatch(t)) {
      cmd = t;
      i++;
      if (cmd == 'Z' || cmd == 'z') {
        path.close();
        cur = start;
        lastCtrl = null;
        continue;
      }
    }
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        final x = num(), y = num();
        cur = rel ? cur + Offset(x, y) : Offset(x, y);
        start = cur;
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L';
        lastCtrl = null;
      case 'L':
        final x = num(), y = num();
        cur = rel ? cur + Offset(x, y) : Offset(x, y);
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
      case 'H':
        final x = num();
        cur = Offset(rel ? cur.dx + x : x, cur.dy);
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
      case 'V':
        final y = num();
        cur = Offset(cur.dx, rel ? cur.dy + y : y);
        path.lineTo(cur.dx, cur.dy);
        lastCtrl = null;
      case 'C':
        final o = rel ? cur : Offset.zero;
        final c1 = o + Offset(num(), num());
        final c2 = o + Offset(num(), num());
        final e = o + Offset(num(), num());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
      case 'S':
        final o = rel ? cur : Offset.zero;
        final c1 = lastCtrl == null ? cur : cur * 2 - lastCtrl;
        final c2 = o + Offset(num(), num());
        final e = o + Offset(num(), num());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, e.dx, e.dy);
        lastCtrl = c2;
        cur = e;
      case 'Q':
        final o = rel ? cur : Offset.zero;
        final c1 = o + Offset(num(), num());
        final e = o + Offset(num(), num());
        path.quadraticBezierTo(c1.dx, c1.dy, e.dx, e.dy);
        lastCtrl = c1;
        cur = e;
      default:
        i++;
    }
  }
  return path;
}
