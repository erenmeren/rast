import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../repositories.dart';
import 'backend.dart';
import '../../core/ids.dart';
import 'profile_repository.dart' show storagePrefix;

const String previewPrefix = 'preview:';
const Duration _signedUrlLife = Duration(hours: 1);
const Duration _signedUrlReuse = Duration(minutes: 50);

/// Upload → `photo-finalize` → `sb:` source. The server renders the preview
/// and is the only thing that marks a photo ready.
class SupabasePhotoRepository implements PhotoRepository {
  SupabasePhotoRepository(this.client);
  final SupabaseClient client;
  final Map<String, (Uri, DateTime)> _signed = {};

  String get _me {
    final id = client.auth.currentUser?.id;
    if (id == null) throw const AuthException('not signed in');
    return id;
  }

  @override
  Future<String> upload(int slot, String filePath) async {
    final me = _me;
    final bytes = await File(filePath).readAsBytes();
    final png = filePath.toLowerCase().endsWith('.png');
    final mime = png ? 'image/png' : 'image/jpeg';
    // a stale attempt in this slot would block the live-slot index; clients
    // cannot delete rows, so it is retired instead
    await client.from('photo').update({'state': 'removed'}).eq('account_id', me).eq('slot', slot).eq('state', 'uploading');
    final id = newUuid();
    final path = '$me/$id.${png ? 'png' : 'jpg'}';
    await client.from('photo').insert({'id': id, 'account_id': me, 'slot': slot, 'storage_path': path});
    try {
      await client.storage.from('photos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
      final res = await client.functions.invoke('photo-finalize', body: {'photo_id': id});
      if (res.status != 200) {
        final data = res.data;
        throw PhotoRejected(data is Map && data['error'] is String ? data['error'] as String : 'unknown_photo');
      }
    } on FunctionException catch (e) {
      final details = e.details;
      await _discard(id, path);
      throw PhotoRejected(details is Map && details['error'] is String ? details['error'] as String : 'unknown_photo');
    } catch (_) {
      await _discard(id, path);
      rethrow;
    }
    return '$storagePrefix$path';
  }

  Future<void> _discard(String id, String path) async {
    try {
      await client.from('photo').update({'state': 'removed'}).eq('id', id);
      await client.storage.from('photos').remove([path]);
    } catch (_) {}
  }

  @override
  Future<void> remove(String source) async {
    if (!source.startsWith(storagePrefix)) return;
    final path = source.substring(storagePrefix.length);
    await client.from('photo').update({'state': 'removed'}).eq('storage_path', path);
    try {
      await client.storage.from('photos').remove([path]);
    } catch (_) {}
  }

  @override
  Future<ImageRequest?> resolve(String source) async {
    if (source.startsWith(previewPrefix)) {
      final token = source.substring(previewPrefix.length);
      final jwt = client.auth.currentSession?.accessToken;
      if (jwt == null) return null;
      return ImageRequest(Uri.parse('$supabaseUrl/functions/v1/like-preview?token=$token'),
          headers: {'Authorization': 'Bearer $jwt'});
    }
    if (!source.startsWith(storagePrefix)) return null;
    final path = source.substring(storagePrefix.length);
    final cached = _signed[path];
    if (cached != null && DateTime.now().isBefore(cached.$2)) return ImageRequest(cached.$1);
    final url = await client.storage.from('photos').createSignedUrl(path, _signedUrlLife.inSeconds);
    final uri = Uri.parse(url);
    _signed[path] = (uri, DateTime.now().add(_signedUrlReuse));
    return ImageRequest(uri);
  }
}
