import 'package:bukidbayan_app/components/dashboard/crops_in_season_section.dart';
import 'package:bukidbayan_app/services/crop_calendar_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'current filter uses month-aware crops and hides out-of-window crops',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CropsInSeasonSection(
                cropCalendarService: CropCalendarService(apiUrl: ''),
                nowProvider: () => DateTime(2026, 1, 15),
                currentUserIdProvider: () => null,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rice (Dry Season)'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Rice (Wet Season)'), findsNothing);
    },
  );

  testWidgets('wet season chip shows wet-season crops only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CropsInSeasonSection(
              cropCalendarService: CropCalendarService(apiUrl: ''),
              nowProvider: () => DateTime(2026, 1, 15),
              currentUserIdProvider: () => null,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Wet Season'));
    await tester.pump();

    expect(find.text('Rice (Wet Season)'), findsOneWidget);
    expect(find.text('Rice (Dry Season)'), findsNothing);
    expect(find.text('Pechay'), findsNothing);
  });
}
