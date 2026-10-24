# rast location lab

A throwaway Flutter app for Phase 0 of rast: it records background location samples on a real phone so we can measure interval, accuracy, outages and battery before building the real encounter pipeline. Nothing leaves the phone until you export a session.

Design: `../../docs/superpowers/specs/2026-10-24-location-lab-design.md`. Test runs: `PROTOCOL.md`.

## Build

```bash
export ANDROID_HOME=$HOME/Android/Sdk
~/development/flutter/bin/flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

iOS: open `ios/Runner.xcworkspace` on a Mac, set a team, run on the iPhone. Background location and the usage strings are already in `Info.plist`.

## Use

1. Grant the three permissions on the home screen (fine location, "Allow all the time", notifications).
2. Pick an interval (15 / 30 / 60 / 120 s) and accuracy, press Start. A persistent notification keeps the service alive on Android.
3. Press Together / Apart during two-phone runs to log ground truth.
4. Stop, open Sessions, Export. Files: `session.json`, `samples.csv`, `events.csv`.

Exports also sit in the app's documents directory under `exports/<session_id>/`.

## Analyse

```bash
python3 tools/analyze.py single <export_dir>
python3 tools/analyze.py pair <export_dir_a> <export_dir_b>
```

## Tests

```bash
~/development/flutter/bin/flutter test --timeout 90s
python3 -m unittest discover -s tools -p 'test_*.py'
```
