// profile_screen.dart
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/services/agromonitoring_service.dart';
import 'package:bukidbayan_app/services/app_language.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bukidbayan_app/screens/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';

// Must match the options in signup_screen.dart
const List<Map<String, dynamic>> _locationTypes = [
  {'value': 'Home', 'label': 'Home', 'icon': Icons.home_rounded},
  {'value': 'Farm', 'label': 'Farm / Field', 'icon': Icons.grass_rounded},
  {'value': 'Business', 'label': 'Business', 'icon': Icons.store_rounded},
  {
    'value': 'Current Location',
    'label': 'Current Location',
    'icon': Icons.my_location_rounded,
  },
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> logout() async => _auth.signOut();

  // ── Generic single-field text editor ────────────────────────────────────
  void _showEditDialog(
    String field,
    String label,
    String currentValue, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLanguage.text(en: 'Edit $label', tl: 'I-edit ang $label'),
        ),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.phone
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLanguage.text(en: 'Cancel', tl: 'Kanselahin')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  final user = _auth.currentUser;
                  if (user != null) {
                    await _authService.updateUserData(user.uid, {
                      field: controller.text.trim(),
                    });

                    if (field == 'firstName' || field == 'lastName') {
                      final firstName = field == 'firstName'
                          ? controller.text.trim()
                          : _userData?['firstName'] ?? '';
                      final lastName = field == 'lastName'
                          ? controller.text.trim()
                          : _userData?['lastName'] ?? '';
                      await user.updateDisplayName('$firstName $lastName');
                    }

                    await _loadUserData();
                    if (mounted) Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLanguage.text(
                              en: 'Profile updated successfully',
                              tl: 'Matagumpay na na-update ang profile',
                            ),
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: Text(AppLanguage.text(en: 'Save', tl: 'I-save')),
          ),
        ],
      ),
    );
  }

  // ── Location type picker dialog ──────────────────────────────────────────
  void _showLocationTypeDialog() {
    String selected = _userData?['locationType'] ?? 'Home';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            AppLanguage.text(en: 'Location Type', tl: 'Uri ng Lokasyon'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _locationTypes.map((type) {
              final isSelected = selected == type['value'];
              return GestureDetector(
                onTap: () =>
                    setDialogState(() => selected = type['value'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? lightColorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? lightColorScheme.primary
                          : Colors.black12,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        color: isSelected
                            ? lightColorScheme.primary
                            : Colors.black45,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLanguage.locationTypeLabel(type['value'] as String),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? lightColorScheme.primary
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLanguage.text(en: 'Cancel', tl: 'Kanselahin')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final user = _auth.currentUser;
                  if (user != null) {
                    await _authService.updateUserData(user.uid, {
                      'locationType': selected,
                    });
                    await _loadUserData();
                    if (mounted) Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Text(AppLanguage.text(en: 'Save', tl: 'I-save')),
            ),
          ],
        ),
      ),
    );
  }

  // ── Address editor (map picker + geocodes on save) ───────────────────────
  void _showAddressEditDialog() {
    final controller = TextEditingController(text: _userData?['address'] ?? '');
    bool isSaving = false;

    // Coordinates from the map picker (null if user typed manually).
    double? pickedLat;
    double? pickedLng;
    String? pickedAddress;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> openPicker() async {
            // Build initial position from existing user data (if any).
            final existingLat = _userData?['latitude'] as num?;
            final existingLng = _userData?['longitude'] as num?;
            final initial = (existingLat != null && existingLng != null)
                ? LatLng(existingLat.toDouble(), existingLng.toDouble())
                : null;

            final result = await Navigator.push<LocationPickerResult>(
              dialogContext,
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(initialPosition: initial),
              ),
            );

            if (result != null && dialogContext.mounted) {
              setDialogState(() {
                controller.text = result.address;
                pickedLat = result.latitude;
                pickedLng = result.longitude;
                pickedAddress = result.address;
              });
            }
          }

          Future<void> save() async {
            final address = controller.text.trim();
            if (address.isEmpty) return;
            setDialogState(() => isSaving = true);
            try {
              double lat, lng;
              if (pickedLat != null && address == pickedAddress) {
                lat = pickedLat!;
                lng = pickedLng!;
              } else {
                final coords = await _authService.validateAndGeocodeAddress(
                  address,
                );
                lat = coords['latitude']!;
                lng = coords['longitude']!;
              }

              final user = _auth.currentUser;
              if (user != null) {
                await _authService.updateUserData(user.uid, {
                  'address': address,
                  'latitude': lat,
                  'longitude': lng,
                });
                await _loadUserData();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLanguage.text(
                          en: 'Address updated successfully',
                          tl: 'Matagumpay na na-update ang address',
                        ),
                      ),
                    ),
                  );
                }
              }
            } catch (e) {
              setDialogState(() => isSaving = false);
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                  ),
                );
              }
            }
          }

          return AlertDialog(
            title: Text(
              AppLanguage.text(en: 'Edit Address', tl: 'I-edit ang Address'),
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.streetAddress,
              onChanged: (_) {
                // User typed manually — clear picker coordinates.
                if (pickedAddress != null && controller.text != pickedAddress) {
                  pickedLat = null;
                  pickedLng = null;
                  pickedAddress = null;
                }
              },
              decoration: InputDecoration(
                labelText: AppLanguage.text(en: 'Address', tl: 'Address'),
                hintText: AppLanguage.text(
                  en: 'Type or pick on map',
                  tl: 'Mag-type o pumili sa mapa',
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: AppLanguage.text(
                    en: 'Pick location on map',
                    tl: 'Pumili ng lokasyon sa mapa',
                  ),
                  onPressed: openPicker,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text(AppLanguage.text(en: 'Cancel', tl: 'Kanselahin')),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppLanguage.text(en: 'Save', tl: 'I-save')),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Farm address editor ──────────────────────────────────────────────────
  void _showFarmAddressEditDialog() {
    final controller = TextEditingController(
      text: _userData?['farmAddress'] ?? '',
    );
    bool isSaving = false;

    double? pickedLat;
    double? pickedLng;
    String? pickedAddress;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> openPicker() async {
            final existingLat = _userData?['farmLatitude'] as num?;
            final existingLng = _userData?['farmLongitude'] as num?;
            final initial = (existingLat != null && existingLng != null)
                ? LatLng(existingLat.toDouble(), existingLng.toDouble())
                : null;

            final result = await Navigator.push<LocationPickerResult>(
              dialogContext,
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(initialPosition: initial),
              ),
            );

            if (result != null && dialogContext.mounted) {
              setDialogState(() {
                controller.text = result.address;
                pickedLat = result.latitude;
                pickedLng = result.longitude;
                pickedAddress = result.address;
              });
            }
          }

          Future<void> save() async {
            final address = controller.text.trim();
            if (address.isEmpty) return;
            setDialogState(() => isSaving = true);
            try {
              double lat, lng;
              if (pickedLat != null && address == pickedAddress) {
                lat = pickedLat!;
                lng = pickedLng!;
              } else {
                final coords = await _authService.validateAndGeocodeAddress(
                  address,
                );
                lat = coords['latitude']!;
                lng = coords['longitude']!;
              }

              // Re-register polygon with Agromonitoring
              String? polygonId;
              try {
                final firstName = _userData?['firstName'] as String? ?? '';
                final lastName = _userData?['lastName'] as String? ?? '';
                polygonId = await AgromonitoringService().createPolygon(
                  lat,
                  lng,
                  '$firstName $lastName'.trim(),
                );
              } catch (e) {
                // Non-fatal — continue without polygon update
                debugPrint('⚠️ Agromonitoring polygon creation failed: $e');
              }

              final user = _auth.currentUser;
              if (user != null) {
                final updates = <String, dynamic>{
                  'farmAddress': address,
                  'farmLatitude': lat,
                  'farmLongitude': lng,
                };
                if (polygonId != null) updates['farmPolygonId'] = polygonId;

                await _authService.updateUserData(user.uid, updates);
                await _loadUserData();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLanguage.text(
                          en: 'Farm address updated successfully',
                          tl: 'Matagumpay na na-update ang farm address',
                        ),
                      ),
                    ),
                  );
                }
              }
            } catch (e) {
              setDialogState(() => isSaving = false);
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                  ),
                );
              }
            }
          }

          return AlertDialog(
            title: Text(
              AppLanguage.text(
                en: 'Edit Farm Field Address',
                tl: 'I-edit ang Farm Field Address',
              ),
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.streetAddress,
              onChanged: (_) {
                if (pickedAddress != null && controller.text != pickedAddress) {
                  pickedLat = null;
                  pickedLng = null;
                  pickedAddress = null;
                }
              },
              decoration: InputDecoration(
                labelText: AppLanguage.text(
                  en: 'Farm Field Address',
                  tl: 'Farm Field Address',
                ),
                hintText: AppLanguage.text(
                  en: 'Type or pick on map',
                  tl: 'Mag-type o pumili sa mapa',
                ),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: AppLanguage.text(
                    en: 'Pick location on map',
                    tl: 'Pumili ng lokasyon sa mapa',
                  ),
                  onPressed: openPicker,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: Text(AppLanguage.text(en: 'Cancel', tl: 'Kanselahin')),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(AppLanguage.text(en: 'Save', tl: 'I-save')),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return AppLanguageScope(
      builder: (context) => Scaffold(
        drawer: CustomDrawer(onLogout: logout),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : user == null
            ? Center(
                child: Text(
                  AppLanguage.text(
                    en: 'No user logged in',
                    tl: 'Walang naka-log in na user',
                  ),
                ),
              )
            : _buildBody(context, user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, User user) {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            backgroundColor: Theme.of(context).primaryColor,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildSliverBackground(context, user),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildInfoCard(context, user),
                  const SizedBox(height: 24),
                  _buildLocationCard(context),
                  const SizedBox(height: 24),
                  _buildFarmCard(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverBackground(BuildContext context, User user) {
    final phone = _userData?['phoneNumber'] ?? user.phoneNumber ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightColorScheme.primary, lightColorScheme.secondary],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 60,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),

          // Avatar + name + phone
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    _getInitials(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.displayName ?? AppLanguage.text(en: 'User', tl: 'User'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone.isNotEmpty ? phone : '—',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile info card (name + phone) ────────────────────────────────────
  Widget _buildInfoCard(BuildContext context, User user) {
    final phone = _userData?['phoneNumber'] ?? user.phoneNumber ?? 'N/A';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguage.text(
                en: 'Profile Information',
                tl: 'Impormasyon ng Profile',
              ),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),

            _buildInfoRow(
              icon: Icons.person,
              label: AppLanguage.text(en: 'First Name', tl: 'Pangalan'),
              value: _userData?['firstName'] ?? 'N/A',
              onEdit: () => _showEditDialog(
                'firstName',
                AppLanguage.text(en: 'First Name', tl: 'Pangalan'),
                _userData?['firstName'] ?? '',
              ),
            ),

            _buildInfoRow(
              icon: Icons.person_outline,
              label: AppLanguage.text(en: 'Last Name', tl: 'Apelyido'),
              value: _userData?['lastName'] ?? 'N/A',
              onEdit: () => _showEditDialog(
                'lastName',
                AppLanguage.text(en: 'Last Name', tl: 'Apelyido'),
                _userData?['lastName'] ?? '',
              ),
            ),

            _buildInfoRow(
              icon: Icons.phone_rounded,
              label: AppLanguage.text(
                en: 'Phone Number',
                tl: 'Numero ng Telepono',
              ),
              value: phone,
              onEdit:
                  null, // phone is Firebase Auth identity — can't change casually
            ),

            if (_userData?['createdAt'] != null)
              _buildInfoRow(
                icon: Icons.calendar_today,
                label: AppLanguage.text(
                  en: 'Member Since',
                  tl: 'Miyembro Mula',
                ),
                value: _formatDate(_userData!['createdAt']),
                onEdit: null,
              ),
          ],
        ),
      ),
    );
  }

  // ── Location card ────────────────────────────────────────────────────────
  Widget _buildLocationCard(BuildContext context) {
    final address = _userData?['address'] ?? 'N/A';
    final locationType = _userData?['locationType'] ?? 'N/A';
    final lat = _userData?['latitude'];
    final lng = _userData?['longitude'];

    // Find matching icon for current type
    final typeIcon =
        _locationTypes.firstWhere(
              (t) => t['value'] == locationType,
              orElse: () => {'icon': Icons.location_on_rounded},
            )['icon']
            as IconData;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguage.text(en: 'Location', tl: 'Lokasyon'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),

            _buildInfoRow(
              icon: typeIcon,
              label: AppLanguage.text(
                en: 'Location Type',
                tl: 'Uri ng Lokasyon',
              ),
              value: AppLanguage.locationTypeLabel(locationType),
              onEdit: _showLocationTypeDialog,
            ),

            _buildInfoRow(
              icon: Icons.home_work_rounded,
              label: AppLanguage.text(en: 'Address', tl: 'Address'),
              value: address,
              onEdit: _showAddressEditDialog,
            ),

            if (lat != null && lng != null)
              _buildInfoRow(
                icon: Icons.my_location_rounded,
                label: AppLanguage.text(
                  en: 'GPS Coordinates',
                  tl: 'GPS Coordinates',
                ),
                value:
                    '${(lat as num).toStringAsFixed(5)}, ${(lng as num).toStringAsFixed(5)}',
                onEdit: null,
              ),
          ],
        ),
      ),
    );
  }

  // ── Farm field card ──────────────────────────────────────────────────────
  Widget _buildFarmCard(BuildContext context) {
    final farmAddress = _userData?['farmAddress'] as String?;
    final lat = _userData?['farmLatitude'] as num?;
    final lng = _userData?['farmLongitude'] as num?;
    final polygonId = _userData?['farmPolygonId'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLanguage.text(en: 'Farm Field', tl: 'Bukid'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),

            _buildInfoRow(
              icon: Icons.grass_rounded,
              label: AppLanguage.text(
                en: 'Farm Field Address',
                tl: 'Address ng Bukid',
              ),
              value: farmAddress?.isNotEmpty == true ? farmAddress! : 'Not set',
              onEdit: _showFarmAddressEditDialog,
            ),

            if (lat != null && lng != null)
              _buildInfoRow(
                icon: Icons.my_location_rounded,
                label: AppLanguage.text(
                  en: 'GPS Coordinates',
                  tl: 'GPS Coordinates',
                ),
                value: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                onEdit: null,
              ),

            _buildInfoRow(
              icon: Icons.satellite_alt_rounded,
              label: AppLanguage.text(
                en: 'NDVI Monitoring',
                tl: 'NDVI Monitoring',
              ),
              value: polygonId != null
                  ? AppLanguage.text(en: 'Registered', tl: 'Rehistrado')
                  : AppLanguage.text(
                      en: 'Not registered',
                      tl: 'Hindi rehistrado',
                    ),
              onEdit: null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared row widget ────────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              color: Theme.of(context).primaryColor,
            ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _getInitials() {
    final first = (_userData?['firstName'] as String? ?? '');
    final last = (_userData?['lastName'] as String? ?? '');
    final initials =
        (first.isNotEmpty ? first[0].toUpperCase() : '') +
        (last.isNotEmpty ? last[0].toUpperCase() : '');
    return initials.isEmpty ? '?' : initials;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = timestamp.toDate() as DateTime;
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
