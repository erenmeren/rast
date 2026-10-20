import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/ui/ui.dart';

/// Interests + one age range. Shared by setup and the preferences sheet.
class PreferencesForm extends StatelessWidget {
  const PreferencesForm({super.key, required this.value, required this.onChanged});

  final Preferences value;
  final ValueChanged<Preferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Who would you like to meet?'),
        const SizedBox(height: 12),
        OptionGroup(
          children: [
            for (final i in Interest.values)
              OptionChip(
                label: i.label,
                selected: value.interests.contains(i),
                onTap: () => onChanged(value.toggled(i)),
              ),
          ],
        ),
        const FormHelp('Choose more than one. Everyone includes all gender identities.'),
        const SizedBox(height: 28),
        AgeRangeSlider(
          minAge: value.minAge,
          maxAge: value.maxAge,
          onChanged: (min, max) => onChanged(value.withRange(min, max)),
        ),
        const SizedBox(height: 22),
        const InfoBox(
          icon: 'mark',
          strong: 'It goes both ways.',
          text: "You will only see people when you match each other's age and gender preferences.",
        ),
      ],
    );
  }
}
