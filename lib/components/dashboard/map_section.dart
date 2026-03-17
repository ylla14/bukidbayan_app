import 'package:bukidbayan_app/models/crop_preference.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/screens/rent/rent_screen.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

enum DashboardCoordinateSource { farm, home }

class MapSection extends StatefulWidget {
  final String? currentUserId;
  final FirestoreService? firestoreService;
  final Future<DashboardUserContext?> Function(String? currentUserId)?
  userContextLoader;
  final Stream<List<Equipment>> Function()? equipmentStreamBuilder;
  final bool showMapTiles;

  const MapSection({
    super.key,
    required this.currentUserId,
    this.firestoreService,
    this.userContextLoader,
    this.equipmentStreamBuilder,
    this.showMapTiles = true,
  });

  @override
  State<MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<MapSection> {
  static const LatLng _fallbackCenter = LatLng(14.2470, 121.1367);
  static const List<double> _radiusOptionsKm = [5, 10, 20];

  late final FirestoreService _firestoreService;

  late Future<DashboardUserContext?> _userContextFuture;

  bool _nearbyOnly = true;
  bool _sortByDistance = true;
  double _radiusKm = 10;
  bool _showCropRecommendedOnly = false;
  String? _activeCropCategory;
  DashboardCoordinateSource _preferredCoordinateSource =
      DashboardCoordinateSource.farm;

  @override
  void initState() {
    super.initState();
    _firestoreService = widget.firestoreService ?? FirestoreService();
    _userContextFuture = _loadUserContext();
  }

  @override
  void didUpdateWidget(covariant MapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.userContextLoader != widget.userContextLoader) {
      _userContextFuture = _loadUserContext();
    }
  }

  Future<DashboardUserContext?> _loadUserContext() async {
    if (widget.userContextLoader != null) {
      return widget.userContextLoader!(widget.currentUserId);
    }

    final userId = widget.currentUserId;
    if (userId == null) return null;

    final profileDoc = await _firestoreService.getUserProfile(userId);
    if (!profileDoc.exists) return null;

    final data = profileDoc.data() as Map<String, dynamic>?;
    if (data == null) return null;

    final cropPreferences =
        await _firestoreService.getCropPreferences(userId) ?? [];

    return DashboardUserContext(
      homeAddress: data['address'] as String?,
      farmAddress: data['farmAddress'] as String?,
      homeLatitude: _asDouble(data['latitude']),
      homeLongitude: _asDouble(data['longitude']),
      farmLatitude: _asDouble(data['farmLatitude']),
      farmLongitude: _asDouble(data['farmLongitude']),
      cropPreferences: cropPreferences,
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _resetNearbyState() {
    setState(() {
      _nearbyOnly = true;
      _sortByDistance = true;
      _radiusKm = 10;
      _showCropRecommendedOnly = false;
      _activeCropCategory = null;
      _preferredCoordinateSource = DashboardCoordinateSource.farm;
    });
  }

  @override
  Widget build(BuildContext context) {
    final equipmentStreamBuilder =
        widget.equipmentStreamBuilder ??
        _firestoreService.getDashboardBrowseEquipmentStream;

    return FutureBuilder<DashboardUserContext?>(
      future: _userContextFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(context);
        }

        if (userSnapshot.hasError) {
          return _buildErrorCard(context, 'Could not load nearby settings.');
        }

        final userContext = userSnapshot.data;
        final userId = widget.currentUserId;
        if (userId == null || userContext == null) {
          return _buildErrorCard(context, 'Sign in to use nearby equipment.');
        }

        return StreamBuilder<List<Equipment>>(
          stream: equipmentStreamBuilder(),
          builder: (context, equipmentSnapshot) {
            if (equipmentSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard(context);
            }

            if (equipmentSnapshot.hasError) {
              return _buildErrorCard(
                context,
                'Could not load nearby equipment.',
              );
            }

            final allEquipment = equipmentSnapshot.data ?? const <Equipment>[];
            return _buildContent(
              context: context,
              userId: userId,
              userContext: userContext,
              allEquipment: allEquipment,
            );
          },
        );
      },
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required String userId,
    required DashboardUserContext userContext,
    required List<Equipment> allEquipment,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final coordinateOptions = _availableCoordinateSources(userContext);
    final selectedCoordinateSource =
        coordinateOptions.contains(_preferredCoordinateSource)
        ? _preferredCoordinateSource
        : (coordinateOptions.isNotEmpty ? coordinateOptions.first : null);

    final origin = _originFromSource(userContext, selectedCoordinateSource);
    final recommendedCategories = recommendedToolTypes(
      userContext.cropPreferences,
    );

    Set<String>? allowedCategories;
    if (_activeCropCategory != null) {
      allowedCategories = {_activeCropCategory!};
    } else if (_showCropRecommendedOnly && recommendedCategories.isNotEmpty) {
      allowedCategories = recommendedCategories;
    }

    List<NearbyEquipmentResult> nearbyResults = const [];

    if (origin != null) {
      nearbyResults = _firestoreService.buildDashboardNearbyResults(
        equipmentList: allEquipment,
        currentUserId: userId,
        originLat: origin.latitude,
        originLng: origin.longitude,
        nearbyOnly: _nearbyOnly,
        radiusKm: _radiusKm,
        sortByDistanceWhenNearbyEnabled: _sortByDistance,
        allowedCategories: allowedCategories,
        includeWithoutCoordinatesWhenNearbyDisabled: true,
      );
    } else if (!_nearbyOnly) {
      nearbyResults = allEquipment
          .where((equipment) {
            if (equipment.ownerId == userId) return false;
            if (!_firestoreService.isEquipmentEffectivelyAvailable(equipment)) {
              return false;
            }
            if (allowedCategories != null && allowedCategories.isNotEmpty) {
              final category = equipment.category;
              if (category == null || !allowedCategories.contains(category)) {
                return false;
              }
            }
            return true;
          })
          .map(
            (equipment) =>
                NearbyEquipmentResult(equipment: equipment, distanceKm: null),
          )
          .toList();
    }

    final markerResults = nearbyResults
        .where(
          (result) =>
              result.equipment.latitude != null &&
              result.equipment.longitude != null,
        )
        .take(20)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Equipment',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RentScreen()),
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View All',
                style: TextStyle(
                  fontSize: 13,
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildMapCard(
          context: context,
          origin: origin,
          markerResults: markerResults,
        ),
        const SizedBox(height: 10),
        _buildNearbyControls(
          context: context,
          userContext: userContext,
          coordinateOptions: coordinateOptions,
          recommendedCategories: recommendedCategories,
          selectedCoordinateSource: selectedCoordinateSource,
        ),
        const SizedBox(height: 10),
        _buildResultSection(
          context: context,
          origin: origin,
          nearbyResults: nearbyResults,
        ),
      ],
    );
  }

  Widget _buildMapCard({
    required BuildContext context,
    required LatLng? origin,
    required List<NearbyEquipmentResult> markerResults,
  }) {
    final mapCenter = origin ?? _fallbackCenter;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 12,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              if (widget.showMapTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bukidbayan.app',
                ),
              if (origin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: origin,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                    ...markerResults.map(
                      (result) => Marker(
                        point: LatLng(
                          result.equipment.latitude!,
                          result.equipment.longitude!,
                        ),
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (origin == null)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Set your home or farm location to enable nearby distance search.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNearbyControls({
    required BuildContext context,
    required DashboardUserContext userContext,
    required List<DashboardCoordinateSource> coordinateOptions,
    required Set<String> recommendedCategories,
    required DashboardCoordinateSource? selectedCoordinateSource,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Nearby only',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _nearbyOnly,
                      onChanged: (value) {
                        setState(() {
                          _nearbyOnly = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _resetNearbyState,
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (coordinateOptions.isNotEmpty) ...[
            const Text(
              'Location source',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: coordinateOptions
                  .map(
                    (source) => ChoiceChip(
                      label: Text(_sourceLabel(source)),
                      selected: selectedCoordinateSource == source,
                      onSelected: (_) {
                        setState(() {
                          _preferredCoordinateSource = source;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
          const Text('Radius', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _radiusOptionsKm
                .map(
                  (radius) => ChoiceChip(
                    label: Text('${radius.toInt()} km'),
                    selected: _radiusKm == radius,
                    onSelected: (_) {
                      setState(() {
                        _radiusKm = radius;
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Sort by distance',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _sortByDistance,
                onChanged: (value) {
                  setState(() {
                    _sortByDistance = value;
                  });
                },
              ),
            ],
          ),
          if (recommendedCategories.isNotEmpty) ...[
            const SizedBox(height: 6),
            FilterChip(
              label: const Text('Recommended for My Crops'),
              selected: _showCropRecommendedOnly && _activeCropCategory == null,
              onSelected: (enabled) {
                setState(() {
                  _showCropRecommendedOnly = enabled;
                  if (enabled) {
                    _activeCropCategory = null;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recommendedCategories
                  .toList()
                  .map(
                    (category) => FilterChip(
                      label: Text(category),
                      selected: _activeCropCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _activeCropCategory = selected ? category : null;
                          if (selected) {
                            _showCropRecommendedOnly = false;
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
          if (recommendedCategories.isEmpty &&
              userContext.cropPreferences.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No recommendation categories available for your crop setup yet.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSection({
    required BuildContext context,
    required LatLng? origin,
    required List<NearbyEquipmentResult> nearbyResults,
  }) {
    if (origin == null && _nearbyOnly) {
      return _buildInfoMessage(
        context,
        icon: Icons.location_off_outlined,
        title: 'Missing location',
        subtitle:
            'Nearby search needs home or farm coordinates. Turn off "Nearby only" to view all available equipment.',
      );
    }

    if (nearbyResults.isEmpty) {
      if (_nearbyOnly) {
        return _buildInfoMessage(
          context,
          icon: Icons.search_off_rounded,
          title: 'No equipment in radius',
          subtitle: 'Try a larger radius or reset your nearby filters.',
        );
      }
      return _buildInfoMessage(
        context,
        icon: Icons.filter_alt_off_rounded,
        title: 'No matching equipment',
        subtitle: 'Try clearing the crop drill-down or nearby filters.',
      );
    }

    final visibleResults = nearbyResults.take(5).toList();

    return Column(
      children: [
        ...visibleResults.map(
          (result) => _NearbyEquipmentCard(
            equipment: result.equipment,
            distanceKm: result.distanceKm,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductPage(item: result.equipment),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      height: 260,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  List<DashboardCoordinateSource> _availableCoordinateSources(
    DashboardUserContext userContext,
  ) {
    final sources = <DashboardCoordinateSource>[];
    if (userContext.hasFarmCoordinates) {
      sources.add(DashboardCoordinateSource.farm);
    }
    if (userContext.hasHomeCoordinates) {
      sources.add(DashboardCoordinateSource.home);
    }
    return sources;
  }

  LatLng? _originFromSource(
    DashboardUserContext userContext,
    DashboardCoordinateSource? source,
  ) {
    if (source == null) return null;

    switch (source) {
      case DashboardCoordinateSource.farm:
        if (userContext.hasFarmCoordinates) {
          return LatLng(userContext.farmLatitude!, userContext.farmLongitude!);
        }
        return null;
      case DashboardCoordinateSource.home:
        if (userContext.hasHomeCoordinates) {
          return LatLng(userContext.homeLatitude!, userContext.homeLongitude!);
        }
        return null;
    }
  }

  String _sourceLabel(DashboardCoordinateSource source) {
    switch (source) {
      case DashboardCoordinateSource.farm:
        return 'Farm';
      case DashboardCoordinateSource.home:
        return 'Home';
    }
  }
}

class _NearbyEquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final double? distanceKm;
  final VoidCallback onTap;

  const _NearbyEquipmentCard({
    required this.equipment,
    required this.distanceKm,
    required this.onTap,
  });

  bool _isNetworkUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  bool _isAssetUrl(String url) => url.startsWith('assets/');

  String _rateSuffix(String rentalUnit) {
    final value = rentalUnit.toLowerCase();
    if (value.contains('hour')) return '/hour';
    if (value.contains('day')) return '/day';
    if (value.contains('week')) return '/week';
    if (value.contains('month')) return '/month';
    if (value.contains('kg')) return '/kg';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = equipment.imageUrls.isNotEmpty
        ? equipment.imageUrls.first
        : 'assets/images/rent1.jpg';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: _buildImage(imageUrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equipment.category ?? 'Uncategorized',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PHP ${equipment.price.toStringAsFixed(0)} ${_rateSuffix(equipment.rentalUnit)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      distanceKm != null
                          ? '${distanceKm!.toStringAsFixed(1)} km away'
                          : 'Location not set',
                      style: TextStyle(
                        fontSize: 12,
                        color: distanceKm != null
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (_isNetworkUrl(imageUrl)) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
      );
    }

    if (_isAssetUrl(imageUrl)) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
      );
    }

    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: const Icon(Icons.agriculture_rounded, color: Colors.grey),
    );
  }
}

class DashboardUserContext {
  final String? homeAddress;
  final String? farmAddress;
  final double? homeLatitude;
  final double? homeLongitude;
  final double? farmLatitude;
  final double? farmLongitude;
  final List<String> cropPreferences;

  const DashboardUserContext({
    required this.homeAddress,
    required this.farmAddress,
    required this.homeLatitude,
    required this.homeLongitude,
    required this.farmLatitude,
    required this.farmLongitude,
    required this.cropPreferences,
  });

  bool get hasHomeCoordinates => homeLatitude != null && homeLongitude != null;
  bool get hasFarmCoordinates => farmLatitude != null && farmLongitude != null;
}
