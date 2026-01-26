import 'package:bukidbayan_app/components/rent/product_availability.dart';
import 'package:bukidbayan_app/components/rent/product_image_carousel.dart';
import 'package:bukidbayan_app/components/rent/product_specs.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';
import 'package:bukidbayan_app/screens/rent/request_rent_form.dart';

import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:flutter/material.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.item});
  final RentItem item;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _openFullImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(
            child: Image.asset(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _requirementChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  String _getRateSuffix(String rentRate) {
    switch (rentRate.toLowerCase()) {
      case 'per day':
        return '/day';
      case 'per hour':
        return '/hour';
      case 'per week':
        return '/week';
      case 'per month':
        return '/month';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
print('landSizeMin: ${item.landSizeMin}');
print('landSizeMax: ${item.landSizeMax}');
print('maxCropHeight: ${item.maxCropHeight}');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Product Details',
          style: TextStyle(color: lightColorScheme.onPrimary),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
              stops: [0.0, 0.9],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SLIDER
            ProductImageCarousel(
              images: item.imageUrl,
              controller: _pageController,
              currentIndex: _currentIndex,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              onImageTap: _openFullImage,
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.star, size: 18, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        '4.8',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ITEM DESCRIPTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                item.description ?? 'No description provided.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 12),
            CustomDivider(),

            // SPECS
            ProductSpecs(item: item),
            CustomDivider(),

            // AVAILABILITY SECTION
            ProductAvailability(item: item),
            CustomDivider(),

            // REQUIREMENTS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Requirements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (item.landSizeRequirement)
                    _requirementChip(
                      (item.landSizeMin != null && item.landSizeMax != null)
                          ? 'Land size requirement: ${item.landSizeMin} – ${item.landSizeMax} sqm'
                          : 'Land size requirement',
                    ),
                  if (item.maxCropHeightRequirement)
                    _requirementChip(
                      item.maxCropHeight != null
                          ? 'Max crop height: ${item.maxCropHeight} cm'
                          : 'Max crop height required',
                    ),

                  // fallback if no requirements
                  if (!item.landSizeRequirement && !item.maxCropHeightRequirement)
                    _requirementChip('No specific requirements'),
                ],
              )
            ),

            CustomDivider(),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ownerChip(item.ownerName),
            ),


            CustomDivider(),

            // REVIEWS (placeholder)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Reviews (12)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    'View all',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Container(
                    width: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Review content here...',
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Price',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '₱${item.price} ${_getRateSuffix(item.rentalUnit)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(width: 30),
            Expanded(
              child: ElevatedButton(
                onPressed: () { 
                  print('hello');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestRentForm(item: item),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightColorScheme.primary,
                  foregroundColor: lightColorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Request to Rent'),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _ownerChip(String? ownerName) {
  final displayName = ownerName ?? 'Unknown Owner';
  final initials = displayName.isNotEmpty
      ? displayName.trim().split(' ').map((e) => e[0]).take(2).join()
      : 'U';

  return Row(
    children: [
      // Bigger circular avatar
      CircleAvatar(
        radius: 24, // bigger than before
        backgroundColor: Colors.blueAccent,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      const SizedBox(width: 12),
      // Owner name
      Expanded(
        child: Text(
          displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}


}
