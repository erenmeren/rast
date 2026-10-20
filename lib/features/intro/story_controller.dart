import 'dart:math';

import 'package:flutter/foundation.dart';

import 'story_model.dart';

/// Playback state for the story. Required mode credits only visible,
/// foreground playback and caps each credited frame at 100 ms so a stalled
/// frame can never skip a scene nobody saw.
class StoryController extends ChangeNotifier {
  StoryController({required this.required, required bool reducedMotion, this.onComplete})
      : _reduced = reducedMotion,
        timeMs = reducedMotion && !required ? howPosters[0] : 0,
        playing = required || !reducedMotion;

  final bool required;
  final VoidCallback? onComplete;

  bool _reduced;
  bool get reducedMotion => _reduced;

  int timeMs;
  int watchedMs = 0;
  bool playing;
  bool complete = false;
  bool inView = true;

  static const int maxCreditedFrameMs = 100;

  HowFrame get frame => howFrame(timeMs);

  /// Required + reduced motion shows timed still scenes while time advances.
  HowFrame get displayFrame => required && _reduced ? howFrame(howPosters[frame.stage]) : frame;

  bool get isAnimating => playing && (!_reduced || required) && inView && !(required && complete);

  bool get finished => timeMs >= howDurationMs;

  /// Advance by the wall-clock time since the previous frame.
  void tick(Duration elapsed) {
    if (!isAnimating) return;
    final ms = max(0, elapsed.inMilliseconds);
    if (required) {
      watchedMs = min(howDurationMs, watchedMs + min(ms, maxCreditedFrameMs));
      timeMs = watchedMs;
    } else {
      timeMs = min(howDurationMs, timeMs + ms);
    }
    if (timeMs >= howDurationMs) {
      playing = false;
      if (required && !complete && watchedMs >= howDurationMs) {
        complete = true;
        onComplete?.call();
      }
    }
    notifyListeners();
  }

  void toggle() {
    if (required && complete) return;
    if (_reduced && !required) {
      setStep((frame.stage + 1) % howSteps.length);
      return;
    }
    if (timeMs >= howDurationMs && !required) timeMs = 0;
    playing = !playing;
    notifyListeners();
  }

  void replay() {
    if (required) return;
    timeMs = _reduced ? howPosters[0] : 0;
    playing = !_reduced;
    notifyListeners();
  }

  void setStep(int index) {
    if (required) return;
    playing = false;
    timeMs = howPosters[index.clamp(0, howPosters.length - 1)];
    notifyListeners();
  }

  void setVisible(bool visible) {
    if (inView == visible) return;
    inView = visible;
    notifyListeners();
  }

  void setReducedMotion(bool reduced) {
    if (_reduced == reduced) return;
    _reduced = reduced;
    if (_reduced && !required) {
      playing = false;
      timeMs = howPosters[frame.stage];
    }
    notifyListeners();
  }

  double chapterFill(int index) {
    if (required && _reduced) return complete || index < frame.stage ? 1 : 0;
    return chapterProgress(index, timeMs);
  }

  String get playLabel {
    if (required && complete) return 'Complete';
    if (_reduced && !required) return 'Next step';
    if (playing) return 'Pause';
    if (finished) return 'Replay';
    return 'Play';
  }

  String get timeLabel => '0:${(frame.time ~/ 1000).toString().padLeft(2, '0')} / 0:27';

  String get accessNote {
    if (required) {
      if (complete) return 'All set. Replay this anytime from Profile.';
      if (!inView) return 'Keep the illustration in view to continue.';
      if (_reduced) return 'Reduced motion is on. The five scenes advance automatically.';
      return 'A short introduction, just once before you begin.';
    }
    return _reduced ? 'Motion is reduced. Select a chapter to explore.' : 'Replay this anytime from your profile.';
  }

  String get continueLabel => complete ? 'Start exploring' : 'Watch to continue';
}
