import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../auth/session_notifier.dart';
import 'intro_notifier.dart';
import 'story_controller.dart';
import 'story_model.dart';
import 'story_palette.dart';
import 'story_scene.dart';

/// The five-scene story. [required] is the one-time gate after setup:
/// pausable, not skippable, back is blocked. Otherwise it is the optional
/// replay under Profile with chapter controls.
class HowItWorksPage extends ConsumerStatefulWidget {
  const HowItWorksPage({super.key, required this.required});
  final bool required;

  @override
  ConsumerState<HowItWorksPage> createState() => HowItWorksPageState();
}

class HowItWorksPageState extends ConsumerState<HowItWorksPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  StoryController? _controller;

  @visibleForTesting
  StoryController get controller => _controller!;
  late final Ticker _ticker;
  Duration? _last;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_controller == null) {
      _controller = StoryController(required: widget.required, reducedMotion: reduced, onComplete: _onComplete);
      _controller!.addListener(_sync);
      _sync();
    } else {
      _controller!.setReducedMotion(reduced);
    }
  }

  void _sync() {
    final c = _controller!;
    if (c.isAnimating && !_ticker.isActive) {
      _last = null;
      _ticker.start();
    } else if (!c.isAnimating && _ticker.isActive) {
      _ticker.stop();
      _last = null;
    }
  }

  void _onTick(Duration elapsed) {
    final previous = _last;
    _last = elapsed;
    if (previous == null) return;
    _controller!.tick(elapsed - previous);
  }

  void _onComplete() {
    if (widget.required) ref.read(introProvider.notifier).complete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller?.setVisible(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller!;
    final p = StoryPalette.of(context);
    final required = widget.required;
    final body = Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final stage = c.frame.stage;
            final step = howSteps[stage];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RastLogo(size: 31, color: p.ink),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: p.controlBorder)),
                        child: Row(
                          children: [
                            Container(width: 5, height: 5, decoration: BoxDecoration(color: p.chapterFill, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('Illustrative demo', style: rastStyle(size: 10, weight: 600, color: p.note)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(required ? 'ONE QUICK INTRODUCTION' : 'SMALL WORLD. GOOD TIMING.', style: rastStyle(size: 10, weight: 750, letterSpacing: 1.6, color: p.note)),
                  const SizedBox(height: 9),
                  Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(text: 'How a hello ', children: [TextSpan(text: 'happens.', style: TextStyle(color: p.coral))]),
                      style: rastStyle(size: 28, weight: 800, height: 1.14, letterSpacing: -1.25, color: p.ink),
                    ),
                  ),
                  if (required) ...[
                    const SizedBox(height: 10),
                    Text('Watch once. Then make your next move.', style: rastStyle(size: 12, weight: 450, height: 1.5, color: p.muted)),
                  ],
                  const SizedBox(height: 17),
                  Semantics(
                    image: true,
                    label: '${step.title} ${step.copy} This is an illustrative demo.',
                    child: StoryScene(controller: c),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Control(
                        icon: c.playing && c.isAnimating ? 'pause' : 'play',
                        label: c.playLabel,
                        primary: true,
                        enabled: !(required && c.complete),
                        onTap: c.toggle,
                        semanticLabel: '${c.playLabel}${c.reducedMotion || c.complete ? '' : ' animation'}',
                        palette: p,
                      ),
                      Expanded(
                        child: Text(c.timeLabel, textAlign: TextAlign.center, style: rastStyle(size: 10, weight: 600, color: p.note).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                      if (required)
                        Row(
                          children: [
                            RastIcon('check', size: 13, color: p.isDark ? const Color(0xFFD9A183) : const Color(0xFFA46D53)),
                            const SizedBox(width: 5),
                            Text('Just this once', style: rastStyle(size: 10, weight: 600, color: p.note)),
                          ],
                        )
                      else
                        _Control(icon: 'rewind', label: 'Replay', primary: false, enabled: true, onTap: c.replay, semanticLabel: 'Replay animation', palette: p),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label: required ? 'Introduction progress' : 'Animation chapters',
                    child: Row(
                      children: [
                        for (var i = 0; i < howSteps.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                              child: _Chapter(
                                index: i,
                                label: howSteps[i].label,
                                progress: c.chapterFill(i),
                                active: i == stage,
                                enabled: !required,
                                onTap: () => c.setStep(i),
                                palette: p,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${(stage + 1).toString().padLeft(2, '0')} / 05', style: rastStyle(size: 9, weight: 800, letterSpacing: 1.1, color: p.counter)),
                          const SizedBox(height: 7),
                          Text(step.title, style: rastStyle(size: 19, weight: 800, height: 1.3, letterSpacing: -0.5, color: p.ink)),
                          const SizedBox(height: 8),
                          Text(step.copy, style: rastStyle(size: 14, weight: 450, height: 1.65, color: p.narration)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 19),
                  _Cta(
                    label: required ? c.continueLabel : 'Back to Profile',
                    enabled: !required || c.complete,
                    palette: p,
                    onTap: () {
                      if (required) {
                        ref.read(sessionProvider.notifier).completeIntro();
                      } else {
                        context.go('/profile');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.accessNote,
                    textAlign: TextAlign.center,
                    style: rastStyle(size: 10, weight: 450, height: 1.5, color: p.note),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (!required) return body;
    return PopScope(canPop: false, child: body);
  }
}

extension on StoryPalette {
  bool get isDark => paper == StoryPalette.dark.paper;
}

class _Control extends StatelessWidget {
  const _Control({required this.icon, required this.label, required this.primary, required this.enabled, required this.onTap, required this.semanticLabel, required this.palette});
  final String icon;
  final String label;
  final bool primary;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticLabel;
  final StoryPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final fg = primary ? p.playFg : p.control;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: primary ? p.playBg : p.controlBg,
        shape: StadiumBorder(side: BorderSide(color: primary ? p.playBorder : p.controlBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RastIcon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
                Text(label, style: rastStyle(size: 12, weight: 700, height: 1, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chapter extends StatelessWidget {
  const _Chapter({required this.index, required this.label, required this.progress, required this.active, required this.enabled, required this.onTap, required this.palette});
  final int index;
  final String label;
  final double progress;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final StoryPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: 'Step ${index + 1}: $label',
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 3,
                  color: p.chapterTrack,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0, 1),
                    child: ColoredBox(color: p.chapterFill),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(label, maxLines: 2, style: rastStyle(size: 12, weight: active ? 800 : 650, height: 1.35, color: active ? p.chapterActive : p.chapterFg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.enabled, required this.palette, required this.onTap});
  final String label;
  final bool enabled;
  final StoryPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? p.cta : p.ctaDisabled,
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 49),
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: rastStyle(size: 14, weight: 750, color: enabled ? const Color(0xFFFFFAF5) : p.ctaDisabledFg)),
                const SizedBox(width: 10),
                RastIcon('arrow', size: 18, color: enabled ? const Color(0xFFFFFAF5) : p.ctaDisabledFg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
