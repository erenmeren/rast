# Native font asset

`PlusJakartaSans-Variable.ttf` is an unchanged official Google Fonts TTF. It contains a normal-style weight axis from 200 to 800, with default 400. The rast design uses 400–800. Attribution and provenance are in `OFL.txt` and `source.json`.

Copy the font and license to the new Flutter project's `assets/fonts/` directory. The example below is a configuration fragment to merge into the new project's `pubspec.yaml`, not a complete Flutter project:

```yaml
flutter:
  fonts:
    - family: PlusJakartaSans
      fonts:
        - asset: assets/fonts/PlusJakartaSans-Variable.ttf
  assets:
    - assets/fonts/OFL.txt
```

Set `ThemeData(fontFamily: 'PlusJakartaSans')`. Preserve actual variable weights when building the text theme. Where explicit axis selection is needed in the target SDK, Flutter's `FontVariation` can specify `wght`; verify rendered weights on the target platform and SDK. Do not use synthetic italics or replace missing weights with an old bundled serif.

Official references, consulted on 2026-10-20:

- https://docs.flutter.dev/cookbook/design/fonts
- https://api.flutter.dev/flutter/painting/TextStyle-class.html
- https://api.flutter.dev/flutter/dart-ui/FontVariation-class.html

This TTF was structurally verified with font metadata inspection, including its variable axis. No Flutter font rendering or native build is claimed by this handoff.

