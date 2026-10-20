import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';

Future<void> showTermsSheet(BuildContext context) => showRastSheet<void>(
      context,
      title: 'A good place to start.',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PolicySection(text: 'This is a product design preview, not a published service agreement.'),
          const PolicySection(
            heading: 'For adults, 18 and over.',
            text: 'Setup blocks entered ages below 18. Self-reported age and phone verification are not a production age-assurance system.',
          ),
          const PolicySection(
            heading: 'Be yourself. Respect boundaries.',
            text: "Use your own photos. Respect other people's choices. Report or block profiles that concern you.",
          ),
          const PolicySection(
            heading: 'Connection is a mutual choice.',
            text: 'Chat starts after you both like each other. Either person can remove a connection permanently. Removed connections cannot match again. Free mutual matching does not require a subscription.',
          ),
          const SizedBox(height: 8),
          PrimaryButton(label: 'Got it', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );

Future<void> showPrivacySheet(BuildContext context) => showRastSheet<void>(
      context,
      title: 'Privacy comes first.',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PolicySection(text: 'This design preview does not collect real locations, send SMS or deliver messages to another person.'),
          const PolicySection(
            heading: 'Your location stays yours.',
            text: 'Exact locations, map pins, distances and crossing times are not shown to other people. The longer privacy delay always applies, even with Premium.',
          ),
          const PolicySection(
            heading: 'Only the essentials.',
            text: 'Setup asks for a phone number, your own age and gender, dating preferences and four photos. No name, occupation, religion or biography is required.',
          ),
          const PolicySection(
            heading: 'In this preview',
            text: 'Chats and Premium access stay in memory and reset when you relaunch. Your age, gender, photos, preferences, timing, notification and appearance choices, the introduction status, and blocked or removed sample profiles are saved on this device. Report reasons are saved; optional report details are not. Removed connections cannot match again in this preview.',
          ),
          const PolicySection(text: 'Profiles are fictional and photos are stock placeholders. The people pictured are not app users.'),
          const SizedBox(height: 8),
          PrimaryButton(label: 'Got it', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
