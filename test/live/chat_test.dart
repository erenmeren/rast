import 'package:flutter_test/flutter_test.dart';
import 'package:rast/data/supabase/chat_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rast/core/storage/preferences_store.dart';

import 'live_helpers.dart';

void main() {
  test('threads, send and realtime change', () async {
    final client = await liveClient();
    SharedPreferences.setMockInitialValues({});
    final chat = SupabaseChatRepository(client, PreferencesStore(await SharedPreferences.getInstance()));
    final threads = (await chat.load()).threads;
    expect(threads, isNotEmpty, reason: 'the test user is matched with the owner');
    final owner = threads.first;
    expect(owner.messages.length, greaterThanOrEqualTo(2));
    expect(owner.messages.first.time, matches(RegExp(r'^\d\d:\d\d$')));

    final events = <void>[];
    final sub = chat.changes().listen(events.add);
    await Future<void>.delayed(const Duration(seconds: 2)); // let the channel subscribe
    final stamp = DateTime.now().toIso8601String();
    final seq = await chat.send(owner.personId, '00000000-0000-4000-8000-${stamp.hashCode.abs().toString().padLeft(12, '0').substring(0, 12)}', 'live $stamp');
    expect(seq, isNotNull);
    final again = (await chat.load()).threads;
    expect(again.first.messages.last.text, 'live $stamp');
    expect(again.first.messages.last.own, isTrue);
    await Future<void>.delayed(const Duration(seconds: 5));
    await sub.cancel();
    expect(events, isNotEmpty, reason: 'pair_event insert should reach the realtime channel');
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
