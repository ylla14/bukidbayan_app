import 'package:bukidbayan_app/components/dashboard/dashboard_calendar_section.dart';
import 'package:bukidbayan_app/models/dashboard_calendar.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/dashboard_calendar_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows day details and suggestion for selected calendar day', (
    tester,
  ) async {
    final contextData = DashboardCalendarContext(
      userId: 'user-1',
      requests: [
        RentRequest(
          requestId: 'req-1',
          itemId: 'item-1',
          itemName: 'Harvester',
          name: 'Requester',
          address: 'Laguna',
          start: DateTime(2026, 3, 10),
          end: DateTime(2026, 3, 12),
          status: RentRequestStatus.approved,
          renterId: 'user-1',
          ownerId: 'owner-1',
          weatherFlag: true,
          weatherFlagDates: [DateTime(2026, 3, 11)],
        ),
      ],
      forecast: [
        WeatherDay(
          date: DateTime(2026, 3, 11),
          weatherCode: 95,
          precipitationMm: 25,
          windSpeedMaxKmh: 65,
          precipitationProbabilityMax: 90,
          tempMaxC: 30,
        ),
      ],
      season: 'Dry Season',
      seasonalCrops: ['Corn'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardCalendarSection(
              currentUserId: 'user-1',
              controller: _FakeDashboardCalendarController(contextData),
              initialMonth: DateTime(2026, 3, 1),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Smart Calendar'), findsOneWidget);
    expect(
      find.byKey(const Key('dashboard_calendar_day_2026-03-11')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('dashboard_calendar_day_2026-03-11')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard_calendar_day_detail_panel')),
      findsOneWidget,
    );
    expect(find.textContaining('Weather risk on booking day'), findsOneWidget);
    expect(find.textContaining('Harvester'), findsWidgets);
  });
}

class _FakeDashboardCalendarController implements DashboardCalendarController {
  final DashboardCalendarContext context;
  final DashboardCalendarService _delegate = DashboardCalendarService();

  _FakeDashboardCalendarController(this.context);

  @override
  Stream<DashboardCalendarContext> watchCalendar({
    required String userId,
    String region = 'philippines',
  }) {
    return Stream<DashboardCalendarContext>.value(context);
  }

  @override
  DashboardCalendarMonthData buildMonthData({
    required DateTime month,
    required DashboardCalendarContext context,
    DateTime? now,
  }) {
    return _delegate.buildMonthData(month: month, context: context, now: now);
  }
}
