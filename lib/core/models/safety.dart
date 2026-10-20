const List<String> reportReasons = [
  'May be under 18',
  'Fake profile or someone else’s photos',
  'Harassment or inappropriate behaviour',
  'Scam or spam',
  'Another reason',
];

class Report {
  const Report({required this.personId, required this.reason});
  final String personId;
  final String reason;
}

/// Blocked profiles (reversible), permanently removed pairs and saved reports.
class SafetyState {
  const SafetyState({this.blocked = const {}, this.disconnected = const {}, this.reports = const []});

  final Set<String> blocked;
  final Set<String> disconnected;
  final List<Report> reports;

  static const empty = SafetyState();

  bool isUnavailable(String id) => blocked.contains(id) || disconnected.contains(id);
  bool hasReport(String id) => reports.any((r) => r.personId == id);

  SafetyState copyWith({Set<String>? blocked, Set<String>? disconnected, List<Report>? reports}) =>
      SafetyState(blocked: blocked ?? this.blocked, disconnected: disconnected ?? this.disconnected, reports: reports ?? this.reports);
}
