import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_lab/export.dart';
import 'package:location_lab/models.dart';

import 'memory_store.dart';

const session = LabSession(
  id: 'exp-1',
  deviceId: 'dev',
  deviceModel: 'Pixel 9a',
  osVersion: 'Android 17',
  appVersion: '0.1.0',
  startedAtUtcMs: 1000,
  endedAtUtcMs: 61000,
  requestedIntervalS: 30,
  requestedAccuracy: RequestedAccuracy.high,
  ntpOffsetMs: 42,
  notes: 'walk, "quoted"',
);

Sample sample(int seq) => Sample(
      sessionId: 'exp-1',
      seq: seq,
      deviceTimeUtcMs: 1000 + seq * 30000,
      fixTimeUtcMs: 900 + seq * 30000,
      lat: 41.0,
      lon: 29.0,
      accuracyM: 8.5,
      altitudeM: 40,
      speedMps: 1.2,
      headingDeg: 90,
      isMocked: false,
      lifecycle: Lifecycle.paused,
      batteryPct: 80,
      batteryState: BatteryStateLabel.discharging,
    );

void main() {
  test('csv escapes quotes and commas', () {
    expect(
      toCsv(['a', 'b'], [
        ['x,y', 'he said "hi"']
      ]),
      'a,b\n"x,y","he said ""hi"""\n',
    );
    expect(toCsv(['n', 'f', 'b'], [[1, 2.5, true]]), 'n,f,b\n1,2.5,true\n');
    expect(toCsv(['t'], [['line\nbreak']]), 't\n"line\nbreak"\n');
  });

  test('writeExport produces three files with headers and one row per record', () async {
    final root = await Directory.systemTemp.createTemp('lab-export');
    addTearDown(() => root.delete(recursive: true));
    final store = MemoryLabStore();
    await store.insertSession(session);
    await store.insertSample(sample(0));
    await store.insertSample(sample(1));
    await store.insertEvent(const LabEvent(
      sessionId: 'exp-1',
      timeUtcMs: 2000,
      kind: EventKind.marker,
      detail: 'together',
    ));

    final files = await writeExport(store, session, root);
    expect(files.map((f) => f.uri.pathSegments.last).toList(),
        ['session.json', 'samples.csv', 'events.csv']);
    expect(files.first.path, '${root.path}/exports/exp-1/session.json');

    final samples = await files[1].readAsLines();
    expect(samples.length, 3);
    expect(samples.first, Sample.csvHeader.join(','));
    expect(samples[1], startsWith('exp-1,0,1000,900,41.0,29.0,8.5,40.0,1.2,90.0,false,paused,80,discharging'));

    final events = await files[2].readAsLines();
    expect(events, ['session_id,time_utc_ms,kind,detail', 'exp-1,2000,marker,together']);
  });

  test('session.json round-trips through jsonDecode', () async {
    final root = await Directory.systemTemp.createTemp('lab-export');
    addTearDown(() => root.delete(recursive: true));
    final store = MemoryLabStore();
    await store.insertSession(session);
    final files = await writeExport(store, session, root);
    final decoded = jsonDecode(await files.first.readAsString()) as Map<String, Object?>;
    expect(LabSession.fromJson(decoded).notes, 'walk, "quoted"');
    expect(decoded['ntp_offset_ms'], 42);
    expect(decoded['requested_accuracy'], 'high');
  });
}
