import 'package:bukidbayan_app/models/dashboard_calendar.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/screens/rent/rent_screen.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/dashboard_calendar_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardCalendarSection extends StatefulWidget {
  final String? currentUserId;
  final DashboardCalendarController? controller;
  final DateTime? initialMonth;
  final String region;
  final bool showHeader;

  const DashboardCalendarSection({
    super.key,
    required this.currentUserId,
    this.controller,
    this.initialMonth,
    this.region = 'philippines',
    this.showHeader = true,
  });

  @override
  State<DashboardCalendarSection> createState() =>
      _DashboardCalendarSectionState();
}

class _DashboardCalendarSectionState extends State<DashboardCalendarSection> {
  late final DashboardCalendarController _controller;
  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? DashboardCalendarService();
    final now = widget.initialMonth ?? DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.currentUserId;
    if (userId == null) {
      return _buildCard(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Mag-sign in para makita ang iyong matalinong kalendaryo.',
          ),
        ),
      );
    }

    return StreamBuilder<DashboardCalendarContext>(
      stream: _controller.watchCalendar(userId: userId, region: widget.region),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Hindi ma-load ang kalendaryo: ${snapshot.error}'),
            ),
          );
        }

        final contextData = snapshot.data;
        if (contextData == null) {
          return _buildCard(
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Wala pang datos sa kalendaryo.'),
            ),
          );
        }

        final monthData = _controller.buildMonthData(
          month: _visibleMonth,
          context: contextData,
        );

        final selectedDate = _dayKey(_selectedDay);
        final selectedDayData =
            monthData.daysByDate[selectedDate] ??
            monthData.daysByDate.values.first;

        return _buildCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showHeader) ...[
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Smart Calendar',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                _buildMonthHeader(),
                const SizedBox(height: 10),
                _buildWeekdayHeader(),
                const SizedBox(height: 8),
                _buildMonthGrid(monthData),
                const SizedBox(height: 14),
                if (contextData.demandForecast != null) ...[
                  _buildDemandForecastPanel(contextData.demandForecast!),
                  const SizedBox(height: 14),
                ],
                _buildSelectedDayPanel(selectedDayData),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
                1,
              );
              _selectedDay = _visibleMonth;
            });
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_visibleMonth),
            key: const Key('dashboard_calendar_month_label'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
                1,
              );
              _selectedDay = _visibleMonth;
            });
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildMonthGrid(DashboardCalendarMonthData monthData) {
    final monthStart = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = monthStart.weekday % 7;
    final totalItems = leadingBlanks + daysInMonth;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalItems,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        if (index < leadingBlanks) {
          return const SizedBox.shrink();
        }

        final dayOfMonth = index - leadingBlanks + 1;
        final date = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          dayOfMonth,
        );
        final dayData = monthData.daysByDate[date];
        if (dayData == null) return const SizedBox.shrink();

        final isSelected = _dayKey(_selectedDay) == date;
        final isToday = _dayKey(DateTime.now()) == date;

        return InkWell(
          key: Key('dashboard_calendar_day_${_dateKeyLabel(date)}'),
          onTap: () {
            setState(() {
              _selectedDay = date;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? Colors.green.shade600
                    : isToday
                    ? Colors.blue.shade300
                    : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$dayOfMonth',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.green.shade800 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  alignment: WrapAlignment.center,
                  children: dayData.markers
                      .map(
                        (marker) => Container(
                          key: Key(
                            'dashboard_calendar_marker_${marker.name}_${_dateKeyLabel(date)}',
                          ),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _markerColor(marker),
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedDayPanel(DashboardCalendarDayData dayData) {
    final formattedDate = DateFormat('EEE, MMM d').format(dayData.date);
    final suggestions = dayData.suggestions;

    return Container(
      key: const Key('dashboard_calendar_day_detail_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Napiling araw: $formattedDate',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (dayData.events.isNotEmpty) ...[
            ...dayData.events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _eventIcon(event.type),
                      size: 15,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${event.title}: ${event.subtitle}',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            const Text(
              'Walang mga kaganapan para sa araw na ito.',
              style: TextStyle(fontSize: 12.5),
            ),
          const SizedBox(height: 10),
          const Text(
            'Mga Mungkahing Aksyon',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (suggestions.isEmpty)
            const Text(
              'Walang kailangang aksyon.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...suggestions.map(_buildSuggestionCard),
        ],
      ),
    );
  }

  Widget _buildDemandForecastPanel(DemandForecastSnapshot snapshot) {
    final weekRange =
        '${DateFormat('MMM d').format(snapshot.weekStart)} - '
        '${DateFormat('MMM d').format(snapshot.weekEnd)}';

    return Container(
      key: const Key('dashboard_calendar_demand_forecast_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Demand Forecast',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _confidenceColor(
                    snapshot.confidence,
                  ).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _confidenceLabel(snapshot.confidence),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _confidenceColor(snapshot.confidence),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$weekRange • ${snapshot.locationLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(snapshot.summary, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          if (!snapshot.hasInsights)
            const Text(
              'Maglagay pa ng booking details tulad ng crop type, farming phase, at intended use para luminaw ang demand forecast.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...snapshot.insights.map(_buildForecastInsightCard),
        ],
      ),
    );
  }

  Widget _buildForecastInsightCard(DemandForecastInsight insight) {
    final levelColor = _forecastLevelColor(insight.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: levelColor.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  insight.equipmentCategory,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _forecastLevelLabel(insight.level),
                  style: TextStyle(
                    color: levelColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(insight.recommendation, style: const TextStyle(fontSize: 12)),
          if (insight.drivers.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...insight.drivers.map(
              (driver) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 7, color: levelColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        driver,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            key: Key(
              'dashboard_calendar_forecast_action_${insight.equipmentCategory}',
            ),
            onPressed: () => _handleAction(
              DashboardCalendarActionTarget(
                kind: DashboardCalendarActionKind.openEquipmentCatalog,
                label: 'Browse Equipment',
                categoryFilter: insight.equipmentCategory,
                searchQuery: insight.equipmentCategory,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Browse Equipment'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(DashboardCalendarSuggestion suggestion) {
    final actionTargets = <DashboardCalendarActionTarget>[
      if (suggestion.actionTarget != null) suggestion.actionTarget!,
      if (suggestion.secondaryActionTarget != null)
        suggestion.secondaryActionTarget!,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _priorityColor(suggestion.priority).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _priorityColor(suggestion.priority).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
          const SizedBox(height: 3),
          Text(suggestion.description, style: const TextStyle(fontSize: 12)),
          if (actionTargets.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actionTargets
                  .asMap()
                  .entries
                  .map((entry) {
                    final index = entry.key;
                    final actionTarget = entry.value;
                    return OutlinedButton(
                      key: Key(
                        'dashboard_calendar_action_${suggestion.type.name}_${actionTarget.kind.name}_$index',
                      ),
                      onPressed: () => _handleAction(actionTarget),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: Text(actionTarget.label),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleAction(DashboardCalendarActionTarget action) async {
    switch (action.kind) {
      case DashboardCalendarActionKind.openRequest:
        final requestId = action.requestId;
        if (requestId == null || !mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RequestSentPage(requestId: requestId),
          ),
        );
        break;
      case DashboardCalendarActionKind.openMyRequests:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RentalsList(mode: RentalsListMode.myRequests),
          ),
        );
        break;
      case DashboardCalendarActionKind.openIncomingRequests:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const RentalsList(mode: RentalsListMode.incomingRequests),
          ),
        );
        break;
      case DashboardCalendarActionKind.openEquipmentCatalog:
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RentScreen(
              initialSearchQuery: action.searchQuery,
              initialCategory: action.categoryFilter,
              initialRecommendedOnly: action.recommendedOnly,
            ),
          ),
        );
        break;
      case DashboardCalendarActionKind.openEquipmentItem:
        final equipmentId = action.equipmentId;
        if (equipmentId == null || equipmentId.isEmpty) return;
        try {
          final equipmentDoc = await FirestoreService().getEquipmentById(
            equipmentId,
          );
          if (!equipmentDoc.exists || !mounted) return;
          final equipment = Equipment.fromFirestore(equipmentDoc);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductPage(item: equipment)),
          );
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hindi ma-buksan ang kagamitan sa ngayon.'),
            ),
          );
        }
        break;
    }
  }

  IconData _eventIcon(DashboardCalendarEventType type) {
    switch (type) {
      case DashboardCalendarEventType.booking:
        return Icons.event_available_rounded;
      case DashboardCalendarEventType.weatherRisk:
        return Icons.thunderstorm_rounded;
      case DashboardCalendarEventType.season:
        return Icons.eco_rounded;
    }
  }

  Color _priorityColor(DashboardCalendarSuggestionPriority priority) {
    switch (priority) {
      case DashboardCalendarSuggestionPriority.high:
        return Colors.red.shade700;
      case DashboardCalendarSuggestionPriority.medium:
        return Colors.orange.shade700;
      case DashboardCalendarSuggestionPriority.low:
        return Colors.blue.shade700;
    }
  }

  Color _markerColor(DashboardCalendarMarker marker) {
    switch (marker) {
      case DashboardCalendarMarker.booking:
        return Colors.green.shade700;
      case DashboardCalendarMarker.weatherRisk:
        return Colors.red.shade700;
      case DashboardCalendarMarker.season:
        return Colors.blue.shade600;
      case DashboardCalendarMarker.actionNeeded:
        return Colors.amber.shade700;
    }
  }

  Color _forecastLevelColor(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return Colors.red.shade700;
      case DemandForecastLevel.medium:
        return Colors.orange.shade700;
      case DemandForecastLevel.low:
        return Colors.blue.shade700;
    }
  }

  String _forecastLevelLabel(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return 'High Demand';
      case DemandForecastLevel.medium:
        return 'Medium Demand';
      case DemandForecastLevel.low:
        return 'Early Signal';
    }
  }

  Color _confidenceColor(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return Colors.green.shade700;
      case DemandForecastConfidence.medium:
        return Colors.orange.shade700;
      case DemandForecastConfidence.low:
        return Colors.blueGrey.shade700;
    }
  }

  String _confidenceLabel(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return 'High confidence';
      case DemandForecastConfidence.medium:
        return 'Medium confidence';
      case DemandForecastConfidence.low:
        return 'Early forecast';
    }
  }

  static DateTime _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateKeyLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
