/// Rows recorded by the location lab. Column names and orders are fixed by
/// docs/superpowers/specs/2026-10-24-location-lab-design.md.
library;

enum Lifecycle { resumed, inactive, paused, hidden, detached }

enum BatteryStateLabel { charging, discharging, full, unknown }

enum RequestedAccuracy { best, high, medium }

enum EventKind {
  lifecycle,
  permission,
  stream,
  error,
  marker,
  note,
  battery,
  appStart;

  /// Snake_case name used in CSV and the database.
  String get wire => this == EventKind.appStart ? 'app_start' : name;

  static EventKind fromWire(String wire) =>
      wire == 'app_start' ? EventKind.appStart : EventKind.values.byName(wire);
}

class LabSession {
  const LabSession({
    required this.id,
    required this.deviceId,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    required this.startedAtUtcMs,
    this.endedAtUtcMs,
    required this.requestedIntervalS,
    required this.requestedAccuracy,
    this.ntpOffsetMs,
    this.notes = '',
  });

  final String id;
  final String deviceId;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final int startedAtUtcMs;
  final int? endedAtUtcMs;
  final int requestedIntervalS;
  final RequestedAccuracy requestedAccuracy;
  final int? ntpOffsetMs;
  final String notes;

  Map<String, Object?> toJson() => {
        'id': id,
        'device_id': deviceId,
        'device_model': deviceModel,
        'os_version': osVersion,
        'app_version': appVersion,
        'started_at_utc_ms': startedAtUtcMs,
        'ended_at_utc_ms': endedAtUtcMs,
        'requested_interval_s': requestedIntervalS,
        'requested_accuracy': requestedAccuracy.name,
        'ntp_offset_ms': ntpOffsetMs,
        'notes': notes,
      };

  factory LabSession.fromJson(Map<String, Object?> m) => LabSession(
        id: m['id'] as String,
        deviceId: m['device_id'] as String,
        deviceModel: m['device_model'] as String,
        osVersion: m['os_version'] as String,
        appVersion: m['app_version'] as String,
        startedAtUtcMs: m['started_at_utc_ms'] as int,
        endedAtUtcMs: m['ended_at_utc_ms'] as int?,
        requestedIntervalS: m['requested_interval_s'] as int,
        requestedAccuracy:
            RequestedAccuracy.values.byName(m['requested_accuracy'] as String),
        ntpOffsetMs: m['ntp_offset_ms'] as int?,
        notes: (m['notes'] as String?) ?? '',
      );
}

class Sample {
  const Sample({
    required this.sessionId,
    required this.seq,
    required this.deviceTimeUtcMs,
    required this.fixTimeUtcMs,
    required this.lat,
    required this.lon,
    required this.accuracyM,
    required this.altitudeM,
    required this.speedMps,
    required this.headingDeg,
    required this.isMocked,
    required this.lifecycle,
    required this.batteryPct,
    required this.batteryState,
  });

  final String sessionId;
  final int seq;
  final int deviceTimeUtcMs;
  final int fixTimeUtcMs;
  final double lat;
  final double lon;
  final double accuracyM;
  final double altitudeM;
  final double speedMps;
  final double headingDeg;
  final bool isMocked;
  final Lifecycle lifecycle;
  final int batteryPct;
  final BatteryStateLabel batteryState;

  static const List<String> csvHeader = [
    'session_id',
    'seq',
    'device_time_utc_ms',
    'fix_time_utc_ms',
    'lat',
    'lon',
    'accuracy_m',
    'altitude_m',
    'speed_mps',
    'heading_deg',
    'is_mocked',
    'lifecycle',
    'battery_pct',
    'battery_state',
  ];

  List<Object?> toCsvRow() => [
        sessionId,
        seq,
        deviceTimeUtcMs,
        fixTimeUtcMs,
        lat,
        lon,
        accuracyM,
        altitudeM,
        speedMps,
        headingDeg,
        isMocked,
        lifecycle.name,
        batteryPct,
        batteryState.name,
      ];

  Map<String, Object?> toRow() => {
        'session_id': sessionId,
        'seq': seq,
        'device_time_utc_ms': deviceTimeUtcMs,
        'fix_time_utc_ms': fixTimeUtcMs,
        'lat': lat,
        'lon': lon,
        'accuracy_m': accuracyM,
        'altitude_m': altitudeM,
        'speed_mps': speedMps,
        'heading_deg': headingDeg,
        'is_mocked': isMocked ? 1 : 0,
        'lifecycle': lifecycle.name,
        'battery_pct': batteryPct,
        'battery_state': batteryState.name,
      };

  factory Sample.fromRow(Map<String, Object?> m) => Sample(
        sessionId: m['session_id'] as String,
        seq: m['seq'] as int,
        deviceTimeUtcMs: m['device_time_utc_ms'] as int,
        fixTimeUtcMs: m['fix_time_utc_ms'] as int,
        lat: (m['lat'] as num).toDouble(),
        lon: (m['lon'] as num).toDouble(),
        accuracyM: (m['accuracy_m'] as num).toDouble(),
        altitudeM: (m['altitude_m'] as num).toDouble(),
        speedMps: (m['speed_mps'] as num).toDouble(),
        headingDeg: (m['heading_deg'] as num).toDouble(),
        isMocked: (m['is_mocked'] as int) == 1,
        lifecycle: Lifecycle.values.byName(m['lifecycle'] as String),
        batteryPct: m['battery_pct'] as int,
        batteryState: BatteryStateLabel.values.byName(m['battery_state'] as String),
      );
}

class LabEvent {
  const LabEvent({
    required this.sessionId,
    required this.timeUtcMs,
    required this.kind,
    required this.detail,
  });

  final String sessionId;
  final int timeUtcMs;
  final EventKind kind;
  final String detail;

  static const List<String> csvHeader = ['session_id', 'time_utc_ms', 'kind', 'detail'];

  List<Object?> toCsvRow() => [sessionId, timeUtcMs, kind.wire, detail];

  Map<String, Object?> toRow() => {
        'session_id': sessionId,
        'time_utc_ms': timeUtcMs,
        'kind': kind.wire,
        'detail': detail,
      };

  factory LabEvent.fromRow(Map<String, Object?> m) => LabEvent(
        sessionId: m['session_id'] as String,
        timeUtcMs: m['time_utc_ms'] as int,
        kind: EventKind.fromWire(m['kind'] as String),
        detail: m['detail'] as String,
      );
}
