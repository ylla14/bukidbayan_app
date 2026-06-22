class AnalyticsTimeWindow {
  final DateTime start;
  final DateTime end;

  AnalyticsTimeWindow({required this.start, required this.end})
    : assert(!end.isBefore(start), 'end must be on or after start');

  DateTime get startOfDay => DateTime(start.year, start.month, start.day);

  DateTime get endExclusive =>
      DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

  double get totalHours =>
      endExclusive.difference(startOfDay).inHours.toDouble();
}
