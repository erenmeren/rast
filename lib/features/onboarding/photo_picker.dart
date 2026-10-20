import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Returns a picked image path or null when cancelled. Overridable in tests.
typedef PhotoPicker = Future<String?> Function();

final photoPickerProvider = Provider<PhotoPicker>((ref) {
  return () async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 90);
    return file?.path;
  };
});
