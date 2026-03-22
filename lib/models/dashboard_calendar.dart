import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/weather_service.dart';

enum DashboardCalendarMarker { booking, weatherRisk, season, actionNeeded }

enum DashboardCalendarEventType { booking, weatherRisk, season }

enum DashboardCalendarSuggestionType {
  weatherRisk,
  overdueReturn,
  overdueRetrieval,
  incomingRequestReview,
  bookingPreparation,
  seasonalPlanning,
}

enum DashboardCalendarSuggestionPriority { low, medium, high }

enum DashboardCalendarActionKind {
  openRequest,
  openMyRequests,
  openIncomingRequests,
}

class DashboardCalendarActionTarget {
  final DashboardCalendarActionKind kind;
  final String label;
  final String? requestId;

  const DashboardCalendarActionTarget({
    required this.kind,
    required this.label,
    this.requestId,
  });
}

class DashboardCalendarEvent {
  final DashboardCalendarEventType type;
  final String title;
  final String subtitle;
  final String? requestId;

  const DashboardCalendarEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    this.requestId,
  });
}

class DashboardCalendarSuggestion {
  final DashboardCalendarSuggestionType type;
  final String title;
  final String description;
  final DashboardCalendarSuggestionPriority priority;
  final DashboardCalendarActionTarget? actionTarget;

  const DashboardCalendarSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.priority,
    this.actionTarget,
  });
}

class DashboardCalendarDayData {
  final DateTime date;
  final List<DashboardCalendarEvent> events;
  final List<DashboardCalendarSuggestion> suggestions;

  const DashboardCalendarDayData({
    required this.date,
    this.events = const [],
    this.suggestions = const [],
  });

  List<DashboardCalendarMarker> get markers {
    final hasBooking = events.any(
      (e) => e.type == DashboardCalendarEventType.booking,
    );
    final hasWeatherRisk = events.any(
      (e) => e.type == DashboardCalendarEventType.weatherRisk,
    );
    final hasSeason = events.any(
      (e) => e.type == DashboardCalendarEventType.season,
    );
    final hasActionNeeded = suggestions.isNotEmpty;

    return [
      if (hasBooking) DashboardCalendarMarker.booking,
      if (hasWeatherRisk) DashboardCalendarMarker.weatherRisk,
      if (hasSeason) DashboardCalendarMarker.season,
      if (hasActionNeeded) DashboardCalendarMarker.actionNeeded,
    ];
  }
}

class DashboardCalendarContext {
  final String userId;
  final List<RentRequest> requests;
  final List<WeatherDay> forecast;
  final String season;
  final List<String> seasonalCrops;
  final Map<String, List<String>> cropsBySeason;
  final Map<int, List<String>> cropsByMonth;

  const DashboardCalendarContext({
    required this.userId,
    required this.requests,
    required this.forecast,
    required this.season,
    required this.seasonalCrops,
    this.cropsBySeason = const {},
    this.cropsByMonth = const {},
  });
}

class DashboardCalendarMonthData {
  final DateTime month;
  final Map<DateTime, DashboardCalendarDayData> daysByDate;
  final String season;
  final List<String> seasonalCrops;

  const DashboardCalendarMonthData({
    required this.month,
    required this.daysByDate,
    required this.season,
    required this.seasonalCrops,
  });
}
