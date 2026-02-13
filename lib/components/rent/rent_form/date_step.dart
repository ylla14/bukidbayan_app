import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:bukidbayan_app/widgets/date_picker_field.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';

class DateStep extends StatefulWidget {
  final Equipment item;
  final DateTime? startDate;
  final DateTime? returnDate;
  final Function(DateTime) onStartDatePicked;
  final Function(DateTime) onReturnDatePicked;

  const DateStep({
    super.key,
    required this.item,
    this.startDate,
    this.returnDate,
    required this.onStartDatePicked,
    required this.onReturnDatePicked,
  });

  @override
  State<DateStep> createState() => _DateStepState();
}

class _DateStepState extends State<DateStep> {
  List<Map<String, DateTime>> bookedRanges = [];
  bool isLoadingDates = true;

  @override
  void initState() {
    super.initState();
    print('🔄 DateStep initialized for equipment: ${widget.item.id}');
    _loadBookedDates();
  }

  Future<void> _loadBookedDates() async {
    print('📅 Loading booked dates...');
    
    // ✅ Add null check for item.id
    if (widget.item.id == null) {
      print('⚠️ Equipment ID is null, skipping booked dates load');
      if (mounted) {
        setState(() => isLoadingDates = false);
      }
      return;
    }

    try {
      final firestoreService = FirestoreService();
      print('🔍 Fetching booked ranges for equipment: ${widget.item.id}');
      
      final ranges = await firestoreService.getBookedDateRanges(widget.item.id!);
      
      print('✅ Loaded ${ranges.length} booked date ranges');
      for (var range in ranges) {
        print('   📆 ${range['start']} → ${range['end']}');
      }
      
      if (mounted) {
        setState(() {
          bookedRanges = ranges;
          isLoadingDates = false;
        });
        print('✅ State updated: isLoadingDates = false, bookedRanges.length = ${ranges.length}');
      }
    } catch (e) {
      print('❌ Error loading booked dates: $e');
      if (mounted) {
        setState(() => isLoadingDates = false);
      }
    }
  }

  bool _isDateBooked(DateTime date) {
    // Normalize date to midnight for comparison
    final checkDate = DateTime(date.year, date.month, date.day);
    
    for (var range in bookedRanges) {
      final start = DateTime(
        range['start']!.year,
        range['start']!.month,
        range['start']!.day,
      );
      final end = DateTime(
        range['end']!.year,
        range['end']!.month,
        range['end']!.day,
      );
      
      // Check if date falls within or equals the booked range
      if ((checkDate.isAfter(start) || checkDate.isAtSameMomentAs(start)) &&
          (checkDate.isBefore(end) || checkDate.isAtSameMomentAs(end))) {
        print('🚫 Date ${_formatDate(date)} is BOOKED (falls in range ${_formatDate(range['start']!)} - ${_formatDate(range['end']!)})');
        return true;
      }
    }
    
    print('✅ Date ${_formatDate(date)} is AVAILABLE');
    return false;
  }

  DateTime _findFirstAvailableDate(DateTime start, DateTime end) {
  DateTime current = DateTime(start.year, start.month, start.day);

  while (!current.isAfter(end)) {
    if (!_isDateBooked(current)) {
      return current;
    }
    current = current.add(const Duration(days: 1));
  }

  return start; // fallback
}


  @override
  Widget build(BuildContext context) {
    final hasAvailabilityDates = widget.item.availableFrom != null && 
                                  widget.item.availableUntil != null;

    print('🎨 Building DateStep: isLoadingDates=$isLoadingDates, hasAvailabilityDates=$hasAvailabilityDates');

    return Column(
      children: [
        const CustomDivider(),
        StepHeader(
          title: 'Step 1: Iskedyul ng Pag-upa',
          subtitle: 'Piliin ang petsa at oras ng pickup at return. Ang return ay dapat hindi bababa sa 1 oras mula sa pickup.',
        ),

        // Debug info (remove in production)
        if (isLoadingDates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading booked dates...',
                      style: TextStyle(color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Warning if no availability dates
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
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        
        // Show booked dates info
        if (bookedRanges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'May mga petsa na ng naka-book:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...bookedRanges.map((range) => Text(
                      '${_formatDate(range['start']!)} - ${_formatDate(range['end']!)}',
                      style: TextStyle(color: Colors.orange.shade800),
                    )),
                  ],
                ),
              ),
            ),
          ),
        
        Row(
          children: [
            Expanded(
              child: DatePickerField(
                label: 'Start / Pickup Date',
                value: widget.startDate,
                onTap: isLoadingDates || !hasAvailabilityDates
                    ? null 
                    : () async {
                      print('📅 Opening start date picker');
                      final now = DateTime.now();
                      final earliest = widget.item.availableFrom!.isAfter(now) 
                          ? widget.item.availableFrom! 
                          : now;
                      final last = widget.item.availableUntil!;
                      final initial = widget.startDate ?? 
                     _findFirstAvailableDate(earliest, last);


                      print('📅 Date range: $earliest → $last');

                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: earliest,
                        lastDate: last,
                        selectableDayPredicate: (date) {
                          return !_isDateBooked(date);
                        },
                      );

                      if (picked != null) {
                        print('✅ User picked start date: $picked');
                        widget.onStartDatePicked(picked);
                      } else {
                        print('❌ User cancelled date picker');
                      }
                    },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DatePickerField(
                label: 'Return',
                value: widget.returnDate,
                onTap: widget.startDate == null || isLoadingDates || !hasAvailabilityDates
                    ? null
                    : () async {
                        print('📅 Opening return date picker');
                        final initial = widget.returnDate ?? widget.startDate!;
                        final first = widget.startDate!;
                        final last = widget.item.availableUntil!;

                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: first,
                          lastDate: last,
                          selectableDayPredicate: (date) {
                            return !_isDateBooked(date);
                          },
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
                          print('✅ User picked return date: $picked');
                          widget.onReturnDatePicked(picked);
                        }
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}