enum DemandForecastLevel { low, medium, high }

enum DemandForecastConfidence { low, medium, high }

class DemandForecastInsight {
  final String equipmentCategory;
  final double score;
  final DemandForecastLevel level;
  final int matchedRequests;
  final int recentRequests;
  final List<String> drivers;
  final String recommendation;

  const DemandForecastInsight({
    required this.equipmentCategory,
    required this.score,
    required this.level,
    required this.matchedRequests,
    required this.recentRequests,
    this.drivers = const [],
    required this.recommendation,
  });
}

class DemandForecastSnapshot {
  final DateTime generatedAt;
  final DateTime weekStart;
  final DateTime weekEnd;
  final String locationLabel;
  final String summary;
  final DemandForecastConfidence confidence;
  final List<DemandForecastInsight> insights;

  const DemandForecastSnapshot({
    required this.generatedAt,
    required this.weekStart,
    required this.weekEnd,
    required this.locationLabel,
    required this.summary,
    required this.confidence,
    this.insights = const [],
  });

  bool get hasInsights => insights.isNotEmpty;
}
