import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cs261_project/theme/app_colors.dart';
import 'package:cs261_project/utils/email_validator.dart';
import 'package:cs261_project/widget/app_avatar.dart';
import 'package:cs261_project/widget/app_section.dart';

// These cover the pieces that run without Firebase. Screens that talk to
// Firestore are exercised by the rules tests (npm run test:rules) instead.
void main() {
  group('EmailValidator', () {
    test('accepts normal addresses, with surrounding spaces trimmed', () {
      expect(EmailValidator.isValid('demo.student@demo.edu'), isTrue);
      expect(EmailValidator.isValid('  first.last+tag@uni.ac.in  '), isTrue);
    });

    test('rejects malformed addresses', () {
      for (final bad in [null, '', '   ', 'no-at-sign.com', 'a@b', '@domain.com', 'two@@at.com', 'name@domain.c']) {
        expect(EmailValidator.isValid(bad), isFalse, reason: 'should reject "$bad"');
      }
    });

    test('normalize trims and lower-cases', () {
      expect(EmailValidator.normalize('  Demo.Student@Demo.EDU '), 'demo.student@demo.edu');
    });
  });

  group('AppAvatar helpers', () {
    test('initials come from the first two name parts', () {
      expect(AppAvatar.initialsOf('Aadeesh Surana'), 'AS');
      expect(AppAvatar.initialsOf('demo'), 'D');
      expect(AppAvatar.initialsOf('demo.alumni@demo.edu'), 'DA');
      expect(AppAvatar.initialsOf('   '), '?');
    });

    test('colour is stable for a name and always from the brand palette', () {
      expect(AppAvatar.colorFor('Aadeesh'), AppAvatar.colorFor('Aadeesh'));
      expect(AppAvatar.colorFor('  aadeesh '), AppAvatar.colorFor('Aadeesh'));
      for (final name in ['Alice', 'Bob', 'Carol', 'Dave', 'Erin', 'Frank', 'Grace']) {
        expect(AppColors.avatarPalette, contains(AppAvatar.colorFor(name)));
      }
    });
  });

  group('widgets', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

    testWidgets('AppAvatar shows initials when there is no photo', (tester) async {
      await tester.pumpWidget(wrap(const AppAvatar(name: 'Demo Alumni', imageUrl: '')));
      expect(find.text('DA'), findsOneWidget);
    });

    testWidgets('RoleBadge shows the role in capitals', (tester) async {
      await tester.pumpWidget(wrap(const RoleBadge(role: 'alumni')));
      expect(find.text('ALUMNI'), findsOneWidget);
    });

    testWidgets('RoleBadge falls back to MEMBER for an empty role', (tester) async {
      await tester.pumpWidget(wrap(const RoleBadge(role: '')));
      expect(find.text('MEMBER'), findsOneWidget);
    });
  });
}
