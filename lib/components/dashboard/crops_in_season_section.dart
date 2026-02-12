import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  State<CropsInSeasonSection> createState() =>
      _CropsInSeasonSectionState();
}

class _CropsInSeasonSectionState
    extends State<CropsInSeasonSection> {

  late String selectedCategory;
  late String currentSeason;
  late String currentMonth;

  String detectSeason(int month) {
    if (month >= 6 && month <= 11) {
      return "Wet Season";
    } else {
      return "Dry Season";
    }
  }

  final List<CropItem> allCrops = [
    CropItem(
      name: "Rice",
      seasons: ["Wet Season"],
      icon: Icons.grass,
      color: Colors.green,
    ),
    CropItem(
      name: "Corn",
      seasons: ["Dry Season"],
      icon: Icons.agriculture,
      color: Colors.orange,
    ),
    CropItem(
      name: "Tomato",
      seasons: ["Wet Season", "Dry Season", "Year Round"],
      icon: Icons.eco,
      color: Colors.redAccent,
    ),
    CropItem(
      name: "Eggplant",
      seasons: ["Wet Season"],
      icon: Icons.local_florist,
      color: Colors.purple,
    ),
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    currentMonth = DateFormat('MMMM').format(now);
    currentSeason = detectSeason(now.month);

    selectedCategory = currentSeason; // default selection
  }

  @override
  Widget build(BuildContext context) {

    List<CropItem> filteredCrops;

    if (selectedCategory == "All") {
      filteredCrops = allCrops;
    } else {
      filteredCrops = allCrops
          .where((crop) =>
              crop.seasons.contains(selectedCategory))
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// TITLE
        Text(
          "Crops in Season",
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        /// MONTH + SEASON DISPLAY
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: currentSeason == "Wet Season"
                ? Colors.blue.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                currentSeason == "Wet Season"
                    ? Icons.water_drop
                    : Icons.wb_sunny,
                color: currentSeason == "Wet Season"
                    ? Colors.blue
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                "$currentMonth • $currentSeason",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: currentSeason == "Wet Season"
                      ? Colors.blue
                      : Colors.orange,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        /// CATEGORY BUTTONS
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCategoryButton("All"),
            _buildCategoryButton("Wet Season"),
            _buildCategoryButton("Dry Season"),
            _buildCategoryButton("Year Round"),
          ],
        ),

        const SizedBox(height: 20),

        /// GRID DISPLAY
        filteredCrops.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      "No crops available for this category."),
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount: filteredCrops.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            crop.color.withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          crop.icon,
                          size: 32,
                          color: crop.color,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          crop.name,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildCategoryButton(String category) {
    final bool isSelected =
        selectedCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? lightColorScheme.primary
              : Colors.grey.shade200,
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
