import 'package:flutter/material.dart';

/// The story has its own warm light palette and a dusk dark palette.
class StoryPalette {
  const StoryPalette({
    required this.paper,
    required this.ink,
    required this.coral,
    required this.muted,
    required this.sceneBg,
    required this.sceneBorder,
    required this.block,
    required this.blockStroke,
    required this.building,
    required this.buildingStroke,
    required this.road,
    required this.roadLine,
    required this.crosswalk,
    required this.park,
    required this.tree,
    required this.treeStroke,
    required this.bench,
    required this.grain,
    required this.personA,
    required this.personALabelBg,
    required this.personALabelFg,
    required this.personB,
    required this.personBLabelBg,
    required this.personBLabelFg,
    required this.radiusFill,
    required this.radiusLine,
    required this.radiusMeasure,
    required this.radiusText,
    required this.connection,
    required this.cardBg,
    required this.cardBorder,
    required this.cardText,
    required this.cardMuted,
    required this.pillBg,
    required this.pillBorder,
    required this.pillFg,
    required this.control,
    required this.controlBorder,
    required this.controlBg,
    required this.playFg,
    required this.playBg,
    required this.playBorder,
    required this.chapterTrack,
    required this.chapterFill,
    required this.chapterFg,
    required this.chapterActive,
    required this.counter,
    required this.narration,
    required this.cta,
    required this.ctaDisabled,
    required this.ctaDisabledFg,
    required this.note,
    required this.clockFace,
    required this.clockTrack,
    required this.clockProgress,
    required this.clockText,
    required this.clockSub,
    required this.kicker,
    required this.checkBg,
    required this.checkFg,
    required this.stampOther,
  });

  final Color paper, ink, coral, muted;
  final Color sceneBg, sceneBorder, block, blockStroke, building, buildingStroke, road, roadLine, crosswalk, park, tree, treeStroke, bench, grain;
  final Color personA, personALabelBg, personALabelFg, personB, personBLabelBg, personBLabelFg;
  final Color radiusFill, radiusLine, radiusMeasure, radiusText, connection;
  final Color cardBg, cardBorder, cardText, cardMuted, pillBg, pillBorder, pillFg;
  final Color control, controlBorder, controlBg, playFg, playBg, playBorder;
  final Color chapterTrack, chapterFill, chapterFg, chapterActive, counter, narration;
  final Color cta, ctaDisabled, ctaDisabledFg, note;
  final Color clockFace, clockTrack, clockProgress, clockText, clockSub, kicker, checkBg, checkFg, stampOther;

  static const light = StoryPalette(
    paper: Color(0xFFFCFAF6), ink: Color(0xFF292C33), coral: Color(0xFFD8523E), muted: Color(0xFF73716E),
    sceneBg: Color(0xFFF2EFEA), sceneBorder: Color(0xFFE9E2D8), block: Color(0xFFE4E0D9), blockStroke: Color(0xFFD9D5CF),
    building: Color(0xFFEFEDE7), buildingStroke: Color(0xFFD2CEC6), road: Color(0xFFFFFDFA), roadLine: Color(0xFFE4DFD5),
    crosswalk: Color(0xFFDDD7CC), park: Color(0xFFDCE5D8), tree: Color(0xFFBECFBA), treeStroke: Color(0xFFB3C4AE), bench: Color(0xFFB7B2AA), grain: Color(0xFFD7D3CC),
    personA: Color(0xFF292C33), personALabelBg: Color(0xFF292C33), personALabelFg: Colors.white,
    personB: Color(0xFFEE7159), personBLabelBg: Colors.white, personBLabelFg: Color(0xFF8D5546),
    radiusFill: Color(0xFFEE7159), radiusLine: Color(0xFFDF806A), radiusMeasure: Color(0xFFC7806A), radiusText: Color(0xFF965B48), connection: Color(0xFFD65A42),
    cardBg: Color(0xFFFFFCF8), cardBorder: Colors.white, cardText: Color(0xFF4C4239), cardMuted: Color(0xFFA38770),
    pillBg: Color(0xFFFFFAF2), pillBorder: Color(0xFFE9DBCB), pillFg: Color(0xFF806044),
    control: Color(0xFF7B5B45), controlBorder: Color(0xFFE9DFD4), controlBg: Color(0xFFFFFAF3),
    playFg: Color(0xFF97502F), playBg: Color(0xFFFAE4D4), playBorder: Color(0xFFEDC6AE),
    chapterTrack: Color(0xFFE8DFD4), chapterFill: Color(0xFFD97453), chapterFg: Color(0xFF938B82), chapterActive: Color(0xFF9E4D2E),
    counter: Color(0xFFB0967F), narration: Color(0xFF7E7469),
    cta: Color(0xFFCF513A), ctaDisabled: Color(0xFFE9E2D8), ctaDisabledFg: Color(0xFF8B8074), note: Color(0xFF958777),
    clockFace: Color(0xFF292C33), clockTrack: Color(0xFFDED7CB), clockProgress: Color(0xFFE78C6E), clockText: Color(0xFFFFFAF1), clockSub: Color(0xFFB5AAA0),
    kicker: Color(0xFF8C7364), checkBg: Color(0xFFE5ECDC), checkFg: Color(0xFF587142), stampOther: Color(0xFF292C33),
  );

  static const dark = StoryPalette(
    paper: Color(0xFF18191D), ink: Color(0xFFF1ECE6), coral: Color(0xFFF4957D), muted: Color(0xFFB7AAA0),
    sceneBg: Color(0xFF202125), sceneBorder: Color(0xFF453B34), block: Color(0xFF2D2E31), blockStroke: Color(0xFF424143),
    building: Color(0xFF353537), buildingStroke: Color(0xFF4A4846), road: Color(0xFF18191D), roadLine: Color(0xFF514B42),
    crosswalk: Color(0xFF625B50), park: Color(0xFF29372E), tree: Color(0xFF40563F), treeStroke: Color(0xFF58734F), bench: Color(0xFF857561), grain: Color(0xFF625C54),
    personA: Color(0xFF3D3C42), personALabelBg: Color(0xFFE7DED1), personALabelFg: Color(0xFF322B27),
    personB: Color(0xFFEE7159), personBLabelBg: Color(0xFF5B342A), personBLabelFg: Color(0xFFFFD1B6),
    radiusFill: Color(0xFFED8C6E), radiusLine: Color(0xFFE8A184), radiusMeasure: Color(0xFFC9916F), radiusText: Color(0xFFF7C7A2), connection: Color(0xFFFFAE8C),
    cardBg: Color(0xFF30271E), cardBorder: Color(0xFF725941), cardText: Color(0xFFF5DDBD), cardMuted: Color(0xFFD3AE85),
    pillBg: Color(0xFF372C22), pillBorder: Color(0xFF9B704E), pillFg: Color(0xFFF0CBAA),
    control: Color(0xFFD8B48B), controlBorder: Color(0xFF65513C), controlBg: Color(0xFF2E251D),
    playFg: Color(0xFFF4C08C), playBg: Color(0xFF4C3320), playBorder: Color(0xFFA7794D),
    chapterTrack: Color(0xFF53412E), chapterFill: Color(0xFFE49E67), chapterFg: Color(0xFFB3A08B), chapterActive: Color(0xFFFFC28B),
    counter: Color(0xFFC49C75), narration: Color(0xFFBFB09E),
    cta: Color(0xFFBD4A33), ctaDisabled: Color(0xFF37302A), ctaDisabledFg: Color(0xFFB2A08E), note: Color(0xFFB6A699),
    clockFace: Color(0xFF151619), clockTrack: Color(0xFF635547), clockProgress: Color(0xFFF0A47E), clockText: Color(0xFFFFF4E6), clockSub: Color(0xFFC6B197),
    kicker: Color(0xFFD8B693), checkBg: Color(0xFF35452C), checkFg: Color(0xFFC1D5A7), stampOther: Color(0xFF694F38),
  );

  static StoryPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
