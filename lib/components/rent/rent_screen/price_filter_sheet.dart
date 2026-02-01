import 'package:flutter/material.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class PriceFilterSheet extends StatefulWidget {
  final RangeValues initialRange;
  final double minPrice;
  final double maxPrice;
  final Function(RangeValues, bool) onApply;

  const PriceFilterSheet({
    super.key,
    required this.initialRange,
    required this.minPrice,
    required this.maxPrice,
    required this.onApply,
  });

  @override
  State<PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends State<PriceFilterSheet> {
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.initialRange;
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter by Price',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
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
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 10,
              ),
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
              onChanged: (values) {
                setState(() {
                  _currentRange = values;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onApply(
                      RangeValues(widget.minPrice, widget.maxPrice),
                      false,
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(color: lightColorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_currentRange, true);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightColorScheme.primary,
                  ),
                  child:  Text('Apply', style: TextStyle(color: lightColorScheme.onPrimary),),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}