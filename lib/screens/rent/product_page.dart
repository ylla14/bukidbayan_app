import 'package:bukidbayan_app/components/rent/product_page/product_availability.dart';
import 'package:bukidbayan_app/components/rent/product_page/product_image_carousel.dart';
import 'package:bukidbayan_app/components/rent/product_page/product_specs.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/review.dart';
import 'package:bukidbayan_app/screens/rent/all_reviews_screen.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/request_rent_form.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
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
                      FutureBuilder<List<Review>>(
                        future: FirestoreService().getReviewsForEquipment(liveItem.id!),
                        builder: (context, reviewSnap) {
                          if (!reviewSnap.hasData || reviewSnap.data!.isEmpty) {
                            return const Row(
                              children: [
                                Icon(Icons.star_outline, size: 18, color: Colors.grey),
                                SizedBox(width: 4),
                                Text('No reviews', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            );
                          }
                          final reviews = reviewSnap.data!;
                          final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
                          return Row(
                            children: [
                              const Icon(Icons.star, size: 18, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                avg.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${reviews.length})',
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          );
                        },
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
                          (liveItem.landSizeMin != null && liveItem.landSizeMax != null)
                              ? 'Land size requirement: ${liveItem.landSizeMin} – ${liveItem.landSizeMax} sqm'
                              : 'Land size requirement',
                        ),
                      if (liveItem.maxCropHeightRequirement)
                        _requirementChip(
                          liveItem.maxCropHeight != null
                              ? 'Max crop height: ${liveItem.maxCropHeight} cm'
                              : 'Max crop height required',
                        ),
                      if (liveItem.minimumVolumeRequired && liveItem.minimumVolumeKg != null)
                        _requirementChip(
                          liveItem.minimumVolumeUnit == 'cavans'
                              ? 'Min volume: ${(liveItem.minimumVolumeKg! / 50).toStringAsFixed(0)} cavans'
                                  '${liveItem.batchingAllowed ? ' (batching available)' : ''}'
                              : 'Min volume: ${liveItem.minimumVolumeKg!.toStringAsFixed(0)} kg'
                                  '${liveItem.batchingAllowed ? ' (batching available)' : ''}',
                        ),
                      if (!liveItem.landSizeRequirement &&
                          !liveItem.maxCropHeightRequirement &&
                          !liveItem.minimumVolumeRequired)
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
                FutureBuilder<List<Review>>(
                  future: FirestoreService().getReviewsForEquipment(liveItem.id!),
                  builder: (context, reviewSnap) {
                    final reviews = reviewSnap.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                       Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Reviews (${reviews.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (reviews.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AllReviewsScreen(
                                          equipmentId: liveItem.id!,
                                          equipmentName: liveItem.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'See all >',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        if (reviews.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'No reviews yet.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                          )
                        else
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: reviews.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final review = reviews[index];
                                return Container(
                                  width: 200,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: List.generate(5, (i) => Icon(
                                          i < review.rating.round() ? Icons.star : Icons.star_outline,
                                          size: 14,
                                          color: Colors.amber,
                                        )),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Text(
                                          review.comment.isNotEmpty ? review.comment : 'No comment',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: review.comment.isNotEmpty ? Colors.black87 : Colors.grey,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      FutureBuilder<String?>(
                                        future: FirestoreService().getUserNameById(review.reviewerId),
                                        builder: (context, nameSnap) {
                                          return Text(
                                            nameSnap.data ?? 'Anonymous',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
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
                    if (liveItem.category?.toLowerCase().contains('rice mill') == true) ...[
                      Row(
                        children: [
                          Text(
                            '₱${liveItem.riceOnlyPricePerKg?.toStringAsFixed(2) ?? '2.00'}/kg',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            ' · Rice Only',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '₱${liveItem.ricePlusDarakPricePerKg?.toStringAsFixed(2) ?? '3.00'}/kg',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            ' · Rice + Darak',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '₱${liveItem.price} ${_getRateSuffix(liveItem.rentalUnit)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (liveItem.category?.toLowerCase() == 'harvester')
                        Text(
                          '+ 12% of Crop Harvest',
                          style: TextStyle(
                            fontSize: 15,
                            color: lightColorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
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
