import 'package:flutter/material.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class PriceFilterSheet extends StatefulWidget {
  final RangeValues initialRange;
  final double minPrice;
  final double maxPrice;
  final String? activeCategory;
  final bool? operatorFilter;
  final DateTimeRange? dateFilter;
  final Function(RangeValues, bool, String?, bool?, DateTimeRange?) onApply;

  const PriceFilterSheet({
    super.key,
    required this.initialRange,
    required this.minPrice,
    required this.maxPrice,
    required this.onApply,
    this.activeCategory,
    this.operatorFilter,
    this.dateFilter,
  });

  @override
  State<PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<PriceFilterSheet> {
  late RangeValues _currentRange;
  String? _selectedCategory;
  bool? _operatorFilter;
  DateTimeRange? _dateFilter;

  final List<String> _categories = ['Hand Tool', 'Tractor', 'Machine', 'Harvester', 'Rice Mill'];

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange;
    _selectedCategory = widget.activeCategory;
    _operatorFilter = widget.operatorFilter;
    _dateFilter = widget.dateFilter;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateFilter ??
        DateTimeRange(
          start: now.add(const Duration(days: 2)),
          end: now.add(const Duration(days: 5)),
        );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select availability window',
      saveText: 'Done',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: lightColorScheme.primary,
              onPrimary: lightColorScheme.onPrimary,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateFilter = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                      _operatorFilter = null;
                      _dateFilter = null;
                      _currentRange = RangeValues(widget.minPrice, widget.maxPrice);
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(color: lightColorScheme.primary),
                  ),
                ),
              ],
            ),

            const Divider(),

            // ── CATEGORY ────────────────────────────────────────────────────
            const Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) => setState(() {
                    _selectedCategory = isSelected ? null : category;
                  }),
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.green.shade900 : Colors.black,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? Colors.green : Colors.grey.shade400,
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // ── OPERATOR ────────────────────────────────────────────────────
            const Text(
              'Operator',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ChoiceChip(
              label: const Text('With Operator'),
              selected: _operatorFilter == true,
              onSelected: (_) => setState(() {
                _operatorFilter = _operatorFilter == true ? null : true;
              }),
              selectedColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                color: _operatorFilter == true ? Colors.blue.shade900 : Colors.black,
                fontWeight: _operatorFilter == true ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: _operatorFilter == true ? Colors.blue : Colors.grey.shade400,
              ),
              avatar: Icon(
                Icons.person,
                size: 16,
                color: _operatorFilter == true ? Colors.blue.shade900 : Colors.black54,
              ),
              showCheckmark: false,
            ),

            const SizedBox(height: 16),
            const Divider(),

            // ── AVAILABILITY DATES ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Availability Dates',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (_dateFilter != null)
                  GestureDetector(
                    onTap: () => setState(() => _dateFilter = null),
                    child: Icon(Icons.clear, size: 18, color: Colors.grey.shade600),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Only show equipment with free days in this window',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _dateFilter != null
                        ? lightColorScheme.primary
                        : Colors.grey.shade400,
                    width: _dateFilter != null ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _dateFilter != null
                      ? lightColorScheme.primary.withOpacity(0.05)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 20,
                      color: _dateFilter != null
                          ? lightColorScheme.primary
                          : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 10),
                    if (_dateFilter != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatDate(_dateFilter!.start)}  →  ${_formatDate(_dateFilter!.end)}',
                            style: TextStyle(
                              color: lightColorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${_dateFilter!.duration.inDays + 1} day(s) selected',
                            style: TextStyle(
                              color: lightColorScheme.primary.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Tap to select date range',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    const Spacer(),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),

            // ── PRICE RANGE ─────────────────────────────────────────────────
            const Text(
              'Price Range',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PHP ${_currentRange.start.toInt()}'),
                Text('PHP ${_currentRange.end.toInt()}'),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: lightColorScheme.primary,
                inactiveTrackColor: Colors.green.shade100,
                thumbColor: lightColorScheme.primary,
                overlayColor: Colors.green.shade100,
                rangeThumbShape:
                    const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                valueIndicatorColor: lightColorScheme.primary,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: RangeSlider(
                min: widget.minPrice,
                max: widget.maxPrice,
                divisions: 10,
                values: _currentRange,
                labels: RangeLabels(
                  'PHP ${_currentRange.start.toInt()}',
                  'PHP ${_currentRange.end.toInt()}',
                ),
                onChanged: (values) => setState(() => _currentRange = values),
              ),
            ),

            const SizedBox(height: 16),

            // ── ACTION BUTTONS ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: lightColorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final isPriceActive = _currentRange !=
                          RangeValues(widget.minPrice, widget.maxPrice);
                      widget.onApply(
                        _currentRange,
                        isPriceActive,
                        _selectedCategory,
                        _operatorFilter,
                        _dateFilter,
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightColorScheme.primary,
                    ),
                    child: Text(
                      'Apply',
                      style: TextStyle(color: lightColorScheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}