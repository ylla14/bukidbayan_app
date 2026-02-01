import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:bukidbayan_app/models/equipment.dart';

class EquipmentCarousel extends StatelessWidget {
  final List<Equipment> equipment;
  final int maxItems;

  const EquipmentCarousel({
    super.key,
    required this.equipment,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context) {
    final carouselItems = equipment.take(maxItems).toList();

    if (carouselItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 180,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.925,
      ),
      items: carouselItems.map((item) {
        final imageUrl = item.imageUrls.isNotEmpty
            ? item.imageUrls[0]
            : 'assets/images/rent1.jpg';

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/rent1.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
              );
            },
          ),
        );
      }).toList(),
    );
  }
}