import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/widgets/user_avatar.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('UserAvatar', () {
    testWidgets('shows the first initial when there is no photo', (t) async {
      await t.pumpWidget(
        wrap(const UserAvatar(photoUrl: '', displayName: 'Alice')),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('uppercases a lowercase name', (t) async {
      await t.pumpWidget(
        wrap(const UserAvatar(photoUrl: '', displayName: 'bob')),
      );

      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('falls back to ? for an empty name', (t) async {
      await t.pumpWidget(
        wrap(const UserAvatar(photoUrl: '', displayName: '')),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('honours the requested radius', (t) async {
      await t.pumpWidget(
        wrap(const UserAvatar(photoUrl: '', displayName: 'A', radius: 34)),
      );

      final avatar = t.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 34);
    });

    testWidgets('scales the initial with the radius', (t) async {
      await t.pumpWidget(
        wrap(const UserAvatar(photoUrl: '', displayName: 'A', radius: 12)),
      );
      final small = t.widget<Text>(find.text('A')).style!.fontSize!;

      await t.pumpWidget(
        wrap(const UserAvatar(photoUrl: '', displayName: 'A', radius: 34)),
      );
      final large = t.widget<Text>(find.text('A')).style!.fontSize!;

      expect(large, greaterThan(small));
    });
  });
}
