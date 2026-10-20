import 'dart:math';

import 'package:flutter/painting.dart';

/// Pure timeline maths for the introduction. Mirrors `how-it-works.js`.
/// Everything is illustrative: no dating data is read or written.

const int howDurationMs = 27400;

class HowStep {
  const HowStep({required this.at, required this.label, required this.title, required this.copy, required this.scene});
  final int at;
  final String label;
  final String title;
  final String copy;
  final String scene;
}

const List<HowStep> howSteps = [
  HowStep(at: 0, label: 'Cross paths', title: 'Life brings you a little closer.', copy: 'Go about your day. When someone comes within about 20 metres, your paths can cross.', scene: 'OUT IN THE WORLD'),
  HowStep(at: 6200, label: 'Both fit', title: 'The connection goes both ways.', copy: 'You must both match each other’s age and gender preferences. A crossing alone isn’t enough.', scene: 'THE FIT IS MUTUAL'),
  HowStep(at: 10600, label: 'Give it time', title: 'A little space. A little time.', copy: 'The longer privacy delay wins. Here, you choose 1 hour and they choose 2, so both wait 2 hours.', scene: 'PRIVACY SETS THE PACE'),
  HowStep(at: 16400, label: 'Discover', title: 'Now, a familiar stranger.', copy: 'Their profile appears in Discover. Your exact location and crossing time stay private.', scene: 'A NEW POSSIBILITY'),
  HowStep(at: 21200, label: 'Say hello', title: 'Two likes. One new beginning.', copy: 'You like each other. A chat opens. Where the conversation goes is up to you.', scene: 'THE NEXT MOVE IS YOURS'),
];

/// Still frames used for reduced motion and chapter selection.
const List<int> howPosters = [5900, 9900, 14000, 20000, howDurationMs];

double bounded(double x, [double lo = 0, double hi = 1]) => min(hi, max(lo, x));
double smooth(double x) {
  final v = bounded(x);
  return v * v * (3 - 2 * v);
}

/// Smoothstep from 0 at [start] to 1 at [end] (milliseconds).
double during(int t, int start, int end) => smooth((t - start) / (end - start));

double _bezier(double a, double b, double c, double d, double t) =>
    pow(1 - t, 3) * a + 3 * pow(1 - t, 2) * t * b + 3 * (1 - t) * t * t * c + pow(t, 3) * d;

/// "MM:SS"-style hours:minutes label for the privacy clock.
String minuteClock(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class HowFrame {
  const HowFrame({
    required this.time,
    required this.a,
    required this.b,
    required this.distance,
    required this.crossed,
    required this.stage,
    required this.wait,
    required this.remaining,
    required this.youLike,
    required this.theyLike,
    required this.chat,
  });

  final int time;

  /// Scene coordinates in a 360×360 space.
  final Offset a;
  final Offset b;

  /// Illustrated metres: four scene units equal one metre.
  final double distance;
  final bool crossed;
  final int stage;
  final double wait;
  final int remaining;
  final bool youLike;
  final bool theyLike;
  final bool chat;
}

HowFrame howFrame(int milliseconds) {
  final time = bounded(milliseconds.toDouble(), 0, howDurationMs.toDouble()).toInt();
  final walk = smooth(time / 6000);
  final a = Offset(_bezier(-32, 21, 104, 142, walk), _bezier(253, 259, 221, 205, walk));
  final b = Offset(_bezier(257, 256, 231, 205, walk), _bezier(-34, 54, 126, 174, walk));
  final distance = (a - b).distance / 4;
  var stage = 0;
  for (var i = 0; i < howSteps.length; i++) {
    if (time >= howSteps[i].at) stage = i;
  }
  final wait = bounded((time - howSteps[2].at) / (howSteps[3].at - howSteps[2].at));
  return HowFrame(
    time: time,
    a: a,
    b: b,
    distance: distance,
    crossed: distance <= 20,
    stage: stage,
    wait: wait,
    remaining: (120 * (1 - wait)).ceil(),
    youLike: time >= 22400,
    theyLike: time >= 23600,
    chat: time >= 24800,
  );
}

/// 0..1 progress of chapter [index] at [timeMs].
double chapterProgress(int index, int timeMs) {
  final start = howSteps[index].at;
  final end = index + 1 < howSteps.length ? howSteps[index + 1].at : howDurationMs;
  return bounded((timeMs - start) / (end - start));
}
