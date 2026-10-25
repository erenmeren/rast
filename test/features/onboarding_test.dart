import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/rules/rules.dart';
import 'package:rast/core/ui/ui.dart';
import 'package:rast/features/auth/phone_page.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/onboarding/about_you_page.dart';
import 'package:rast/features/onboarding/photo_picker.dart';
import 'package:rast/features/profile/profile_notifier.dart';

import '../helpers/app.dart';

Future<void> tapPrimary(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(PrimaryButton, label));
  await tester.pumpAndSettle();
}

void main() {
  test('phone validation matches the prototype', () {
    expect(validatePhone('+44', '123'), 'Enter a valid phone number.');
    expect(validatePhone('+44', '7700 900 123'), isNull);
    expect(validatePhone('+90', '05321234567'), 'Enter a 10-digit number without the leading zero.');
    expect(validatePhone('+90', '5321234567'), isNull);
  });

  test('birth date validation: exact 18 check, real calendar dates, 130-year guard', () {
    final today = DateTime.utc(2026, 10, 25);
    expect(validateBirthDateInput('25', '10', '2008', today), isNull);
    expect(validateBirthDateInput('26', '10', '2008', today), 'You must be 18 or older to use rast.');
    expect(validateBirthDateInput(' 14 ', '5', '1998', today), isNull);
    expect(validateBirthDateInput('', '', '', today), 'Enter your birth date as day, month and year.');
    expect(validateBirthDateInput('31', '2', '2000', today), 'Enter your birth date as day, month and year.');
    expect(validateBirthDateInput('14', '13', '1998', today), 'Enter your birth date as day, month and year.');
    expect(validateBirthDateInput('14', '5', '98', today), 'Enter your birth date as day, month and year.');
    expect(validateBirthDateInput('1', '1', '1890', today), 'Enter a valid birth date.');
    expect(validateBirthDateInput('1', '1', '2030', today), 'Enter a valid birth date.');
    expect(parseBirthDate('14', '5', '1998'), DateTime.utc(1998, 5, 14));
    expect(parseBirthDate('31', '2', '2000'), isNull);
  });

  testWidgets('full signup flow ends at the required introduction', (tester) async {
    final c = await testContainer();
    await pumpRast(tester, c);
    expect(find.text("Let's get you out there"), findsOneWidget);
    await tapPrimary(tester, "Let's get you out there");
    expect(currentPath(c), '/auth/phone');

    await tester.enterText(find.bySemanticsLabel('Phone number').last, '123');
    await tapPrimary(tester, 'Send code');
    expect(find.text('Enter a valid phone number.'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Phone number').last, '7700 900 123');
    await tapPrimary(tester, 'Send code');
    expect(currentPath(c), '/auth/verify');
    expect(find.text('Demo SMS code: 246810. No real SMS is sent.'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Verification code').last, '000000');
    await tapPrimary(tester, 'Verify');
    expect(find.text('That code does not match. Use 246810 for this prototype.'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Verification code').last, '246810');
    await tapPrimary(tester, 'Verify');
    expect(currentPath(c), '/setup/about');
    expect(c.read(sessionProvider).verified, isTrue);

    // No gender preselected.
    expect(c.read(profileProvider).gender, isNull);
    await tester.enterText(find.bySemanticsLabel('Day').last, '14');
    await tester.enterText(find.bySemanticsLabel('Month').last, '5');
    await tester.enterText(find.bySemanticsLabel('Year').last, '2012');
    await tapPrimary(tester, 'Continue');
    expect(find.text('You must be 18 or older to use rast.'), findsOneWidget);
    await tester.enterText(find.bySemanticsLabel('Year').last, '1998');
    await tapPrimary(tester, 'Continue');
    expect(find.text('Select your gender to continue.'), findsOneWidget);
    await tester.tap(find.text('Self-describe'));
    await tester.pumpAndSettle();
    await tapPrimary(tester, 'Continue');
    expect(find.text('Describe your gender in your own words.'), findsOneWidget);
    await tester.tap(find.text('Woman'));
    await tester.pumpAndSettle();
    await tapPrimary(tester, 'Continue');
    expect(currentPath(c), '/setup/preferences');
    expect(c.read(profileProvider).birthDate, DateTime.utc(1998, 5, 14));
    expect(c.read(profileProvider).age, ageOn(DateTime.utc(1998, 5, 14), DateTime.now().toUtc()));

    // Deselecting Everyone leaves nothing selected.
    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Women'));
    await tester.pumpAndSettle();
    await tapPrimary(tester, 'Continue');
    expect(find.text('Choose at least one dating preference.'), findsOneWidget);
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();
    await tapPrimary(tester, 'Continue');
    expect(currentPath(c), '/setup/photos');

    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Continue')).onPressed, isNull);
    expect(find.text('0 of 4 added'), findsOneWidget);
    c.read(profileProvider.notifier).useSamplePhotos();
    await tester.pumpAndSettle();
    expect(find.text('4 of 4 added'), findsOneWidget);
    expect(find.text('MAIN PHOTO'), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('3 of 4 added'), findsOneWidget);
    expect(tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Continue')).onPressed, isNull);
    c.read(profileProvider.notifier).useSamplePhotos();
    await tester.pumpAndSettle();
    await tapPrimary(tester, 'Continue');
    expect(currentPath(c), '/setup/location');

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).phase, SessionPhase.introPending);
    expect(currentPath(c), '/intro');
  });

  testWidgets('picking a photo fills the tapped slot', (tester) async {
    final c = await testContainer(extra: [photoPickerProvider.overrideWithValue(() async => 'assets/photos/portrait-8.jpg')]);
    c.read(sessionProvider.notifier).startSignup();
    await pumpRast(tester, c, initialLocation: '/setup/photos');
    await tester.tap(find.byKey(const Key('photo-slot-2')));
    await tester.pumpAndSettle();
    expect(c.read(profileProvider).photos[2], 'assets/photos/portrait-8.jpg');
    expect(find.text('1 of 4 added'), findsOneWidget);
  });

  testWidgets('terms and privacy open from Welcome', (tester) async {
    final c = await testContainer();
    await pumpRast(tester, c);
    await tester.ensureVisible(find.text('Terms'));
    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();
    expect(find.text('A good place to start.'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy information'));
    await tester.tap(find.text('Privacy information'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy comes first.'), findsOneWidget);
  });
}
