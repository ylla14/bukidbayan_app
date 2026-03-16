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
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Phase tag model
// ---------------------------------------------------------------------------
class _PhaseTag {
  final String label;
  final IconData icon;
  final Color color;

  const _PhaseTag({required this.label, required this.icon, required this.color});
}

// ---------------------------------------------------------------------------
// Hardcoded phase mapping (expand as needed)
// ---------------------------------------------------------------------------
List<_PhaseTag> _getPhaseTagsForEquipment(Equipment item) {
  final name = item.name.toLowerCase();
  final category = (item.category ?? '').toLowerCase();

  final tags = <_PhaseTag>[];

  // Land Preparation
  if (category.contains('tractor') ||
      name.contains('tractor') ||
      name.contains('plow') ||
      name.contains('rotavator') ||
      name.contains('cultivat')) {
    tags.add(const _PhaseTag(
      label: 'Land Prep',
      icon: Icons.grass,
      color: Color(0xFF6B8E23),
    ));
  }

  // Planting
  if (name.contains('seeder') ||
      name.contains('transplant') ||
      name.contains('planter') ||
      category.contains('planter')) {
    tags.add(const _PhaseTag(
      label: 'Planting',
      icon: Icons.eco,
      color: Color(0xFF2E8B57),
    ));
  }

  // Irrigation / Water Management
  if (name.contains('pump') ||
      name.contains('irrigat') ||
      name.contains('sprinkler') ||
      category.contains('pump')) {
    tags.add(const _PhaseTag(
      label: 'Irrigation',
      icon: Icons.water_drop,
      color: Color(0xFF1E90FF),
    ));
  }

  // Crop Care / Spraying
  if (name.contains('spray') ||
      name.contains('sprayer') ||
      name.contains('pest') ||
      name.contains('fertil') ||
      category.contains('sprayer')) {
    tags.add(const _PhaseTag(
      label: 'Crop Care',
      icon: Icons.science,
      color: Color(0xFF9370DB),
    ));
  }

  // Harvesting
  if (category.contains('harvester') ||
      name.contains('harvest') ||
      name.contains('reaper') ||
      name.contains('combine')) {
    tags.add(const _PhaseTag(
      label: 'Harvesting',
      icon: Icons.agriculture,
      color: Color(0xFFD2691E),
    ));
  }

  // Post-Harvest / Milling
  if (category.contains('rice mill') ||
      name.contains('mill') ||
      name.contains('thresher') ||
      name.contains('dryer') ||
      name.contains('sheller') ||
      name.contains('huller')) {
    tags.add(const _PhaseTag(
      label: 'Post-Harvest',
      icon: Icons.factory,
      color: Color(0xFFCD853F),
    ));
  }

  // Transport / Hauling
  if (name.contains('hauler') ||
      name.contains('transport') ||
      name.contains('truck') ||
      name.contains('trailer') ||
      category.contains('transport')) {
    tags.add(const _PhaseTag(
      label: 'Transport',
      icon: Icons.local_shipping,
      color: Color(0xFF708090),
    ));
  }

  // Storage
  if (name.contains('silo') ||
      name.contains('storage') ||
      name.contains('bin') ||
      category.contains('storage')) {
    tags.add(const _PhaseTag(
      label: 'Storage',
      icon: Icons.inventory_2,
      color: Color(0xFF8B6914),
    ));
  }

  // Fallback — if nothing matched
  if (tags.isEmpty) {
    tags.add(const _PhaseTag(
      label: 'General Use',
      icon: Icons.build,
      color: Color(0xFF607D8B),
    ));
  }

  return tags;
}

// ---------------------------------------------------------------------------
// Phase chip widget
// ---------------------------------------------------------------------------
class _PhaseChip extends StatefulWidget {
  final _PhaseTag tag;

  const _PhaseChip({required this.tag});

  @override
  State<_PhaseChip> createState() => _PhaseChipState();
}

class _PhaseChipState extends State<_PhaseChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        // Could navigate to a phase info screen in future
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tag.label} phase: equipment used during this farming stage.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _pressed
              ? tag.color.withOpacity(0.25)
              : tag.color.withOpacity(0.12),
          border: Border.all(
            color: tag.color.withOpacity(_pressed ? 0.9 : 0.5),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tag.icon, size: 13, color: tag.color),
            const SizedBox(width: 5),
            Text(
              tag.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tag.color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ProductPage
// ---------------------------------------------------------------------------
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
        case 'per kg':
          return '/kg';
        case 'per hectare':
          return '/ha';
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

        /// Opens Google Maps (or falls back to a maps URL) for the equipment location.
    void _openInMaps(double lat, double lng, String? label) {
      // Replace with launchUrl() once url_launcher is in your pubspec.
      showConfirmSnackbar(
        context: context,
        title: 'Equipment Location',
        message: label ?? '$lat, $lng',
      );
    }

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
        final phaseTags = _getPhaseTagsForEquipment(liveItem);

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
                // ── Image carousel ──────────────────────────────────────────
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

                // ── Name + rating ────────────────────────────────────────────
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
                                Text('No reviews',
                                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                              ],
                            );
                          }
                          final reviews = reviewSnap.data!;
                          final avg = reviews
                                  .map((r) => r.rating)
                                  .reduce((a, b) => a + b) /
                              reviews.length;
                          return Row(
                            children: [
                              const Icon(Icons.star, size: 18, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(avg.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              Text('(${reviews.length})',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.grey)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ── Phase tags 
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // const Text(
                      //   'Used in farming phase',
                      //   style: TextStyle(
                      //     fontSize: 11,
                      //     color: Colors.black45,
                      //     letterSpacing: 0.4,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: phaseTags
                            .map((tag) => _PhaseChip(tag: tag))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                // ── Description ──────────────────────────────────────────────
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

                // ── Location ─────────────────────────────────────────────────
                if (liveItem.location != null && liveItem.location!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 20,
                              color: lightColorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                liveItem.location!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            // "Open in Maps" button — only shown if coords exist
                            if (liveItem.latitude != null && liveItem.longitude != null)
                              GestureDetector(
                                onTap: () => _openInMaps(
                                  liveItem.latitude!,
                                  liveItem.longitude!,
                                  liveItem.location,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: lightColorScheme.primary.withOpacity(0.08),
                                    border: Border.all(
                                      color: lightColorScheme.primary.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 14,
                                        color: lightColorScheme.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Map',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: lightColorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Coordinates hint — subtle, shown only if available
                        if (liveItem.latitude != null && liveItem.longitude != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              '${liveItem.latitude!.toStringAsFixed(5)}, '
                              '${liveItem.longitude!.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                CustomDivider(),
                ProductSpecs(item: liveItem),
                CustomDivider(),
                ProductAvailability(item: liveItem),
                CustomDivider(),

                // ── Requirements ─────────────────────────────────────────────
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
                              ? 'Land size requirement: ${liveItem.landSizeMin} – ${liveItem.landSizeMax} ha'
                              : 'Land size requirement',
                        ),
                      if (liveItem.maxCropHeightRequirement)
                        _requirementChip(
                          liveItem.maxCropHeight != null
                              ? 'Max grass height: ${liveItem.maxCropHeight} cm'
                              : 'Max grass height required',
                        ),
                      if (liveItem.minimumVolumeRequired &&
                          liveItem.minimumVolumeKg != null)
                        _requirementChip(
                          liveItem.minimumVolumeUnit == 'cavans'
                              ? 'Min volume: ${(liveItem.minimumVolumeKg! / 50).toStringAsFixed(0)} cavans'
                                  '${liveItem.batchingAllowed ? ' (batching available)' : ''}'
                              : 'Min volume: ${liveItem.minimumVolumeKg!.toStringAsFixed(0)} kg'
                                  '${liveItem.batchingAllowed ? ' (batching available)' : ''}',
                        ),
                      if (liveItem.cropConditionRequirement)
                      _requirementChip(
                        liveItem.cropCondition != null
                            ? 'Crop condition: ${liveItem.cropCondition}'
                            : 'Crop condition required',
                      ),
                      if (!liveItem.landSizeRequirement &&
                        !liveItem.maxCropHeightRequirement &&
                        !liveItem.minimumVolumeRequired &&
                        !liveItem.cropConditionRequirement)
                      _requirementChip('No specific requirements'),
                    ],
                  ),
                ),
                CustomDivider(),

                // ── Owner 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ownerChip(liveItem.ownerName),
                ),
                CustomDivider(),

                // ── Reviews 
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
                                    fontSize: 16, fontWeight: FontWeight.w500),
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
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (reviews.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('No reviews yet.',
                                style: TextStyle(fontSize: 13, color: Colors.grey)),
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
                                        children: List.generate(
                                          5,
                                          (i) => Icon(
                                            i < review.rating.round()
                                                ? Icons.star
                                                : Icons.star_outline,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: Text(
                                          review.comment.isNotEmpty
                                              ? review.comment
                                              : 'No comment',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: review.comment.isNotEmpty
                                                ? Colors.black87
                                                : Colors.grey,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      FutureBuilder<String?>(
                                        future: FirestoreService()
                                            .getUserNameById(review.reviewerId),
                                        builder: (context, nameSnap) {
                                          return Text(
                                            nameSnap.data ?? 'Anonymous',
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.grey),
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

          // ── Bottom bar 
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
                    const Text('Price',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    if (liveItem.category?.toLowerCase().contains('rice mill') ==
                        true) ...[
                      Row(
                        children: [
                          Text(
                            '₱${liveItem.riceOnlyPricePerKg?.toStringAsFixed(2) ?? '2.00'}/kg',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Text(' · Rice Only',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '₱${liveItem.ricePlusDarakPricePerKg?.toStringAsFixed(2) ?? '3.00'}/kg',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Text(' · Rice + Darak',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ] else ...[
                      Text(
                        '₱${liveItem.price} ${_getRateSuffix(liveItem.rentalUnit)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (liveItem.category?.toLowerCase() == 'harvester (halimaw)')
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
                                builder: (_) => EquipmentListingScreen(
                                    existingEquipment: liveItem),
                              ),
                            );
                          }
                        : liveItem.isAvailable
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RequestRentForm(item: liveItem),
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
                        if (!liveItem.isAvailable &&
                            currentUserId != liveItem.ownerId)
                          const Text(
                            'Not available',
                            style: TextStyle(fontSize: 12, color: Colors.red),
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