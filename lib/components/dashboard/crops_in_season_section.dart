import 'package:bukidbayan_app/services/crop_calendar_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CropItem {
  final String name;
  final List<String> seasons;
  final IconData icon;
  final Color color;
  final String? imageUrl; 

  CropItem({
    required this.name,
    required this.seasons,
    required this.icon,
    required this.color,
    this.imageUrl,
  });
}

class CropsInSeasonSection extends StatefulWidget {
  const CropsInSeasonSection({super.key});

  @override
  State<CropsInSeasonSection> createState() => _CropsInSeasonSectionState();
}

class _CropsInSeasonSectionState extends State<CropsInSeasonSection> {
  final CropCalendarService _cropCalendarService = CropCalendarService();
  final FirestoreService _firestoreService = FirestoreService();

  late String selectedCategory;
  late String currentSeason;
  late String currentMonthName;
  late int currentMonthIndex;
  bool _loading = true;
  List<CropItem> allCrops = const [];
  
  // Keep track of the crops the user adds to "My Farm"
  Set<String> myFarmCrops = {};

  String detectSeason(int month) => _cropCalendarService.detectSeason(month);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    currentMonthName = DateFormat('MMMM').format(now);
    currentMonthIndex = now.month;
    currentSeason = detectSeason(now.month);
    // Default the active tab to the current season
    selectedCategory = currentSeason;
    _loadCrops();
    _loadMyFarmCrops();
  }

  Future<void> _loadMyFarmCrops() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final saved = await _firestoreService.getCropPreferences(uid);
    if (saved != null && mounted) {
      setState(() => myFarmCrops = saved.toSet());
    }
  }

  Future<void> _saveMyFarmCrops() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _firestoreService.saveCropPreferences(uid, myFarmCrops.toList());
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
            imageUrl: item.imageUrl, 
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

  // Helper logic to determine Land Prep or Harvest based on the crop and current month
  String? _getCropPhase(String name, int month) {
    final n = name.toLowerCase();

    if (n.contains('rice')) {
      // Differentiate between Wet and Dry season rice if specified in the name
      if (n.contains('wet')) {
        if (month == 6 || month == 7) return 'Land Prep';
        // As requested: rice in the wet season shouldn't be considered as harvest time and left blank
        return null;
      } else if (n.contains('dry')) {
        if (month == 11 || month == 12 || month == 1) return 'Land Prep';
        if (month == 3 || month == 4) return 'Harvest Time';
      } else {
        // If the item is simply named 'Rice', apply the same logic
        if (month == 6 || month == 7 || month == 12 || month == 1) return 'Land Prep';
        if (month == 11) return 'Land Prep'; // Treat November as Dry Season prep only, leaving Wet Harvest blank
        if (month == 3 || month == 4) return 'Harvest Time';
      }
    } else if (n.contains('squash')) {
      bool isPrep = (month >= 10 && month <= 12);
      bool isHarvest = (month >= 1 && month <= 3);
      if (isPrep && isHarvest) return 'Land Prep and Harvest';
      if (isPrep) return 'Land Prep';
      if (isHarvest) return 'Harvest Time';
    } else if (n.contains('tomato')) {
      bool isPrep = (month >= 10 || month <= 2);
      bool isHarvest = (month >= 1 && month <= 5);
      if (isPrep && isHarvest) return 'Land Prep and Harvest';
      if (isPrep) return 'Land Prep';
      if (isHarvest) return 'Harvest Time';
    } else if (n.contains('watermelon')) {
      bool isPrep = (month >= 10 || month == 1);
      bool isHarvest = (month >= 1 && month <= 4);
      if (isPrep && isHarvest) return 'Land Prep and Harvest';
      if (isPrep) return 'Land Prep';
      if (isHarvest) return 'Harvest Time';
    } else if (n.contains('mung bean') || n.contains('peanut') || n.contains('sugarcane')) {
      bool isPrep = (month >= 10 && month <= 12);
      bool isHarvest = (month >= 1 && month <= 4);
      if (isPrep && isHarvest) return 'Land Prep and Harvest';
      if (isPrep) return 'Land Prep';
      if (isHarvest) return 'Harvest Time';
    }
    
    return null; // Return null if it's currently in the growing phase without prep/harvest
  }

  // Handle interacting with a crop card
  void _handleCropTap(CropItem crop) {
    final isAdded = myFarmCrops.contains(crop.name);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isAdded ? "Remove Crop" : "Add to My Farm?"),
          content: Text(isAdded
              ? "Do you want to remove ${crop.name} from your farm?"
              : "Would you like to add ${crop.name} to your farm for equipment recommendations?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdded ? Colors.red.shade600 : Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  if (isAdded) {
                    myFarmCrops.remove(crop.name);
                  } else {
                    myFarmCrops.add(crop.name);
                  }
                });
                _saveMyFarmCrops();
                Navigator.pop(context);
              },
              child: Text(isAdded ? "Remove" : "Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isWet = currentSeason == "Wet Season";

    // Filtering logic updated to reflect "My Farm"
    final filteredCrops = selectedCategory == 'My Farm'
        ? allCrops.where((c) => myFarmCrops.contains(c.name)).toList(growable: false)
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
                "$currentMonthName • $currentSeason",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isWet ? Colors.blue : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Category filter buttons (Changed "Current" to "My Farm")
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ["My Farm", "Wet Season", "Dry Season", "Year Round"]
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    selectedCategory == 'My Farm' 
                        ? "No crops added to My Farm yet. Tap on a crop to add it!" 
                        : "No crops available for this category.",
                    textAlign: TextAlign.center,
                  ),
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
                  final isYearRound = crop.seasons.contains('Year Round');
                  final isAddedToFarm = myFarmCrops.contains(crop.name);
                  
                  // Only calculate phase for seasonal crops
                  final String? phase = isYearRound ? null : _getCropPhase(crop.name, currentMonthIndex);

                  return GestureDetector(
                    onTap: () => _handleCropTap(crop),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background image
                          crop.imageUrl != null
                              ? Image.network(
                                  crop.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(color: crop.color.withOpacity(0.1)),
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(color: crop.color.withOpacity(0.1));
                                  },
                                )
                              : Container(color: crop.color.withOpacity(0.1)),

                          // Dark overlay so text is readable
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

                          // Phase Tag (Land Prep / Harvest Time)
                          if (phase != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: phase == 'Land Prep and Harvest'
                                      ? Colors.teal.shade600 // Use a distinct color for overlapping months
                                      : phase.contains('Harvest') 
                                          ? Colors.orange.shade600 
                                          : Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  phase,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                          // My Farm Indicator Checkmark
                          if (isAddedToFarm)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                            ),

                          // Crop name at the bottom
                          Positioned(
                            bottom: 10,
                            left: 8,
                            right: 8,
                            child: Text(
                              crop.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  IconData _iconForCrop(String name) {
    final normalized = name.toLowerCase();
    
    // Original mappings
    if (normalized.contains('rice')) return Icons.grass;
    if (normalized.contains('corn')) return Icons.agriculture;
    if (normalized.contains('tomato')) return Icons.eco;
    if (normalized.contains('eggplant')) return Icons.local_florist;
    if (normalized.contains('coconut')) return Icons.park;
    if (normalized.contains('banana')) return Icons.energy_savings_leaf;
    
    // New mappings based on our agricultural logic
    if (normalized.contains('squash')) return Icons.adjust;
    if (normalized.contains('pechay')) return Icons.grass;
    if (normalized.contains('upo')) return Icons.eco;
    if (normalized.contains('watermelon')) return Icons.water_drop;
    if (normalized.contains('bean') || normalized.contains('peanut')) return Icons.grain;
    
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