import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rast/data/repositories.dart';
import 'package:rast/data/supabase/photo_repository.dart';

import 'live_helpers.dart';

// A 1×1 PNG: decodable, far below the 320 px minimum.
const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  test('upload, finalize, signed url, rejection and removal', () async {
    final client = await liveClient();
    final photos = SupabasePhotoRepository(client);

    final src = await photos.upload(3, 'assets/photos/portrait-1.jpg');
    expect(src, startsWith('sb:'));
    final row = await client.from('photo').select('state').eq('slot', 3).eq('state', 'ready').maybeSingle();
    expect(row, isNotNull);

    final req = await photos.resolve(src);
    expect(req, isNotNull);
    final res = await http.get(req!.uri, headers: req.headers);
    expect(res.statusCode, 200);
    expect(res.headers['content-type'], startsWith('image/'));

    final tiny = File('${Directory.systemTemp.path}/rast-tiny.png')..writeAsBytesSync(base64Decode(_tinyPng));
    await expectLater(photos.upload(2, tiny.path), throwsA(isA<PhotoRejected>().having((e) => e.reason, 'reason', 'too_small')));
    final leftover = await client.from('photo').select('id').eq('slot', 2).eq('state', 'uploading');
    expect(leftover, isEmpty, reason: 'a rejected upload leaves no uploading row');
    final slot2 = await client.from('photo').select('id').eq('slot', 2).eq('state', 'ready');
    expect(slot2, hasLength(1), reason: 'the previous ready photo in the slot survives a rejected replacement');

    // put slot 3 back the way the other tests expect it: one ready photo
    expect(await client.from('photo').select('id').eq('slot', 3).eq('state', 'ready'), hasLength(1));
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
