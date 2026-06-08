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
  final FirestoreService? firestoreService;
  final String? Function()? currentUserIdProvider;

  const CropsInSeasonSection({
    super.key,
    this.cropCalendarService,
    this.nowProvider,
    this.region = 'philippines',
    this.firestoreService,
    this.currentUserIdProvider,
  });

  @override
  State<CropsInSeasonSection> createState() => _CropsInSeasonSectionState();
}

class _CropsInSeasonSectionState extends State<CropsInSeasonSection> {
  late final CropCalendarService _cropCalendarService;
  late final FirestoreService _firestoreService;
  late final String? Function() _currentUserIdProvider;

  late String selectedCategory;
  late String currentSeason;
  late String currentMonth;
  late int currentMonthNumber;
  bool _loading = true;
  List<CropItem> allCrops = const [];
  Set<String> myFarmCrops = {};

  String detectSeason(int month) => _cropCalendarService.detectSeason(month);

  @override
  void initState() {
    super.initState();
    _cropCalendarService = widget.cropCalendarService ?? CropCalendarService();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _currentUserIdProvider =
        widget.currentUserIdProvider ?? _defaultCurrentUserIdProvider;

    final now = (widget.nowProvider ?? DateTime.now).call();
    currentMonthNumber = now.month;
    currentMonth = DateFormat('MMMM').format(now);
    currentSeason = detectSeason(now.month);
    selectedCategory = 'Current';

    _loadCrops();
    _loadMyFarmCrops();
  }

  static String? _defaultCurrentUserIdProvider() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadMyFarmCrops() async {
    final uid = _currentUserIdProvider();
    if (uid == null || uid.isEmpty) return;

    try {
      final saved = await _firestoreService.getCropPreferences(uid);
      if (saved != null && mounted) {
        setState(() => myFarmCrops = saved.toSet());
      }
    } catch (_) {
      // Avoid blocking section rendering if user preference fetch fails.
    }
  }

  Future<void> _saveMyFarmCrops() async {
    final uid = _currentUserIdProvider();
    if (uid == null || uid.isEmpty) return;

    try {
      await _firestoreService.saveCropPreferences(uid, myFarmCrops.toList());
    } catch (_) {
      // Keep UI responsive even when remote save is temporarily unavailable.
    }
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

  Future<void> _handleCropTap(CropItem crop) async {
    final isAdded = myFarmCrops.contains(crop.name);

    final shouldToggle = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(isAdded ? 'Alisin ang Pananim' : 'Idagdag sa Aking Bukid?'),
          content: Text(
            isAdded
                ? 'Gusto mo bang alisin ang ${crop.name} mula sa iyong bukid?'
                : 'Gusto mo bang idagdag ang ${crop.name} sa iyong bukid para sa mga rekomendasyon ng kagamitan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kanselahin'), // BLT123: TL ENG
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdded
                    ? Colors.red.shade600
                    : Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(isAdded ? 'Alisin' : 'Idagdag'), // BLT123: TL ENG
            ),
          ],
        );
      },
    );

    if (shouldToggle != true || !mounted) return;

    setState(() {
      if (isAdded) {
        myFarmCrops.remove(crop.name);
      } else {
        myFarmCrops.add(crop.name);
      }
    });
    await _saveMyFarmCrops();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isWet = currentSeason == 'Wet Season';

    final filteredCrops = selectedCategory == 'My Farm'
        ? allCrops
              .where((crop) => myFarmCrops.contains(crop.name))
              .toList(growable: false)
        : selectedCategory == 'Current'
        ? allCrops
              .where(
                (crop) =>
                    crop.isRelevantInMonth(currentMonthNumber, currentSeason),
              )
              .toList(growable: false)
        : selectedCategory == 'Year Round'
        ? allCrops.where((crop) => crop.isYearRound).toList(growable: false)
        : allCrops
              .where((crop) => crop.seasons.contains(selectedCategory))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mga Pananim sa Panahon',
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
            'My Farm',
            'Wet Season',
            'Dry Season',
            'Year Round',
          ].map((category) => _buildCategoryButton(category, primary)).toList(),
        ),
        const SizedBox(height: 20),
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
                        ? 'Wala pang pananim na naidagdag sa Aking Bukid. Pindutin ang isang pananim para idagdag.'
                        : 'Walang available na pananim para sa kategoryang ito.',
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
                  final phaseBadge = _phaseBadgeForMonth(
                    crop,
                    currentMonthNumber,
                  );
                  final isAddedToFarm = myFarmCrops.contains(crop.name);

                  return GestureDetector(
                    onTap: () => _handleCropTap(crop),
                    child: ClipRRect(
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
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: crop.color.withOpacity(0.1),
                                        );
                                      },
                                )
                              : Container(color: crop.color.withOpacity(0.1)),
                          if (phaseBadge != null)
                            Positioned(
                              top: 8,
                              right: 8,
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
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
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
    if (normalized.contains('watermelon')) return Icons.water_drop;
    if (normalized.contains('squash')) return Icons.adjust;
    if (normalized.contains('pechay')) return Icons.grass;
    if (normalized.contains('upo')) return Icons.eco;
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
    if (plantingNow && harvestingNow) return 'Magtanim + Umani';
    if (plantingNow) return 'Pagtatanim';
    if (harvestingNow) return 'Pag-aani';
    if (crop.isYearRound) return 'Year-round';
    return null;
  }

  String _phaseSummary(CropItem crop) {
    if (crop.isYearRound) {
      return crop.harvestingPhase ?? 'Available all year';
    }
    if (crop.plantingPhase != null && crop.harvestingPhase != null) {
      return 'Tanim: ${crop.plantingPhase} | Ani: ${crop.harvestingPhase}';
    }
    if (crop.plantingPhase != null) return 'Tanim: ${crop.plantingPhase}';
    if (crop.harvestingPhase != null) return 'Ani: ${crop.harvestingPhase}';
    return 'Pananim sa Panahon';
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
