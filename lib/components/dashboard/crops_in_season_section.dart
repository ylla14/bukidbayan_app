import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bukidbayan_app/services/crop_calendar_service.dart';

class CropItem {
  final String name;
  final List<String> seasons;
  final IconData icon;
  final Color color;

  CropItem({
    required this.name,
    required this.seasons,
    required this.icon,
    required this.color,
  });
}

class CropsInSeasonSection extends StatefulWidget {
  const CropsInSeasonSection({super.key});

  @override
  State<CropsInSeasonSection> createState() => _CropsInSeasonSectionState();
}

class _CropsInSeasonSectionState extends State<CropsInSeasonSection> {
  final CropCalendarService _cropCalendarService = CropCalendarService();

  late String selectedCategory;
  late String currentSeason;
  late String currentMonth;
  bool _loading = true;
  List<CropItem> allCrops = const [];

  String detectSeason(int month) => _cropCalendarService.detectSeason(month);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentMonth = DateFormat('MMMM').format(now);
    currentSeason = detectSeason(now.month);
    selectedCategory = currentSeason;
    _loadCrops();
  }

  Future<void> _loadCrops() async {
    try {
      final seasonalItems = await _cropCalendarService.getRegionalCrops(
        region: 'philippines',
      );

      final mapped = seasonalItems
          .map(
            (item) => CropItem(
              name: item.name,
              seasons: item.seasons,
              icon: _iconForCrop(item.name),
              color: _colorForCrop(item.name),
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
    final isWet = currentSeason == "Wet Season";

    final filteredCrops = selectedCategory == 'Current'
        ? allCrops
            .where((c) => c.seasons.contains(currentSeason) || c.seasons.contains('Year Round'))
            .toList(growable: false)
        : allCrops.where((c) => c.seasons.contains(selectedCategory)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          "Crops in Season",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),

        // Current season indicator
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
                "$currentMonth • $currentSeason",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isWet ? Colors.blue : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Category filter buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ["Current", "Wet Season", "Dry Season", "Year Round"]
              .map((c) => _buildCategoryButton(c, primary))
              .toList(),
        ),
        const SizedBox(height: 20),

        // Crop grid
        _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : filteredCrops.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("No crops available for this category."),
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
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: crop.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: crop.color.withOpacity(0.4)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(crop.icon, size: 32, color: crop.color),
                        const SizedBox(height: 8),
                        Text(
                          crop.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
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
    if (normalized.contains('coconut')) return Icons.park;
    if (normalized.contains('banana')) return Icons.energy_savings_leaf;
    return Icons.spa;
  }

  Color _colorForCrop(String name) {
    const palette = <Color>[
      Colors.green,
      Colors.orange,
      Colors.redAccent,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
    ];
    return palette[name.hashCode.abs() % palette.length];
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
