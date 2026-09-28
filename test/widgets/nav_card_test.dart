import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_league/theme/app_colors.dart';
import 'package:prediction_league/widgets/nav_card.dart';

class _Destination extends StatelessWidget {
  const _Destination();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('destination reached'));
}

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

NavCard card({WidgetBuilder? builder}) => NavCard(
      icon: Icons.sports_soccer,
      iconColor: AppColors.accent,
      title: 'Premier League Fixtures',
      subtitle: 'Tap to view matches',
      builder: builder ?? (_) => const _Destination(),
    );

void main() {
  group('NavCard', () {
    testWidgets('renders its title, subtitle and icon', (t) async {
      await t.pumpWidget(wrap(card()));

      expect(find.text('Premier League Fixtures'), findsOneWidget);
      expect(find.text('Tap to view matches'), findsOneWidget);
      expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('navigates to the destination when tapped', (t) async {
      await t.pumpWidget(wrap(card()));

      await t.tap(find.byType(NavCard));
      await t.pumpAndSettle();

      expect(find.text('destination reached'), findsOneWidget);
    });

    testWidgets('does not build the destination until tapped', (t) async {
      var built = 0;
      await t.pumpWidget(
        wrap(
          card(
            builder: (_) {
              built++;
              return const _Destination();
            },
          ),
        ),
      );

      expect(built, 0, reason: 'destination built eagerly');

      await t.tap(find.byType(NavCard));
      await t.pumpAndSettle();

      expect(built, 1);
    });

    testWidgets('exposes itself as a button to screen readers', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(wrap(card()));

      expect(
        find.bySemanticsLabel('Premier League Fixtures. Tap to view matches'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
