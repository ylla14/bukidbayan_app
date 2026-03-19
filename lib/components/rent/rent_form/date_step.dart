import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/date_picker_field.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DateStep extends StatefulWidget {
  final Equipment item;
  final DateTime? startDate;
  final DateTime? returnDate;
  final Function(DateTime) onStartDatePicked;
  final Function(DateTime) onReturnDatePicked;
  final Function(double?)? onHectaresChanged;

  const DateStep({
    super.key,
    required this.item,
    this.startDate,
    this.returnDate,
    required this.onStartDatePicked,
    required this.onReturnDatePicked,
    this.onHectaresChanged,
  });

  @override
  State<DateStep> createState() => _DateStepState();
}

class _DateStepState extends State<DateStep> {
  List<Map<String, DateTime>> bookedRanges = [];
  List<DateTime> _badWeatherDays = [];
  bool isLoadingDates = true;

  final TextEditingController _hectaresController = TextEditingController();
  String? _hectaresError;

  // ── Per-category rates ───────────────────────────────────────────────────
  double get _hectaresPerDay {
    switch (widget.item.category?.toLowerCase()) {
      case 'hand tractor (kuliglig)': 
      case 'floating tiller (pagong)': 
      return 1.0;
      default:                          
      return 2.0; // tractor, harvester (halimaw)
    }
  }

  String get _equipmentLabel {
    switch (widget.item.category?.toLowerCase()) {
      case 'harvester (halimaw)':      return 'Harvester (Halimaw)';
      case 'hand tractor (kuliglig)':  return 'Hand Tractor (Kuliglig)';
      case 'floating tiller (pagong)': return 'Floating Tiller (Pagong)';
      default:                          return 'Tractor';
    }
  }

  // ── Auto-compute eligibility ─────────────────────────────────────────────
  bool get _isAutoComputedEquipment {
    final cat = widget.item.category?.toLowerCase();
    final isEligibleCategory = cat == 'tractor' ||
        cat == 'harvester (halimaw)' ||
        cat == 'hand tractor (kuliglig)' ||
        cat == 'floating tiller (pagong)';
    return isEligibleCategory && widget.item.landSizeRequirement;
  }

  double? get _minHa => double.tryParse(widget.item.landSizeMin ?? '');
  double? get _maxHa => double.tryParse(widget.item.landSizeMax ?? '');

  double? get _validatedHectares {
    final val = double.tryParse(_hectaresController.text.trim());
    if (val == null) return null;
    final min = _minHa;
    final max = _maxHa;
    if (min != null && val < min) return null;
    if (max != null && val > max) return null;
    return val;
  }

  int _daysNeeded(double hectares) =>
      (hectares / _hectaresPerDay).ceil().clamp(1, 9999);

  DateTime? _computedReturnDate(DateTime start, double hectares) {
    final days = _daysNeeded(hectares);
    return start.add(Duration(days: days - 1));
  }

  void _onHectaresChanged(String value) {
    final ha = double.tryParse(value.trim());
    String? error;
    if (value.trim().isEmpty) {
      error = null;
    } else if (ha == null) {
      error = 'Please enter a valid number.';
    } else {
      final min = _minHa;
      final max = _maxHa;
      if (min != null && ha < min) {
        error = 'Minimum land size is ${_formatHa(min)} ha.';
      } else if (max != null && ha > max) {
        error = 'Maximum land size is ${_formatHa(max)} ha.';
      }
    }

    setState(() => _hectaresError = error);

    if (error == null && ha != null && widget.startDate != null) {
      final returnDate = _computedReturnDate(widget.startDate!, ha);
      if (returnDate != null) {
        widget.onReturnDatePicked(returnDate);
      }
    }

    widget.onHectaresChanged?.call(error == null ? ha : null);
  }

  @override
  void didUpdateWidget(covariant DateStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate &&
        _isAutoComputedEquipment &&
        _validatedHectares != null) {
      final returnDate = _computedReturnDate(widget.startDate!, _validatedHectares!);
      if (returnDate != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onReturnDatePicked(returnDate);
        });
      }
    }
  }

  @override
  void dispose() {
    _hectaresController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadBookedDates();
    _loadWeatherDays();
  }

  Future<void> _loadWeatherDays() async {
    try {
      final forecast = await WeatherService().getOrFetchForecast();
      final bad = forecast
          .where((d) => d.isBadWeather)
          .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
          .toList();
      if (mounted) setState(() => _badWeatherDays = bad);
    } catch (_) {}
  }

  bool _isDateBadWeather(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _badWeatherDays.any((bad) => bad.isAtSameMomentAs(d));
  }

  Future<void> _loadBookedDates() async {
    if (widget.item.id == null) {
      if (mounted) setState(() => isLoadingDates = false);
      return;
    }
    try {
      final ranges = await FirestoreService().getBookedDateRanges(widget.item.id!);
      if (mounted) {
        setState(() {
          bookedRanges = ranges;
          isLoadingDates = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingDates = false);
    }
  }

  bool _isDateBooked(DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    for (var range in bookedRanges) {
      final start = DateTime(
          range['start']!.year, range['start']!.month, range['start']!.day);
      final end =
          DateTime(range['end']!.year, range['end']!.month, range['end']!.day);
      if ((checkDate.isAfter(start) || checkDate.isAtSameMomentAs(start)) &&
          (checkDate.isBefore(end) || checkDate.isAtSameMomentAs(end))) {
        return true;
      }
    }
    return false;
  }

  DateTime _findFirstAvailableDate(DateTime start, DateTime end) {
    DateTime current = DateTime(start.year, start.month, start.day);
    while (!current.isAfter(end)) {
      if (!_isDateBooked(current)) return current;
      current = current.add(const Duration(days: 1));
    }
    return start;
  }

  @override
  Widget build(BuildContext context) {
    final hasAvailabilityDates = widget.item.availableFrom != null &&
        widget.item.availableUntil != null;
    final isAutoComputed = _isAutoComputedEquipment;
    final bool returnIsComputed = isAutoComputed && _validatedHectares != null;
    final ha = _validatedHectares;
    final int? daysNeeded =
        (isAutoComputed && ha != null && widget.startDate != null)
            ? _daysNeeded(ha)
            : null;

    return Column(
      children: [
        const CustomDivider(),
        StepHeader(
          title: 'Step 1: Iskedyul ng Pag-upa',
          subtitle:
              'Piliin ang petsa at oras ng pickup at return. Ang return ay dapat hindi bababa sa 1 oras mula sa pickup.',
        ),

        if (isLoadingDates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text('Loading booked dates...',
                        style: TextStyle(color: Colors.blue.shade900)),
                  ],
                ),
              ),
            ),
          ),

        if (!hasAvailabilityDates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Hindi available ang equipment na ito - walang availability dates.',
                  style: TextStyle(
                      color: Colors.red.shade900, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

        if (bookedRanges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: Card(
                color: lightColorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'May mga petsa na ng naka-book:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: lightColorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      ...bookedRanges.map((range) => Text(
                            '${_formatDate(range['start']!)} - ${_formatDate(range['end']!)}',
                            style: TextStyle(color: lightColorScheme.primary),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),

        if (_badWeatherDays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            'Severe weather expected:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ..._badWeatherDays.map((d) => Text(_formatDate(d),
                          style: TextStyle(color: Colors.amber.shade800))),
                      const SizedBox(height: 4),
                      Text('These dates are blocked for booking.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.amber.shade700)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Date pickers ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: DatePickerField(
                label: 'Start / Pickup Date',
                value: widget.startDate,
                onTap: isLoadingDates || !hasAvailabilityDates
                    ? null
                    : () async {
                        final firestoreService = FirestoreService();
                        final leadTimeDate =
                            firestoreService.getEarliestBookingDate();
                        final earliest =
                            widget.item.availableFrom!.isAfter(leadTimeDate)
                                ? widget.item.availableFrom!
                                : leadTimeDate;
                        final last = widget.item.availableUntil!;
                        final effectiveStart = widget.startDate != null &&
                                widget.startDate!.isBefore(earliest)
                            ? earliest
                            : widget.startDate;
                        final initial = effectiveStart ??
                            _findFirstAvailableDate(earliest, last);

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: earliest,
                          lastDate: last,
                          selectableDayPredicate: (date) =>
                              !_isDateBooked(date) && !_isDateBadWeather(date),
                        );

                        if (picked != null) {
                          widget.onStartDatePicked(picked);
                          if (isAutoComputed && _validatedHectares != null) {
                            final ret =
                                _computedReturnDate(picked, _validatedHectares!);
                            if (ret != null) widget.onReturnDatePicked(ret);
                          }
                        }
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DatePickerField(
                label: 'Return',
                value: widget.returnDate,
                onTap: returnIsComputed ||
                        widget.startDate == null ||
                        isLoadingDates ||
                        !hasAvailabilityDates
                    ? null
                    : () async {
                        final initial = widget.returnDate ?? widget.startDate!;
                        final first = widget.startDate!;
                        final last = widget.item.availableUntil!;

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: first,
                          lastDate: last,
                          selectableDayPredicate: (date) =>
                              !_isDateBooked(date) && !_isDateBadWeather(date),
                        );

                        if (picked != null) {
                          if (picked.isBefore(widget.startDate!)) {
                            showErrorSnackbar(
                              context: context,
                              title: 'Invalid date',
                              message: 'Return date must be after pickup date',
                            );
                            return;
                          }
                          widget.onReturnDatePicked(picked);
                        }
                      },
              ),
            ),
          ],
        ),

        // ── Auto-computed equipment: hectare input ────────────────────────
        if (isAutoComputed && widget.startDate != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.agriculture, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Land Area',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    if (_minHa != null || _maxHa != null)
                      Text(
                        '(${_minHa != null ? '${_formatHa(_minHa!)} – ' : ''}${_maxHa != null ? '${_formatHa(_maxHa!)} ha' : ''})',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _hectaresController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Number of Hectares',
                    suffixText: 'ha',
                    errorText: _hectaresError,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onHectaresChanged,
                ),
                const SizedBox(height: 8),
            
                if (daysNeeded != null) ...[
                  Card(
                    color: lightColorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16,
                                  color: lightColorScheme.onPrimaryContainer),
                              const SizedBox(width: 6),
                              Text(
                                'Computed Rental Schedule',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: lightColorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _scheduleRow(
                            Icons.today,
                            'Start date',
                            _formatDate(widget.startDate!),
                            lightColorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 4),
                          _scheduleRow(
                            Icons.event,
                            'Return date',
                            _formatDate(widget.returnDate!),
                            lightColorScheme.onPrimaryContainer,
                          ),
                          const Divider(height: 16),
                          _scheduleRow(
                            Icons.calendar_month,
                            'Total days',
                            '$daysNeeded day${daysNeeded == 1 ? '' : 's'} '
                                '(${_formatHa(_validatedHectares!)} ha ÷ '
                                '${_formatHa(_hectaresPerDay)} ha/day)',
                            lightColorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The return date is automatically set based on '
                            '${_formatHa(_hectaresPerDay)} hectares covered per day '
                            'by the $_equipmentLabel, '
                            'starting from your pickup date '
                            '(${_formatDate(widget.startDate!)}). '
                            'Day 1 is your pickup date.',
                            style: TextStyle(
                              fontSize: 11,
                              color: lightColorScheme.onPrimaryContainer
                                  .withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            
                if (daysNeeded == null && _hectaresController.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Optional: Ilagay ang bilang ng ektarya para awtomatikong makuha ang petsa ng pagbabalik '
                    '(${_formatHa(_hectaresPerDay)} ha/day). '
                    'O maaari kang pumili ng return date nang mano-mano.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _scheduleRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(fontSize: 13, color: color)),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  String _formatHa(double ha) =>
      ha == ha.truncateToDouble() ? ha.toInt().toString() : ha.toString();
}