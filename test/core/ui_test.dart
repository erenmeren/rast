import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/theme/rast_theme.dart';
import 'package:rast/core/ui/ui.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: rastTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('PrimaryButton is disabled without onPressed', (tester) async {
    await tester.pumpWidget(wrap(const PrimaryButton(label: 'Go', onPressed: null)));
    var tapped = false;
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    await tester.pumpWidget(wrap(PrimaryButton(label: 'Go', onPressed: () => tapped = true)));
    await tester.tap(find.text('Go'));
    expect(tapped, isTrue);
  });

  testWidgets('OptionChip shows a check only when selected', (tester) async {
    await tester.pumpWidget(wrap(OptionChip(label: 'Women', selected: false, onTap: () {})));
    expect(find.byType(RastIcon), findsNothing);
    await tester.pumpWidget(wrap(OptionChip(label: 'Women', selected: true, onTap: () {})));
    expect(find.byType(RastIcon), findsOneWidget);
  });

  testWidgets('AgeRangeSlider labels the range and keeps min <= max', (tester) async {
    int? min, max;
    await tester.pumpWidget(wrap(AgeRangeSlider(minAge: 23, maxAge: 99, onChanged: (a, b) { min = a; max = b; })));
    expect(find.text('23–99+'), findsOneWidget);
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    slider.onChanged!(const RangeValues(40, 30));
    expect(min, 30);
    expect(max, 30);
  });

  testWidgets('TimingGrid renders all values and reports selection', (tester) async {
    int? picked;
    await tester.pumpWidget(wrap(TimingGrid<int>(
      values: const [15, 30, 45, 60, 75, 90, 105, 120],
      selected: 30,
      label: (v) => '$v',
      onSelect: (v) => picked = v,
    )));
    expect(find.text('105'), findsOneWidget);
    await tester.tap(find.text('45'));
    expect(picked, 45);
  });

  testWidgets('SubHeader step bars mark completed steps', (tester) async {
    await tester.pumpWidget(wrap(const SubHeader(title: 'About you', step: 3)));
    expect(find.byKey(const Key('step-bar-3-done')), findsOneWidget);
    expect(find.byKey(const Key('step-bar-4-todo')), findsOneWidget);
    expect(find.text('About you'), findsOneWidget);
  });

  testWidgets('showRastSheet shows the title and closes', (tester) async {
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => TextLinkButton(
        label: 'open',
        onPressed: () => showRastSheet<void>(context, title: 'Your kind of light.', builder: (_) => const Text('body')),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Your kind of light.'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('body'), findsNothing);
  });

  testWidgets('showToast shows and hides the message', (tester) async {
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => TextLinkButton(label: 'toast', onPressed: () => showToast(context, 'Like sent.')),
    )));
    await tester.tap(find.text('toast'));
    await tester.pump();
    expect(find.text('Like sent.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Like sent.'), findsNothing);
  });

  testWidgets('RastSwitch toggles', (tester) async {
    bool? v;
    await tester.pumpWidget(wrap(RastSwitch(value: false, onChanged: (x) => v = x, semanticLabel: 'Open to encounters')));
    await tester.tap(find.bySemanticsLabel('Open to encounters'));
    expect(v, isTrue);
  });
}
