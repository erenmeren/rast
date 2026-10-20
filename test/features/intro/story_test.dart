import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/features/intro/story_controller.dart';
import 'package:rast/features/intro/story_model.dart';
import 'package:rast/features/intro/story_scene.dart';

import '../../helpers/app.dart';

void main() {
  group('howFrame', () {
    test('stages follow the chapter clock', () {
      expect(howFrame(0).stage, 0);
      expect(howFrame(6199).stage, 0);
      expect(howFrame(6200).stage, 1);
      expect(howFrame(10600).stage, 2);
      expect(howFrame(16400).stage, 3);
      expect(howFrame(21200).stage, 4);
      expect(howFrame(99999).time, howDurationMs);
    });

    test('people walk to within 20 metres and the likes land in order', () {
      expect(howFrame(0).crossed, isFalse);
      expect(howFrame(0).distance, greaterThan(20));
      expect(howFrame(6000).crossed, isTrue);
      expect(howFrame(6000).distance, lessThanOrEqualTo(20));
      expect(howFrame(27400).youLike && howFrame(27400).theyLike && howFrame(27400).chat, isTrue);
      expect(howFrame(22400).youLike, isTrue);
      expect(howFrame(22399).youLike, isFalse);
      expect(howFrame(23600).theyLike, isTrue);
      expect(howFrame(10600).remaining, 120);
      expect(howFrame(16400).remaining, 0);
      expect(minuteClock(120), '02:00');
      expect(minuteClock(75), '01:15');
    });

    test('chapter progress and smoothing are bounded', () {
      expect(chapterProgress(0, 0), 0);
      expect(chapterProgress(0, 6200), 1);
      expect(chapterProgress(4, 27400), 1);
      expect(during(500, 0, 1000), closeTo(0.5, 1e-9));
      expect(during(-5, 0, 1000), 0);
      expect(during(5000, 0, 1000), 1);
    });

    test('svg path parser handles the commands the scene uses', () {
      final bounds = parseSvgPathData('M-12 18H161Q175 18 175 32V124Q175 137 160 137H91L-12 108Z').getBounds();
      expect(bounds.left, -12);
      expect(bounds.top, 18);
      expect(bounds.right, closeTo(175, 0.01));
      final road = parseSvgPathData('M-28 250C63 258 113 208 173 210S285 190 389 146').getBounds();
      expect(road.right, closeTo(389, 0.01));
    });
  });

  group('StoryController', () {
    test('required mode completes after 27.4 s of credited playback', () {
      var completed = 0;
      final c = StoryController(required: true, reducedMotion: false, onComplete: () => completed++);
      for (var i = 0; i < 273; i++) {
        c.tick(const Duration(milliseconds: 100));
      }
      expect(c.complete, isFalse);
      c.tick(const Duration(milliseconds: 100));
      expect(c.complete, isTrue);
      expect(completed, 1);
      expect(c.playing, isFalse);
      expect(c.continueLabel, 'Start exploring');
      expect(c.playLabel, 'Complete');
      expect(c.accessNote, 'All set. Replay this anytime from Profile.');
    });

    test('a stalled frame credits at most 100 ms', () {
      final c = StoryController(required: true, reducedMotion: false);
      c.tick(const Duration(seconds: 5));
      expect(c.watchedMs, 100);
      expect(c.timeMs, 100);
    });

    test('hidden time is not credited and pause works', () {
      final c = StoryController(required: true, reducedMotion: false);
      c.tick(const Duration(milliseconds: 100));
      c.setVisible(false);
      c.tick(const Duration(milliseconds: 100));
      expect(c.watchedMs, 100);
      expect(c.accessNote, 'Keep the illustration in view to continue.');
      c.setVisible(true);
      c.toggle();
      expect(c.playing, isFalse);
      expect(c.playLabel, 'Play');
      c.tick(const Duration(milliseconds: 100));
      expect(c.watchedMs, 100);
      c.toggle();
      c.tick(const Duration(milliseconds: 100));
      expect(c.watchedMs, 200);
    });

    test('optional mode supports chapters, replay and reduced motion', () {
      final c = StoryController(required: false, reducedMotion: false);
      expect(c.playing, isTrue);
      c.setStep(2);
      expect(c.timeMs, 14000);
      expect(c.playing, isFalse);
      expect(c.frame.stage, 2);
      c.replay();
      expect(c.timeMs, 0);
      expect(c.playing, isTrue);
      for (var i = 0; i < 300; i++) {
        c.tick(const Duration(milliseconds: 100));
      }
      expect(c.finished, isTrue);
      expect(c.playLabel, 'Replay');
      c.toggle();
      expect(c.timeMs, 0);
      expect(c.playing, isTrue);

      final r = StoryController(required: false, reducedMotion: true);
      expect(r.playing, isFalse);
      expect(r.timeMs, howPosters[0]);
      expect(r.playLabel, 'Next step');
      r.toggle();
      expect(r.frame.stage, 1);
      expect(r.accessNote, 'Motion is reduced. Select a chapter to explore.');
    });

    test('required + reduced motion shows posters but still needs the time', () {
      final c = StoryController(required: true, reducedMotion: true);
      expect(c.isAnimating, isTrue);
      c.tick(const Duration(milliseconds: 100));
      expect(c.displayFrame.time, howPosters[0]);
      expect(c.chapterFill(0), 0);
      expect(c.accessNote, 'Reduced motion is on. The five scenes advance automatically.');
      c.setStep(3); // ignored in required mode
      expect(c.timeMs, 100);
    });

    test('time label', () {
      final c = StoryController(required: false, reducedMotion: false);
      expect(c.timeLabel, '0:00 / 0:27');
      c.tick(const Duration(milliseconds: 7300));
      expect(c.timeLabel, '0:07 / 0:27');
    });
  });

  testWidgets('scene renders in both themes without errors', (tester) async {
    await loadRastFont();
    final c = StoryController(required: false, reducedMotion: false);
    for (final b in Brightness.values) {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: b), home: Scaffold(body: StoryScene(controller: c))));
      for (final t in [0, 6000, 8000, 12000, 18000, 26000]) {
        c.timeMs = t;
        c.notifyListeners();
        await tester.pump();
      }
    }
    expect(tester.takeException(), isNull);
  });
}
