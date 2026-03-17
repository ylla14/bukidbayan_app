import 'package:bukidbayan_app/models/dashboard_calendar.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/dashboard_calendar_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardCalendarService buildMonthData', () {
    final service = DashboardCalendarService();

    test('aggregates booking, weather risk, season, and action markers', () {
      final context = DashboardCalendarContext(
        userId: 'user-1',
        requests: [
          _request(
            requestId: 'req-1',
            itemName: 'Harvester',
            renterId: 'user-1',
            ownerId: 'owner-1',
            start: DateTime(2026, 3, 10),
            end: DateTime(2026, 3, 12),
            status: RentRequestStatus.approved,
            weatherFlag: true,
            weatherFlagDates: [DateTime(2026, 3, 11)],
          ),
        ],
        forecast: [
          WeatherDay(
            date: DateTime(2026, 3, 11),
            weatherCode: 95,
            precipitationMm: 28,
            windSpeedMaxKmh: 61,
            precipitationProbabilityMax: 85,
            tempMaxC: 30,
          ),
        ],
        season: 'Dry Season',
        seasonalCrops: ['Corn', 'Peanut'],
      );

      final monthData = service.buildMonthData(
        month: DateTime(2026, 3, 1),
        context: context,
        now: DateTime(2026, 3, 10),
      );
      final day = monthData.daysByDate[DateTime(2026, 3, 11)];

      expect(day, isNotNull);
      expect(day!.markers, contains(DashboardCalendarMarker.booking));
      expect(day.markers, contains(DashboardCalendarMarker.weatherRisk));
      expect(day.markers, contains(DashboardCalendarMarker.season));
      expect(day.markers, contains(DashboardCalendarMarker.actionNeeded));
      expect(
        day.suggestions.any(
          (s) => s.type == DashboardCalendarSuggestionType.weatherRisk,
        ),
        isTrue,
      );
    });

    test('creates overdue suggestions for renter and owner roles', () {
      final context = DashboardCalendarContext(
        userId: 'user-1',
        requests: [
          _request(
            requestId: 'req-renter',
            itemName: 'Rice Mill',
            renterId: 'user-1',
            ownerId: 'owner-1',
            start: DateTime(2026, 3, 10),
            end: DateTime(2026, 3, 14),
            status: RentRequestStatus.inProgress,
          ),
          _request(
            requestId: 'req-owner',
            itemName: 'Hand Tractor',
            renterId: 'renter-2',
            ownerId: 'user-1',
            start: DateTime(2026, 3, 10),
            end: DateTime(2026, 3, 14),
            status: RentRequestStatus.inProgress,
          ),
        ],
        forecast: const [],
        season: 'Dry Season',
        seasonalCrops: const [],
      );

      final monthData = service.buildMonthData(
        month: DateTime(2026, 3, 1),
        context: context,
        now: DateTime(2026, 3, 16),
      );
      final today = monthData.daysByDate[DateTime(2026, 3, 16)];

      expect(today, isNotNull);
      expect(
        today!.suggestions.any(
          (s) => s.type == DashboardCalendarSuggestionType.overdueReturn,
        ),
        isTrue,
      );
      expect(
        today.suggestions.any(
          (s) => s.type == DashboardCalendarSuggestionType.overdueRetrieval,
        ),
        isTrue,
      );
    });

    test('uses day month for season and crop context (July -> Wet Season)', () {
      final context = DashboardCalendarContext(
        userId: 'user-1',
        requests: const [],
        forecast: const [],
        season: 'Dry Season',
        seasonalCrops: ['Corn'],
        cropsBySeason: const {
          'Dry Season': ['Corn'],
          'Wet Season': ['Rice'],
        },
      );

      final monthData = service.buildMonthData(
        month: DateTime(2026, 7, 1),
        context: context,
        now: DateTime(2026, 7, 10),
      );
      final day = monthData.daysByDate[DateTime(2026, 7, 10)];

      expect(day, isNotNull);
      final seasonEvent = day!.events.firstWhere(
        (e) => e.type == DashboardCalendarEventType.season,
      );
      expect(seasonEvent.title, 'Wet Season');
      expect(seasonEvent.subtitle, contains('Rice'));
    });
  });
}

RentRequest _request({
  required String requestId,
  required String itemName,
  required String renterId,
  required String ownerId,
  required DateTime start,
  required DateTime end,
  required RentRequestStatus status,
  bool weatherFlag = false,
  List<DateTime> weatherFlagDates = const [],
}) {
  return RentRequest(
    requestId: requestId,
    itemId: 'item-$requestId',
    itemName: itemName,
    name: 'Requester',
    address: 'Laguna',
    start: start,
    end: end,
    status: status,
    renterId: renterId,
    ownerId: ownerId,
    weatherFlag: weatherFlag,
    weatherFlagDates: weatherFlagDates,
  );
}
