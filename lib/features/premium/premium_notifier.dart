import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Demo entitlement flag. Nothing is purchased. Production: store receipt
/// verified on the server; the client flag is never authoritative.
class PremiumNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(entitlementRepositoryProvider).isPremium();

  void activatePreview() {
    state = true;
    ref.read(entitlementRepositoryProvider).setPremium(true);
  }

  void end() {
    state = false;
    ref.read(entitlementRepositoryProvider).setPremium(false);
  }
}

final premiumProvider = NotifierProvider<PremiumNotifier, bool>(PremiumNotifier.new);
