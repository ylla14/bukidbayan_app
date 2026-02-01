import 'package:flutter/material.dart';

class CategoryFilterBar extends StatelessWidget {
  final String? activeCategory;
  final Function(String) onCategorySelected;
  final List<String> categories;

  const CategoryFilterBar({
    super.key,
    required this.activeCategory,
    required this.onCategorySelected,
    this.categories = const ['Hand Tool', 'Tractor', 'Machine', 'Harvester'],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int index = 0; index < categories.length; index++) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      activeCategory == categories[index] ? Colors.green.shade100 : null,
                  side: BorderSide(
                    color: activeCategory == categories[index]
                        ? Colors.green
                        : Colors.grey,
                  ),
                ),
                onPressed: () => onCategorySelected(categories[index]),
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: activeCategory == categories[index]
                        ? Colors.green.shade900
                        : Colors.black,
                    fontWeight: activeCategory == categories[index]
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (index < categories.length - 1)
                const SizedBox(width: 8), // separator
            ],
          ],
        ),
      ),
    );
  }
}
