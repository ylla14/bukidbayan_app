import 'package:flutter/material.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/components/rent/rent_item_card.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';

class EquipmentGrid extends StatelessWidget {
  final List<Equipment> equipment;
  final Map<String, String> ownerNames;
  final bool Function(Equipment) calculateAvailability;

  const EquipmentGrid({
    super.key,
    required this.equipment,
    required this.ownerNames,
    required this.calculateAvailability,
  });

  @override
  Widget build(BuildContext context) {
    if (equipment.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: equipment.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final item = equipment[index];
        final ownerName = ownerNames[item.ownerId] ?? 'Unknown Owner';

        return GestureDetector(
          onTap: () => _navigateToProductPage(context, item, ownerName),
          child: RentItemCard(
            title: item.name,
            imageUrl: item.imageUrls.isNotEmpty
                ? item.imageUrls[0]
                : 'assets/images/rent1.jpg',
            price: '₱${item.price.toStringAsFixed(0)}',
            ownerName: ownerName,
            rentalUnit: item.rentalUnit,
            isAvailable: calculateAvailability(item),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No equipment found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProductPage(
    BuildContext context,
    Equipment equipment,
    String ownerName,
  ) {
    final equipmentWithOwner = Equipment(
      name: equipment.name,
      imageUrls: equipment.imageUrls.isNotEmpty
          ? equipment.imageUrls
          : ['assets/images/rent1.jpg'],
      category: equipment.category ?? 'Other',
      price: equipment.price,
      availableFrom: equipment.availableFrom,
      availableUntil: equipment.availableUntil,
      brand: equipment.brand,
      yearModel: equipment.yearModel,
      power: equipment.power,
      fuelType: equipment.fuelType,
      condition: equipment.condition,
      attachments: equipment.attachments,
      operatorIncluded: equipment.operatorIncluded,
      rentRate: equipment.rentRate ?? 'Unknown Rent Rate',
      landSizeRequirement: equipment.landSizeRequirement,
      maxCropHeightRequirement: equipment.maxCropHeightRequirement,
      id: equipment.id ?? 'UNKNOWN ID',
      description: equipment.description,
      landSizeMax: equipment.landSizeMax,
      landSizeMin: equipment.landSizeMin,
      maxCropHeight: equipment.maxCropHeight,
      ownerName: ownerName,
      rentalUnit: equipment.rentalUnit,
      ownerId: equipment.ownerId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductPage(item: equipmentWithOwner),
      ),
    );
  }
}