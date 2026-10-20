import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/rast_colors.dart';
import '../../core/theme/rast_theme.dart';
import '../../core/ui/ui.dart';
import '../profile/profile_notifier.dart';
import 'onboarding_scaffold.dart';
import 'photo_grid.dart';
import 'photo_picker.dart';

/// Setup step 4, or the Profile → Edit photos editor when [editing].
class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key, this.editing = false});
  final bool editing;

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  String? _error;

  Future<void> _pick(int slot) async {
    try {
      final path = await ref.read(photoPickerProvider)();
      if (path == null || !mounted) return;
      ref.read(profileProvider.notifier).setPhoto(slot, path);
      setState(() => _error = null);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'This photo could not be opened. Try another file.');
    }
  }

  void _continue() {
    if (!ref.read(profileProvider).photosComplete) {
      setState(() => _error = widget.editing ? 'All four photos are required.' : 'Add four photos to continue.');
      return;
    }
    if (widget.editing) {
      showToast(context, 'Your photos have been updated in this preview.');
      context.pop();
    } else {
      context.push('/setup/location');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final profile = ref.watch(profileProvider);
    final count = profile.photoCount;
    return OnboardingScaffold(
      headerTitle: widget.editing ? 'Your photos' : 'Your first impression',
      step: widget.editing ? 0 : 4,
      headline: 'Four photos.\nAll you.',
      copy: 'Let people see the person behind the profile.\nYour first photo leads the way.',
      body: [
        PhotoGrid(
          photos: profile.photos,
          onPick: _pick,
          onRemove: (i) => ref.read(profileProvider.notifier).setPhoto(i, null),
        ),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Four photos required.', style: rastStyle(size: 12, weight: 450, color: c.body))),
            Text('$count of 4 added', style: rastStyle(size: 12, weight: 750, color: c.accent)),
          ],
        ),
        if (kDebugMode)
          Align(
            alignment: Alignment.centerLeft,
            child: TextLinkButton(
              label: 'Use sample photos (debug)',
              size: 12,
              onPressed: () {
                ref.read(profileProvider.notifier).useSamplePhotos();
                setState(() => _error = null);
              },
            ),
          ),
        FormError(_error),
      ],
      footer: Column(
        children: [
          PrimaryButton(label: widget.editing ? 'Save photos' : 'Continue', onPressed: count < 4 ? null : _continue),
          const SizedBox(height: 13),
          Text('Use clear, recent photos of yourself.', textAlign: TextAlign.center, style: RastText.tiny(c)),
        ],
      ),
    );
  }
}
