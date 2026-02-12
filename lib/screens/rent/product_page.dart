import 'package:bukidbayan_app/components/rent/product_page/product_availability.dart';
import 'package:bukidbayan_app/components/rent/product_page/product_image_carousel.dart';
import 'package:bukidbayan_app/components/rent/product_page/product_specs.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/request_rent_form.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProductPage extends StatelessWidget {
  final Equipment item;

  const ProductPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final PageController _pageController = PageController();
    final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

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

    Widget _ownerChip(String? ownerName) {
      final displayName = ownerName ?? 'Unknown Owner';
      final initials = displayName.isNotEmpty
          ? displayName.trim().split(' ').map((e) => e[0]).take(2).join()
          : 'U';

      return Row(
        children: [
          CircleAvatar(
            radius: 24,
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

    void _openFullImage(BuildContext context, String imageUrl) {
      showDialog(
        context: context,
        barrierColor: Colors.black,
        builder: (_) => GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    // StreamBuilder for live updates
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('equipment')
          .doc(item.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Equipment not found.')),
          );
        }

        final liveItem = Equipment.fromFirestore(snapshot.data!);

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
                  stops: const [0.0, 0.9],
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: currentIndex,
                  builder: (_, index, __) => ProductImageCarousel(
                    images: liveItem.imageUrls,
                    controller: _pageController,
                    currentIndex: index,
                    onPageChanged: (i) => currentIndex.value = i,
                    onImageTap: (url) => _openFullImage(context, url),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          liveItem.name,
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
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    liveItem.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CustomDivider(),
                ProductSpecs(item: liveItem),
                CustomDivider(),
                ProductAvailability(item: liveItem),
                CustomDivider(),
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
                      if (liveItem.landSizeRequirement)
                        _requirementChip(
                          (liveItem.landSizeMin != null &&
                                  liveItem.landSizeMax != null)
                              ? 'Land size requirement: ${liveItem.landSizeMin} – ${liveItem.landSizeMax} sqm'
                              : 'Land size requirement',
                        ),
                      if (liveItem.maxCropHeightRequirement)
                        _requirementChip(
                          liveItem.maxCropHeight != null
                              ? 'Max crop height: ${liveItem.maxCropHeight} cm'
                              : 'Max crop height required',
                        ),
                      if (!liveItem.landSizeRequirement &&
                          !liveItem.maxCropHeightRequirement)
                        _requirementChip('No specific requirements'),
                    ],
                  ),
                ),
                CustomDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ownerChip(liveItem.ownerName),
                ),
                CustomDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Reviews (12)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        'View all',
                        style:
                            TextStyle(fontSize: 13, color: Colors.blueGrey),
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
                      '₱${liveItem.price} ${_getRateSuffix(liveItem.rentalUnit)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: ElevatedButton(
                    onPressed: currentUserId == liveItem.ownerId
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EquipmentListingScreen(existingEquipment: liveItem,),
                              ),
                            );
                          }
                        : liveItem.isAvailable
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RequestRentForm(item: liveItem),
                                  ),
                                );
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentUserId == liveItem.ownerId
                          ? lightColorScheme.primary
                          : (liveItem.isAvailable
                              ? lightColorScheme.primary
                              : Colors.grey),
                      foregroundColor: lightColorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(currentUserId == liveItem.ownerId
                            ? 'Edit Listing'
                            : 'Request to Rent'),
                        if (!liveItem.isAvailable && currentUserId != liveItem.ownerId)
                          const Text(
                            'Not available',
                            style:
                                TextStyle(fontSize: 12, color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
