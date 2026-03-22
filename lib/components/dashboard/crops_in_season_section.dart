import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bukidbayan_app/services/crop_calendar_service.dart';

class CropItem {
  final String name;
  final List<String> seasons;
  final IconData icon;
  final Color color;
  final String? imageUrl;
  final List<int> plantingMonths;
  final List<int> harvestingMonths;
  final String? plantingPhase;
  final String? harvestingPhase;
  final String? notes;

  CropItem({
    required this.name,
    required this.seasons,
    required this.icon,
    required this.color,
    this.imageUrl,
    this.plantingMonths = const [],
    this.harvestingMonths = const [],
    this.plantingPhase,
    this.harvestingPhase,
    this.notes,
  });

  bool get isYearRound => seasons.contains('Year Round');

  bool isRelevantInMonth(int month, String currentSeason) {
    if (isYearRound) return true;
    if (plantingMonths.contains(month)) return true;
    if (harvestingMonths.contains(month)) return true;
    if (plantingMonths.isEmpty &&
        harvestingMonths.isEmpty &&
        seasons.contains(currentSeason)) {
      return true;
    }
    return false;
  }
}

class CropsInSeasonSection extends StatefulWidget {
  final CropCalendarService? cropCalendarService;
  final DateTime Function()? nowProvider;
  final String region;

  const CropsInSeasonSection({
    super.key,
    this.cropCalendarService,
    this.nowProvider,
    this.region = 'philippines',
  });

  @override
  State<CropsInSeasonSection> createState() => _CropsInSeasonSectionState();
}

class _CropsInSeasonSectionState extends State<CropsInSeasonSection> {
  late final CropCalendarService _cropCalendarService;

  late String selectedCategory;
  late String currentSeason;
  late String currentMonth;
  late int currentMonthNumber;
  bool _loading = true;
  List<CropItem> allCrops = const [];

  String detectSeason(int month) => _cropCalendarService.detectSeason(month);

  @override
  void initState() {
    super.initState();
    _cropCalendarService = widget.cropCalendarService ?? CropCalendarService();
    final now = (widget.nowProvider ?? DateTime.now).call();
    currentMonthNumber = now.month;
    currentMonth = DateFormat('MMMM').format(now);
    currentSeason = detectSeason(now.month);
    selectedCategory = 'Current';
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    try {
      final seasonalItems = await _cropCalendarService.getRegionalCrops(
        region: widget.region,
      );

      final mapped = seasonalItems
          .map(
            (item) => CropItem(
              name: item.name,
              seasons: item.seasons,
              icon: _iconForCrop(item.name),
              color: _colorForCrop(item.name),
              imageUrl: item.imageUrl,
              plantingMonths: item.plantingMonths,
              harvestingMonths: item.harvestingMonths,
              plantingPhase: item.plantingPhase,
              harvestingPhase: item.harvestingPhase,
              notes: item.notes,
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        allCrops = mapped;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isWet = currentSeason == 'Wet Season';

    final filteredCrops = selectedCategory == 'Current'
        ? allCrops
              .where(
                (c) => c.isRelevantInMonth(currentMonthNumber, currentSeason),
              )
              .toList(growable: false)
        : selectedCategory == 'Year Round'
        ? allCrops.where((c) => c.isYearRound).toList(growable: false)
        : allCrops
              .where((c) => c.seasons.contains(selectedCategory))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crops in Season',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isWet ? Colors.blue : Colors.orange).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isWet ? Icons.water_drop : Icons.wb_sunny,
                color: isWet ? Colors.blue : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                '$currentMonth - $currentSeason',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isWet ? Colors.blue : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Current',
            'Wet Season',
            'Dry Season',
            'Year Round',
          ].map((c) => _buildCategoryButton(c, primary)).toList(),
        ),
        const SizedBox(height: 20),
        _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : filteredCrops.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No crops available for this category.'),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCrops.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  final crop = filteredCrops[index];
                  final phaseBadge = _phaseBadgeForMonth(
                    crop,
                    currentMonthNumber,
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        crop.imageUrl != null
                            ? Image.network(
                                crop.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: crop.color.withOpacity(0.1),
                                    ),
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: crop.color.withOpacity(0.1),
                                      );
                                    },
                              )
                            : Container(color: crop.color.withOpacity(0.1)),
                        if (phaseBadge != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                phaseBadge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 8,
                          right: 8,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                crop.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (selectedCategory == 'Current')
                                Text(
                                  _phaseSummary(crop),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  IconData _iconForCrop(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('rice')) return Icons.grass;
    if (normalized.contains('corn')) return Icons.agriculture;
    if (normalized.contains('tomato')) return Icons.eco;
    if (normalized.contains('eggplant')) return Icons.local_florist;
    if (normalized.contains('banana')) return Icons.energy_savings_leaf;
    if (normalized.contains('watermelon')) return Icons.spa;
    return Icons.spa;
  }

  Color _colorForCrop(String name) {
    const palette = <Color>[
      Colors.green,
      Colors.orange,
      Colors.redAccent,
      Colors.deepPurple,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  String? _phaseBadgeForMonth(CropItem crop, int month) {
    final plantingNow = crop.plantingMonths.contains(month);
    final harvestingNow = crop.harvestingMonths.contains(month);
    if (plantingNow && harvestingNow) return 'Plant + Harvest';
    if (plantingNow) return 'Planting';
    if (harvestingNow) return 'Harvest';
    if (crop.isYearRound) return 'Year-round';
    return null;
  }

  String _phaseSummary(CropItem crop) {
    if (crop.isYearRound) {
      return crop.harvestingPhase ?? 'Available all year';
    }
    if (crop.plantingPhase != null && crop.harvestingPhase != null) {
      return 'Plant: ${crop.plantingPhase} | Harvest: ${crop.harvestingPhase}';
    }
    if (crop.plantingPhase != null) return 'Plant: ${crop.plantingPhase}';
    if (crop.harvestingPhase != null) return 'Harvest: ${crop.harvestingPhase}';
    return 'Seasonal crop';
  }

  Widget _buildCategoryButton(String category, Color primary) {
    final isSelected = selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
