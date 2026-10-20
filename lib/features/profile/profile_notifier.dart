import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../data/mock/mock_people.dart';

class ProfileNotifier extends Notifier<Profile> {
  @override
  Profile build() => ref.read(profileRepositoryProvider).load();

  void _set(Profile p) {
    state = p;
    ref.read(profileRepositoryProvider).save(p);
  }

  void setAge(int? age) => _set(state.copyWith(age: age, clearAge: age == null));
  void setGender(Gender? gender) => _set(state.copyWith(gender: gender, clearGender: gender == null));
  void setCustomGender(String text) => _set(state.copyWith(customGender: text));
  void setShowGender(bool value) => _set(state.copyWith(showGender: value));
  void setPhone(String dial, String phone) => _set(state.copyWith(dial: dial, phone: phone));

  void setPhoto(int slot, String? src) {
    final photos = List<String?>.of(state.photos);
    photos[slot] = src;
    _set(state.copyWith(photos: photos));
  }

  void setPhotos(List<String?> photos) => _set(state.copyWith(photos: List<String?>.of(photos)));
  void useSamplePhotos() => setPhotos(samplePhotos);

  void reset() {
    state = Profile.empty;
    ref.read(profileRepositoryProvider).clear();
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile>(ProfileNotifier.new);
