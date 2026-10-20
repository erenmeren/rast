enum SessionPhase { signedOut, onboarding, introPending, active }

class Session {
  const Session({this.phase = SessionPhase.signedOut, this.verified = false});
  final SessionPhase phase;
  final bool verified;

  static const signedOut = Session();

  Session copyWith({SessionPhase? phase, bool? verified}) =>
      Session(phase: phase ?? this.phase, verified: verified ?? this.verified);
}

enum IntroStatus { none, pending, complete }
