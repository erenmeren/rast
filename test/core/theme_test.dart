import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:rast/core/theme/appearance.dart';
import 'package:rast/core/theme/rast_colors.dart';
import 'package:rast/core/theme/rast_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> containerWithPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [preferencesStoreProvider.overrideWithValue(PreferencesStore(prefs))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('light and dark tokens match the handoff', () {
    expect(RastColors.light.primary, const Color(0xFFCF4131));
    expect(RastColors.light.canvas, const Color(0xFFFFFFFF));
    expect(RastColors.light.accent, const Color(0xFFFA634F));
    expect(RastColors.dark.canvas, const Color(0xFF18191D));
    expect(RastColors.dark.accent, const Color(0xFFFF907F));
    expect(RastColors.dark.outgoingBubble, const Color(0xFFB93F30));
    expect(RastColors.dark.darkStage, const Color(0xFF151619));
  });

  test('no italic anywhere in the text theme', () {
    for (final brightness in Brightness.values) {
      final theme = rastTheme(brightness);
      final styles = [
        theme.textTheme.displayLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.bodyMedium,
        theme.textTheme.labelLarge,
        theme.textTheme.labelSmall,
      ];
      for (final s in styles) {
        expect(s!.fontStyle ?? FontStyle.normal, FontStyle.normal);
        expect(s.fontFamily, rastFontFamily);
      }
      expect(theme.extension<RastColors>(), isNotNull);
    }
  });

  test('rastStyle carries a variable weight axis', () {
    final s = rastStyle(size: 14, weight: 650);
    expect(s.fontVariations, [const FontVariation('wght', 650)]);
    expect(s.fontWeight, FontWeight.w700);
    expect(s.fontStyle, FontStyle.normal);
  });

  test('appearance persists and maps to ThemeMode', () async {
    SharedPreferences.setMockInitialValues({});
    final container = await containerWithPrefs();
    expect(container.read(appearanceProvider), Appearance.system);
    await container.read(appearanceProvider.notifier).set(Appearance.dark);
    expect(container.read(appearanceProvider), Appearance.dark);
    expect(themeModeOf(Appearance.dark), ThemeMode.dark);
    expect(themeModeOf(Appearance.light), ThemeMode.light);
    expect(themeModeOf(Appearance.system), ThemeMode.system);

    final again = await containerWithPrefs();
    expect(again.read(appearanceProvider), Appearance.dark);
  });

  testWidgets('explicit Light ignores platform dark; System follows it', (tester) async {
    Widget app(Appearance a) => MaterialApp(
          theme: rastTheme(Brightness.light),
          darkTheme: rastTheme(Brightness.dark),
          themeMode: themeModeOf(a),
          home: Builder(
            builder: (c) => Text('x', style: TextStyle(color: c.colors.canvas)),
          ),
        );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(app(Appearance.light));
    expect(Theme.of(tester.element(find.text('x'))).brightness, Brightness.light);

    await tester.pumpWidget(app(Appearance.system));
    await tester.pumpAndSettle(); // MaterialApp animates theme changes.
    expect(Theme.of(tester.element(find.text('x'))).brightness, Brightness.dark);
    expect(tester.element(find.text('x')).colors.canvas, RastColors.dark.canvas);
  });
}
