import 'dart:convert';
import 'dart:io';

import 'package:share_plus/share_plus.dart';

import 'lab_store.dart';
import 'models.dart';

/// RFC 4180 CSV: fields holding a comma, quote or line break are quoted and
/// quotes are doubled. Booleans print as true/false; enums must already be
/// their wire names.
String toCsv(List<String> header, Iterable<List<Object?>> rows) {
  final buffer = StringBuffer();
  void line(List<Object?> fields) {
    buffer
      ..write(fields.map(_field).join(','))
      ..write('\n');
  }

  line(header);
  for (final row in rows) {
    line(row);
  }
  return buffer.toString();
}

String _field(Object? value) {
  final text = switch (value) {
    null => '',
    bool b => b ? 'true' : 'false',
    _ => value.toString(),
  };
  if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// Writes session.json, samples.csv and events.csv under
/// `<root>/exports/<session id>/` and returns the three files in that order.
Future<List<File>> writeExport(LabStore store, LabSession session, Directory root) async {
  final dir = Directory('${root.path}/exports/${session.id}');
  await dir.create(recursive: true);

  final sessionFile = File('${dir.path}/session.json');
  await sessionFile.writeAsString(const JsonEncoder.withIndent('  ').convert(session.toJson()));

  final samples = await store.samples(session.id);
  final samplesFile = File('${dir.path}/samples.csv');
  await samplesFile.writeAsString(toCsv(Sample.csvHeader, samples.map((s) => s.toCsvRow())));

  final events = await store.events(session.id);
  final eventsFile = File('${dir.path}/events.csv');
  await eventsFile.writeAsString(toCsv(LabEvent.csvHeader, events.map((e) => e.toCsvRow())));

  return [sessionFile, samplesFile, eventsFile];
}

Future<void> shareExport(List<File> files, {String? subject}) => SharePlus.instance.share(
      ShareParams(
        files: files.map((f) => XFile(f.path)).toList(),
        subject: subject ?? 'rast location lab export',
      ),
    );
