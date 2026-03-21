import 'package:bukidbayan_app/services/draft_service.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_dropdown_form_field.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/cloudinary_service.dart';
import 'package:bukidbayan_app/screens/location_picker_screen.dart';
import 'package:latlong2/latlong.dart';

const List<String> rentalUnit = <String>[
  'Per Day',
  'Per Hectare'
];

/// Returns (min, max) price limits for a given category, or null if unconstrained.
(double min, double max)? getCategoryPriceLimits(String? category) {
  if (category == null) return null;
  final c = category.toLowerCase();
  // Order matters: check 'hand tractor' before plain 'tractor'
  if (c.contains('hand tractor') || c.contains('kuliglig'))    return (2000, 5000);
  if (c.contains('tractor'))         return (5000, 10000);
  if (c.contains('harvester') || c.contains('halimaw')) return (3500, 8000);
  if (c.contains('floating tiller') || c.contains('Pagong')) return (2000, 5000);
  if (c.contains('machine'))         return (500,  5000);
  if (c.contains('hand tool'))       return (50,   1000);
  if (c.contains('implement'))       return (1000, 3000);
  return null;
}

const List<String> condition = <String>[
  'Brand New',
  'Excellent',
  'Good',
  'Fair',
];

final List<String> yearOptions = List.generate(
  20,
  (i) => (DateTime.now().year - i).toString(),
);
const List<String> powerOptions = [
  '10 HP',
  '20 HP',
  '24 HP',
  '32 HP',
  '34 HP',
  '50 HP',
  '75 HP',
];

class EquipmentListingScreen extends StatefulWidget {
  final Equipment? existingEquipment;
    final String? draftId;
final Map<String, dynamic>? draftData;

  const EquipmentListingScreen({  super.key,
  this.existingEquipment,
  this.draftId,
  this.draftData,});

  @override
  State<EquipmentListingScreen> createState() => _EquipmentListingScreenState();
}

class _EquipmentListingScreenState extends State<EquipmentListingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _equipmentNameController        = TextEditingController();
  final _equipmentDescriptionController = TextEditingController();
  final _equipmentPriceController       = TextEditingController();
  final _equipmentBrandController       = TextEditingController();
  final _landSizeController             = TextEditingController();
  final _yearController                 = TextEditingController();
  final _powerController                = TextEditingController();
  final _fuelController                 = TextEditingController();
  final _attachmentsController          = TextEditingController();
  final _defectsController              = TextEditingController();
  final _landSizeMinController          = TextEditingController();
  final _landSizeMaxController          = TextEditingController();
  final _maxCropHeightController        = TextEditingController();
  final _minimumVolumeController        = TextEditingController();
  final _riceOnlyPriceController        = TextEditingController();
  final _ricePlusDarakPriceController   = TextEditingController();
  final _cropSharePercentController     = TextEditingController();
  final _maintenanceIntervalController  = TextEditingController();

  // ── Address controllers ─────────────────────────────────────────────────
  final _otherAddressController = TextEditingController();

  String _addressMode = 'my';
  String? _profileAddress;
  double? _profileLat;
  double? _profileLng;
  double? _pickedLat;
  double? _pickedLng;
  String? _pickedAddress;

  // ── Other existing fields ───────────────────────────────────────────────
  String? selectedBrand;
  String? selectedYear;
  String? selectedPower;
  String? selectedFuel;

  bool? operatorIncluded;
  bool? landSizeRequirement;
  bool? maxCropHeightRequirement;
  bool? cropConditionRequirement;
  bool showCropConditionError = false;
  final TextEditingController _cropConditionController = TextEditingController();

  bool showLandSizeError    = false;
  bool showCropHeightError  = false;
  bool showImageError       = false;
  bool showAddressError     = false;

  DateTime? availableFrom;
  DateTime? availableUntil;
  bool showAvailabilityError = false;

  bool get _isRiceMill =>
      selectedCategory?.toLowerCase().contains('rice mill') == true;

  List<String> uniqueCategories    = [];
  bool         isLoadingCategories = true;

  List<String> brandOptions    = [];
  List<String> fuelOptions     = [];
  bool         isLoadingDropdowns = true;

  String? selectedCategory;
  String? selectedRentalUnit;
  String? selectedCondition;

  final ImagePicker    _picker = ImagePicker();
  final List<XFile?> images    = List.generate(10, (_) => null);
  bool _isPickingImage         = false;
  List<String> existingImageUrls = [];

  bool?  minimumVolumeRequired;
  bool   showMinVolumeError     = false;
  String selectedMinVolumeUnit  = 'cavans';

  DeliveryMode _selectedDeliveryMode = DeliveryMode.both;

  bool? cropShareRequired;
  bool  showCropShareError = false;
  bool? maintenanceRequired;
  bool  showMaintenanceError = false;
final DraftService _draftService = DraftService();
String? _currentDraftId;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadCategoriesFromFirestore();
    _loadDropdownOptionsFromFirestore();
    _loadProfileAddress();

    if (widget.existingEquipment != null) {
      final eq = widget.existingEquipment!;

      _equipmentNameController.text        = eq.name ?? '';
      _equipmentDescriptionController.text = eq.description ?? '';
      _equipmentPriceController.text       = eq.price?.toString() ?? '';
      _attachmentsController.text          = eq.attachments ?? '';
      _defectsController.text              = eq.defects ?? '';
      _landSizeMinController.text          = eq.landSizeMin ?? '';
      _landSizeMaxController.text          = eq.landSizeMax ?? '';
      _maxCropHeightController.text        = eq.maxCropHeight ?? '';
      _minimumVolumeController.text        = eq.minimumVolumeKg != null
          ? (eq.minimumVolumeUnit == 'cavans'
              ? (eq.minimumVolumeKg! / 50).toStringAsFixed(0)
              : eq.minimumVolumeKg!.toStringAsFixed(0))
          : '';
      _riceOnlyPriceController.text        = eq.riceOnlyPricePerKg?.toString() ?? '2.0';
      _ricePlusDarakPriceController.text   = eq.ricePlusDarakPricePerKg?.toString() ?? '3.0';
      _selectedDeliveryMode = eq.deliveryMode;
      _cropSharePercentController.text =
          eq.cropSharePercent?.toString() ?? '';
      _maintenanceIntervalController.text =
          eq.maintenanceIntervalHrs == 240 ? '240' : eq.maintenanceIntervalHrs.toString();
      _cropConditionController.text = eq.cropCondition ?? '';
      cropConditionRequirement = eq.cropConditionRequirement;
      

      selectedCategory    = eq.category;
      selectedBrand       = eq.brand;
      selectedYear        = eq.yearModel;
      _powerController.text = eq.power ?? '';
      selectedFuel        = eq.fuelType;
      selectedCondition   = eq.condition;
      selectedRentalUnit  = eq.rentalUnit;
      selectedMinVolumeUnit = eq.minimumVolumeUnit;

      operatorIncluded          = eq.operatorIncluded;
      landSizeRequirement       = eq.landSizeRequirement;
      maxCropHeightRequirement  = eq.maxCropHeightRequirement;
      minimumVolumeRequired     = eq.minimumVolumeRequired;

      availableFrom = eq.availableFrom;
      availableUntil = eq.availableUntil;

      cropShareRequired  = eq.cropShareRequired;
      maintenanceRequired = eq.maintenanceRequired;

      if (eq.location != null && eq.location!.isNotEmpty) {
        _addressMode = 'other';
        _otherAddressController.text = eq.location!;
        _pickedLat     = eq.latitude;
        _pickedLng     = eq.longitude;
        _pickedAddress = eq.location;
      }

      final List<String> existingUrls = eq.imageUrls ?? [];
      for (int i = 0; i < existingUrls.length && i < images.length; i++) {
        images[i] = XFile(existingUrls[i]);
      }

      if (widget.existingEquipment == null) {
        _maintenanceIntervalController.text = '240';
      }
    }

    if (widget.draftData != null) {
  final d = widget.draftData!;
  _currentDraftId = widget.draftId;
  _equipmentNameController.text        = d['name'] ?? '';
  _equipmentDescriptionController.text = d['description'] ?? '';
  _equipmentPriceController.text       = d['price']?.toString() ?? '';
  _attachmentsController.text          = d['attachments'] ?? '';
  _defectsController.text              = d['defects'] ?? '';
  _landSizeMinController.text          = d['landSizeMin'] ?? '';
  _landSizeMaxController.text          = d['landSizeMax'] ?? '';
  _maxCropHeightController.text        = d['maxCropHeight'] ?? '';
  _powerController.text                = d['power'] ?? '';
  _riceOnlyPriceController.text        = d['riceOnlyPrice']?.toString() ?? '';
  _ricePlusDarakPriceController.text   = d['ricePlusDarakPrice']?.toString() ?? '';
  _cropSharePercentController.text     = d['cropSharePercent']?.toString() ?? '';
  _maintenanceIntervalController.text  = d['maintenanceInterval']?.toString() ?? '';
  selectedCategory    = d['category'];
  selectedBrand       = d['brand'];
  selectedYear        = d['yearModel'];
  selectedFuel        = d['fuelType'];
  selectedCondition   = d['condition'];
  selectedRentalUnit  = d['rentalUnit'];
  operatorIncluded    = d['operatorIncluded'] as bool?;
  landSizeRequirement = d['landSizeRequirement'] as bool?;
  maxCropHeightRequirement = d['maxCropHeightRequirement'] as bool?;
  cropConditionRequirement = d['cropConditionRequirement'] as bool?;
  cropShareRequired   = d['cropShareRequired'] as bool?;
  final savedUrls = (d['imageUrls'] as List<dynamic>?)
      ?.map((e) => e.toString())
      .toList() ?? [];
  for (int i = 0; i < savedUrls.length && i < images.length; i++) {
    images[i] = XFile(savedUrls[i]);
  }
  final fromStr = d['availableFrom'] as String?;
  final untilStr = d['availableUntil'] as String?;
  if (fromStr != null) availableFrom = DateTime.tryParse(fromStr);
  if (untilStr != null) availableUntil = DateTime.tryParse(untilStr);
  _cropConditionController.text = d['cropCondition'] ?? '';

}
  }

  @override
  void dispose() {
    _otherAddressController.dispose();
    _cropConditionController.dispose();
    _cropSharePercentController.dispose();
    _maintenanceIntervalController.dispose();
    super.dispose();
  }

  // ── Load profile address ─────────────────────────────────────────────────

  Future<void> _loadProfileAddress() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;
      final data = await authService.getUserData(user.uid);
      if (data != null && mounted) {
        setState(() {
          _profileAddress = data['address'] as String?;
          _profileLat     = (data['latitude']  as num?)?.toDouble();
          _profileLng     = (data['longitude'] as num?)?.toDouble();

          if (widget.existingEquipment == null && _addressMode != 'other') {
            _addressMode = 'my';
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile address: $e');
    }
  }

  // ── Map picker helper ────────────────────────────────────────────────────

  Future<void> _openMapPicker() async {
    final existingLat = _pickedLat ?? _profileLat;
    final existingLng = _pickedLng ?? _profileLng;
    final initial = (existingLat != null && existingLng != null)
        ? LatLng(existingLat, existingLng)
        : null;

    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialPosition: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _otherAddressController.text = result.address;
        _pickedLat     = result.latitude;
        _pickedLng     = result.longitude;
        _pickedAddress = result.address;
        showAddressError = false;
      });
    }
  }

  // ── Computed address values for save ─────────────────────────────────────

  String? get _resolvedLocation {
    if (_addressMode == 'my') return _profileAddress;
    final text = _otherAddressController.text.trim();
    return text.isEmpty ? null : text;
  }

  double? get _resolvedLat =>
      _addressMode == 'my' ? _profileLat : _pickedLat;

  double? get _resolvedLng =>
      _addressMode == 'my' ? _profileLng : _pickedLng;

  bool get _addressIsValid {
    if (_addressMode == 'my') {
      return _profileAddress != null && _profileAddress!.isNotEmpty;
    }
    return _otherAddressController.text.trim().isNotEmpty;
  }

  // ── Firestore loaders ────────────────────────────────────────────────────

  Future<void> _loadCategoriesFromFirestore() async {
    final firestoreService = FirestoreService();
    try {
      final categories = await firestoreService.getUniqueEquipmentCategories();
      setState(() {
        uniqueCategories    = categories;
        isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => isLoadingCategories = false);
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _loadDropdownOptionsFromFirestore() async {
    final firestoreService = FirestoreService();
    try {
      final options = await firestoreService.fetchEquipmentDropdownOptions();
      setState(() {
        brandOptions        = options['brands'] ?? [];
        fuelOptions         = options['fuelTypes'] ?? [];
        isLoadingDropdowns  = false;
      });
    } catch (e) {
      setState(() => isLoadingDropdowns = false);
      debugPrint('Failed to load dropdown options: $e');
    }
  }

  bool get _isHarvester =>
    selectedCategory?.toLowerCase().contains('harvester') == true ||
    selectedCategory?.toLowerCase().contains('halimaw') == true;


  void _showMissingFieldsSheet(List<String> missing) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline_rounded,
                      color: Colors.red.shade600, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hindi pa kumpleto ang form',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Pakitapos ang mga sumusunod bago mag-save:',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (missing.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'May mga patlang na may maling halaga. '
                        'Tingnan ang mga pulang mensahe sa form.',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...missing.map((field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.radio_button_unchecked,
                          size: 14, color: Colors.red.shade400),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        field,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightColorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Bumalik sa Form',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Resolve price limits for the currently selected category
    final priceLimits = getCategoryPriceLimits(selectedCategory);

    return PopScope(
       canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _confirmCancel(context);
        },
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lightColorScheme.primary, lightColorScheme.secondary],
                stops: const [0.0, 0.9],
              ),
            ),
          ),
          centerTitle: true,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Equipment Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: lightColorScheme.primary,
                      ),
                    ),
                  ),
      
                  const SizedBox(height: 10),
      
                  // ── Image picker ─────────────────────────────────────────
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final XFile? image = images[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: GestureDetector(
                            onTap: () => pickImage(index),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                border: Border.all(color: lightColorScheme.primary),
                                borderRadius: BorderRadius.circular(8),
                                color: lightColorScheme.primary.withOpacity(0.2),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Builder(
                                        builder: (_) {
                                          if (image != null && !image.path.startsWith('http')) {
                                            return kIsWeb
                                                ? Image.network(image.path, fit: BoxFit.cover)
                                                : Image.file(File(image.path), fit: BoxFit.cover);
                                          }
                                          if (image != null && image.path.startsWith('http')) {
                                            return Image.network(image.path, fit: BoxFit.cover);
                                          }
                                          return const Center(
                                            child: Icon(Icons.add, size: 32, color: Colors.white),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  if (image != null)
                                    Positioned(
                                      top: 2, right: 2,
                                      child: GestureDetector(
                                        onTap: () => setState(() => images[index] = null),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 18, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      
                  if (showImageError)
                    Padding(
                      padding: EdgeInsets.fromLTRB(8,4,0,0),
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined,
                                size: 14, color: Colors.red.shade600),
                            const SizedBox(width: 6),
                            Text('Mag-upload ng kahit isang larawan',
                                style: TextStyle(color: Colors.red.shade700,
                                    fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    ),
      
                  const SizedBox(height: 15),
      
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
      
                        // ── CATEGORY ───────────────────────────────────────
                        const Text('Equipment Category',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: uniqueCategories.contains(selectedCategory) ? selectedCategory : null,
                          isExpanded: true,
                          dropdownColor: lightColorScheme.onPrimary,
                          decoration: InputDecoration(
                            hintText: 'Select Category',
                            hintStyle: const TextStyle(color: Colors.black12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: lightColorScheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
                            ),
                            prefixIcon: selectedCategory != null
                                ? IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() => selectedCategory = null),
                                  )
                                : null,
                          ),
                          items: isLoadingCategories
                              ? []
                              : uniqueCategories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                          onChanged: isLoadingCategories
                            ? null
                            : (val) {
                                setState(() {
                                  selectedCategory = val;
                                  _equipmentPriceController.clear();
                                  if (val?.toLowerCase().contains('rice mill') != true) {
                                    minimumVolumeRequired = null;
                                    _minimumVolumeController.clear();
                                    showMinVolumeError = false;
                                  }

                                  // ── Auto-fill land size min/max based on category ──
                                  final cat = val?.toLowerCase();
                                  final isAutoCategory = cat == 'tractor' ||
                                      cat == 'harvester (halimaw)' ||
                                      cat == 'hand tractor (kuliglig)' ||
                                      cat == 'floating tiller (pagong)';

                                  if (isAutoCategory) {
                                    final haPerDay = (cat == 'hand tractor (kuliglig)' ||
                                            cat == 'floating tiller (pagong)')
                                        ? 1.0
                                        : 2.0;
                                    _landSizeMinController.text = '1';
                                    _landSizeMaxController.text = (haPerDay * 5).toStringAsFixed(0);
                                    landSizeRequirement = true; // auto-enable 
                                    showLandSizeError = false;
                                  } else {
                                    // Clear for non-auto categories
                                    _landSizeMinController.clear();
                                    _landSizeMaxController.clear();
                                  }
                                });
                              },
                          validator: (v) => v == null ? 'Please select a category' : null,
                        ),
      
                        const SizedBox(height: 16),
      
                        // ── LISTING NAME ───────────────────────────────────
                        const Text('Listing Name',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        CustomTextFormField(
                          controller: _equipmentNameController,
                          hint: 'Equipment Name (e.g. Tractor)',
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Please enter equipment name' : null,
                        ),
      
                        const SizedBox(height: 16),
      
                        // ── DESCRIPTION ────────────────────────────────────
                        const Text('Description',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        CustomTextFormField(
                          controller: _equipmentDescriptionController,
                          hint: 'Brief description of the equipment',
                          maxLines: 4,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Please enter a description' : null,
                        ),
      
                        const SizedBox(height: 16),
      
                        // ── EQUIPMENT ADDRESS ──────────────────────────────
                        const Text('Equipment Location',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          'Saan nakalagay o pwedeng i-pickup ang kagamitan',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 10),
      
                        Row(
                          children: [
                            Expanded(
                              child: _AddressOptionCard(
                                icon: Icons.home_rounded,
                                label: 'My Address',
                                subtitle: _profileAddress != null && _profileAddress!.isNotEmpty
                                    ? _profileAddress!
                                    : 'No address in profile',
                                isSelected: _addressMode == 'my',
                                isDisabled: _profileAddress == null || _profileAddress!.isEmpty,
                                onTap: () {
                                  if (_profileAddress != null && _profileAddress!.isNotEmpty) {
                                    setState(() {
                                      _addressMode = 'my';
                                      showAddressError = false;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AddressOptionCard(
                                icon: Icons.edit_location_alt_rounded,
                                label: 'Other Address',
                                subtitle: (_addressMode == 'other' &&
                                        _otherAddressController.text.isNotEmpty)
                                    ? _otherAddressController.text
                                    : 'Tap to set address',
                                isSelected: _addressMode == 'other',
                                isDisabled: false,
                                onTap: () => setState(() {
                                  _addressMode = 'other';
                                  showAddressError = false;
                                }),
                              ),
                            ),
                          ],
                        ),
      
                        if (_addressMode == 'other') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _otherAddressController,
                            keyboardType: TextInputType.streetAddress,
                            onChanged: (v) {
                              if (_pickedAddress != null && v != _pickedAddress) {
                                _pickedLat     = null;
                                _pickedLng     = null;
                                _pickedAddress = null;
                              }
                              if (showAddressError) setState(() => showAddressError = false);
                            },
                            decoration: InputDecoration(
                              hintText: 'Type address or pick on map',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: lightColorScheme.primary.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    BorderSide(color: lightColorScheme.primary, width: 2),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.map_outlined,
                                    color: lightColorScheme.primary),
                                tooltip: 'Pick on map',
                                onPressed: _openMapPicker,
                              ),
                            ),
                            validator: (_) => null,
                          ),
                          if (_pickedLat != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 14, color: Colors.green.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  'Location pinned on map',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.green.shade600),
                                ),
                              ],
                            ),
                          ],
                        ],
      
                        if (showAddressError)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Please set an equipment location',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
      
                        const Padding(
                          padding: EdgeInsets.all(5),
                          child: Divider(thickness: 1),
                        ),
      
                        // ── TECHNICAL SPECS ────────────────────────────────
                        const Text(
                          'Technical Specifications',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
      
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Brand / Model', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  CustomDropdownFormField(
                                    value: brandOptions.contains(selectedBrand) ? selectedBrand : null,
                                    options: isLoadingDropdowns ? [] : brandOptions,
                                    hint: isLoadingDropdowns ? 'Loading...' : 'Select Brand',
                                    onChanged: isLoadingDropdowns
                                        ? (_) {}
                                        : (v) => setState(() => selectedBrand = v),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Year Model', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  CustomDropdownFormField(
                                    value: selectedYear,
                                    options: yearOptions,
                                    hint: 'Select Year',
                                    onChanged: (v) => setState(() => selectedYear = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
      
                        const SizedBox(height: 12),
      
                        Row(
                          children: [
                           Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Power / Capacity (HP)', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  CustomTextFormField(
                                    controller: _powerController,
                                    hint: 'e.g. 24',
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Fuel Type', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  CustomDropdownFormField(
                                    value: fuelOptions.contains(selectedFuel) ? selectedFuel : null,
                                    options: isLoadingDropdowns ? [] : fuelOptions,
                                    hint: isLoadingDropdowns ? 'Loading...' : 'Select Fuel Type',
                                    onChanged: isLoadingDropdowns
                                        ? (_) {}
                                        : (v) => setState(() => selectedFuel = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
      
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Condition', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: selectedCondition,
                              isExpanded: true,
                              dropdownColor: lightColorScheme.onPrimary,
                              decoration: InputDecoration(
                                hintText: 'e.g. Brand New / Excellent',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: lightColorScheme.primary.withOpacity(0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: lightColorScheme.primary, width: 2),
                                ),
                                prefixIcon: selectedCondition != null
                                    ? IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => setState(() => selectedCondition = null),
                                      )
                                    : null,
                              ),
                              items: condition
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => selectedCondition = v),
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                            if (getConditionHelpText(selectedCondition) != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                getConditionHelpText(selectedCondition)!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                            if (selectedCondition == 'Needs Maintenance') ...[
                              const SizedBox(height: 6),
                              Text('Please list the defects or issues:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                              const SizedBox(height: 4),
                              CustomTextFormField(
                                controller: _defectsController,
                                hint: 'e.g. Broken hydraulic pump, worn tires',
                                maxLines: 3,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Please describe the defects'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
      
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Attachments Included', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            CustomTextFormField(
                              hint: 'e.g. Plow, Harrow',
                              controller: _attachmentsController,
                            ),
                          ],
                        ),
      
                        const SizedBox(height: 16),
                        const Text('Operator Included',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        ToggleButtons(
                          isSelected: [operatorIncluded == true, operatorIncluded == false],
                          onPressed: (i) => setState(() {
                            operatorIncluded = i == 0;
                            if (i == 0) _selectedDeliveryMode = DeliveryMode.deliveryOnly;
                          }),
                          borderRadius: BorderRadius.circular(20),
                          selectedBorderColor: lightColorScheme.primary,
                          selectedColor: Colors.white,
                          fillColor: lightColorScheme.primary,
                          color: lightColorScheme.primary,
                          constraints:
                              const BoxConstraints(minHeight: 40, minWidth: 80),
                          children: const [Text('Yes'), Text('No')],
                        ),
      
                        const SizedBox(height: 10),
                        const Padding(padding: EdgeInsets.all(5), child: Divider(thickness: 1)),
      
                        if (operatorIncluded == false) ...[
                          const SizedBox(height: 16),
                          const Text('How can renters get the equipment?',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            'Piliin kung pwedeng i-pickup ng renter, ipadala mo, o pareho.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _DeliveryModeCard(
                                icon: Icons.directions_walk_rounded,
                                label: 'Pick Up Only',
                                subtitle: 'Renter collects from your location',
                                isSelected: _selectedDeliveryMode == DeliveryMode.pickupOnly,
                                onTap: () => setState(() => _selectedDeliveryMode = DeliveryMode.pickupOnly),
                              ),
                              const SizedBox(width: 8),
                              _DeliveryModeCard(
                                icon: Icons.local_shipping_rounded,
                                label: 'Delivery Only',
                                subtitle: 'You deliver to the renter',
                                isSelected: _selectedDeliveryMode == DeliveryMode.deliveryOnly,
                                onTap: () => setState(() => _selectedDeliveryMode = DeliveryMode.deliveryOnly),
                              ),
                              const SizedBox(width: 8),
                              _DeliveryModeCard(
                                icon: Icons.swap_horiz_rounded,
                                label: 'Both',
                                subtitle: "Renter's choice",
                                isSelected: _selectedDeliveryMode == DeliveryMode.both,
                                onTap: () => setState(() => _selectedDeliveryMode = DeliveryMode.both),
                              ),
                            ],
                          ),
                        ],
      
                        const Text('Usage Requirements & Conditions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(
                          'Pumili ng anumang kundisyon o kinakailangan upang magamit ang kagamitang ito. '
                          'Maaaring humingi ng karagdagang detalye o patunay mula sa umuupa.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
      
                        const SizedBox(height: 16),
                        const Text('Land Size Requirement',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          'Mayroon bang minimum o maximum na sukat ng lupa na kailangan bago gamitin ang kagamitan? '
                          'Halimbawa: hindi angkop sa mga lupang mas maliit sa 1 ektarya.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ToggleButtons(
                          isSelected: [landSizeRequirement == true, landSizeRequirement == false],
                          onPressed: (i) => setState(() {
                            landSizeRequirement = i == 0;
                            showLandSizeError = false;
                          }),
                          borderRadius: BorderRadius.circular(20),
                          selectedBorderColor: lightColorScheme.primary,
                          selectedColor: Colors.white,
                          fillColor: lightColorScheme.primary,
                          color: lightColorScheme.primary,
                          constraints:
                              const BoxConstraints(minHeight: 40, minWidth: 80),
                          children: const [Text('Yes'), Text('No')],
                        ),
                        if (showLandSizeError)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade600),
                                SizedBox(width: 4),
                                Text(
                                  'Kailangan itong sagutin',
                                  style: TextStyle(color: Colors.red.shade600, fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          ),
                        if (landSizeRequirement == true) ...[
                          const SizedBox(height: 6),
                          const Text('Specify the land size range:',
                              style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextFormField(
                                  controller: _landSizeMinController,
                                  keyboardType: TextInputType.number,
                                  hint: 'Min (e.g. 1 ha)',
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CustomTextFormField(
                                  controller: _landSizeMaxController,
                                  keyboardType: TextInputType.number,
                                  hint: 'Max (e.g. 5 ha)',
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
      
                        const SizedBox(height: 16),
                        const Text('Maximum Grass Height?',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          'Mayroon bang limitasyon sa taas ng damo o pananim bago gamitin ang kagamitan? '
                          'Halimbawa: hindi pwedeng gamitin kung masyado nang mataas ang damo.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ToggleButtons(
                          isSelected: [
                            maxCropHeightRequirement == true,
                            maxCropHeightRequirement == false,
                          ],
                          onPressed: (i) => setState(() {
                            maxCropHeightRequirement = i == 0;
                            showCropHeightError = false;
                          }),
                          borderRadius: BorderRadius.circular(20),
                          selectedBorderColor: lightColorScheme.primary,
                          selectedColor: Colors.white,
                          fillColor: lightColorScheme.primary,
                          color: lightColorScheme.primary,
                          constraints:
                              const BoxConstraints(minHeight: 40, minWidth: 80),
                          children: const [Text('Yes'), Text('No')],
                        ),
                        if (showCropHeightError)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade600),
                                SizedBox(width: 4),
                                Text(
                                  'Kailangan itong sagutin',
                                  style: TextStyle(color: Colors.red.shade600, fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          ),
                        if (maxCropHeightRequirement == true) ...[
                          const SizedBox(height: 6),
                          Text('Ilagay ang pinapayagang taas ng damo o pananim:',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                          const SizedBox(height: 4),
                          CustomTextFormField(
                            hint: 'e.g. Hanggang 30 cm lamang',
                            maxLines: 1,
                            controller: _maxCropHeightController,
                            validator: (v) {
                              if (maxCropHeightRequirement == true &&
                                  (v == null || v.isEmpty)) return 'Required';
                              return null;
                            },
                          ),
                        ],
      
                        const SizedBox(height: 16),
                        const Text('Crop Condition Requirement',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          'Mayroon bang kinakailangang kondisyon ng pananim bago pwedeng gamitin ang kagamitan? '
                          'Halimbawa: kailangang tuyo na ang uhay, o kailangang naka-bundle na ang ani.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ToggleButtons(
                          isSelected: [
                            cropConditionRequirement == true,
                            cropConditionRequirement == false,
                          ],
                          onPressed: (i) => setState(() {
                            cropConditionRequirement = i == 0;
                            showCropConditionError = false;
                          }),
                          borderRadius: BorderRadius.circular(20),
                          selectedBorderColor: lightColorScheme.primary,
                          selectedColor: Colors.white,
                          fillColor: lightColorScheme.primary,
                          color: lightColorScheme.primary,
                          constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
                          children: const [Text('Yes'), Text('No')],
                        ),
                        if (showCropConditionError)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade600),
                                SizedBox(width: 4),
                                Text(
                                  'Kailangan itong sagutin',
                                  style: TextStyle(color: Colors.red.shade600, fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          ),
                        if (cropConditionRequirement == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ilarawan ang kinakailangang kondisyon ng pananim bago gamitin ang kagamitang ito. '
                            'Halimbawa: tuyo na ang uhay, hindi pa naani, o naka-bundle na.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 4),
                          CustomTextFormField(
                            hint: 'e.g. Dapat tuyo na ang pananim bago gamitin',
                            maxLines: 3,
                            controller: _cropConditionController,
                            validator: (v) {
                              if (cropConditionRequirement == true &&
                                  (v == null || v.isEmpty)) return 'Required';
                              return null;
                            },
                          ),
                        ],
      
                        // ── CROP SHARE (Harvester / Halimaw only) ─────────────────────────
                        if (_isHarvester) ...[
                          const SizedBox(height: 16),
                          const Text('Crop Share', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            'Hinihingi ba ng may-ari ng kagamitan ang bahagi ng ani bilang bayad?',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          ToggleButtons(
                            isSelected: [cropShareRequired == true, cropShareRequired == false],
                            onPressed: (i) => setState(() {
                              cropShareRequired = i == 0;
                              showCropShareError = false;
                              if (i == 1) _cropSharePercentController.clear();
                            }),
                            borderRadius: BorderRadius.circular(20),
                            selectedBorderColor: lightColorScheme.primary,
                            selectedColor: Colors.white,
                            fillColor: lightColorScheme.primary,
                            color: lightColorScheme.primary,
                            constraints: const BoxConstraints(minHeight: 40, minWidth: 80),
                            children: const [Text('Yes'), Text('No')],
                          ),
                          if (showCropShareError)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade600),
                                  SizedBox(width: 4),
                                  Text(
                                    'Kailangan itong sagutin',
                                    style: TextStyle(color: Colors.red.shade600, fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          if (cropShareRequired == true) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Crop Share Percentage (%)',
                                          style: TextStyle(fontSize: 12)),
                                      const SizedBox(height: 4),
                                      CustomTextFormField(
                                        controller: _cropSharePercentController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(decimal: true),
                                        hint: 'e.g. 10',
                                        validator: (v) {
                                          if (cropShareRequired != true) return null;
                                          if (v == null || v.isEmpty) return 'Required';
                                          final n = double.tryParse(v);
                                          if (n == null || n <= 0) return 'Enter a valid number';
                                          if (n > 15) return 'Maximum is 15%';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Icon(Icons.info_outline,
                                              size: 13, color: Colors.amber.shade800),
                                          const SizedBox(width: 4),
                                          Text('Max 15%',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.amber.shade800)),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ang crop share ay hindi dapat lumagpas sa 15% ng kabuuang ani.',
                                          style: TextStyle(
                                              fontSize: 10, color: Colors.amber.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
      
                        // ── MAINTENANCE INTERVAL ───────────────────────────
                        const SizedBox(height: 16),
                        const Text('Maintenance Interval',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          'Ilagay ang bilang ng oras ng operasyon bago kailangang mag-maintain ng kagamitan.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Interval (hours)', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  CustomTextFormField(
                                    controller: _maintenanceIntervalController,
                                    keyboardType: TextInputType.number,
                                    hint: 'Default: 240 hrs',
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      final n = double.tryParse(v);
                                      if (n == null || n <= 0) return 'Enter a valid number';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(Icons.build_circle_outlined,
                                          size: 13, color: Colors.blue.shade700),
                                      const SizedBox(width: 4),
                                      Text('Default: 240 hrs',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade700)),
                                    ]),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Karaniwang isinasagawa ang maintenance tuwing 240 oras ng operasyon.',
                                      style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
      
                        // ── RICE MILL MINIMUM VOLUME ───────────────────────
                        if (_isRiceMill) ...[
                          const SizedBox(height: 16),
                          const Text('Minimum Volume Requirement',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('Rice Mill requires a minimum load to cover startup costs.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Unit', style: TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  ToggleButtons(
                                    isSelected: [
                                      selectedMinVolumeUnit == 'cavans',
                                      selectedMinVolumeUnit == 'kg',
                                    ],
                                    onPressed: (i) {
                                      final newUnit = i == 0 ? 'cavans' : 'kg';
                                      final raw =
                                          double.tryParse(_minimumVolumeController.text);
                                      if (raw != null) {
                                        _minimumVolumeController.text = newUnit == 'cavans'
                                            ? (raw / 50).toStringAsFixed(1)
                                            : (raw * 50).toStringAsFixed(0);
                                      }
                                      setState(() => selectedMinVolumeUnit = newUnit);
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    selectedBorderColor: lightColorScheme.primary,
                                    selectedColor: Colors.white,
                                    fillColor: lightColorScheme.primary,
                                    color: lightColorScheme.primary,
                                    constraints:
                                        const BoxConstraints(minHeight: 40, minWidth: 70),
                                    children: const [Text('Cavans'), Text('kg')],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Minimum Volume ($selectedMinVolumeUnit)',
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CustomTextFormField(
                                      controller: _minimumVolumeController,
                                      keyboardType: TextInputType.number,
                                      hint: selectedMinVolumeUnit == 'cavans'
                                          ? 'e.g. 1 cavan'
                                          : 'e.g. 5 kg',
                                      validator: (v) {
                                        if (!_isRiceMill) return null;
                                        if (v == null || v.isEmpty) return 'Required';
                                        final n = double.tryParse(v);
                                        if (n == null || n <= 0) return 'Enter a valid number';
                                        if (selectedMinVolumeUnit == 'cavans' && n < 1) {
                                          return 'Minimum is 1 cavan (50 kg)';
                                        }
                                        if (selectedMinVolumeUnit == 'kg' && n < 50) {
                                          return 'Minimum is 50 kg (1 cavan)';
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_minimumVolumeController.text.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Builder(builder: (_) {
                                        final val = double.tryParse(
                                            _minimumVolumeController.text);
                                        if (val == null) return const SizedBox.shrink();
                                        final kg = selectedMinVolumeUnit == 'cavans'
                                            ? val * 50
                                            : val;
                                        final cavans = selectedMinVolumeUnit == 'kg'
                                            ? val / 50
                                            : val;
                                        return Text(
                                          '≈ ${cavans.toStringAsFixed(1)} cavans / ${kg.toStringAsFixed(0)} kg',
                                          style: TextStyle(
                                              fontSize: 11, color: Colors.grey[600]),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
      
                        const Padding(padding: EdgeInsets.all(5), child: Divider(thickness: 1)),
                        const SizedBox(height: 16),
      
                        // ── AVAILABILITY ───────────────────────────────────
                        const Text('Availability',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(isStart: true),
                                child: Text(
                                  availableFrom == null
                                      ? 'Available From'
                                      : 'From: ${availableFrom!.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(color: lightColorScheme.primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: availableFrom == null
                                    ? null
                                    : () => _pickDate(isStart: false),
                                child: Text(
                                  availableUntil == null
                                      ? 'Available Until'
                                      : 'Until: ${availableUntil!.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(color: lightColorScheme.primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (showAvailabilityError)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Please select availability dates',
                                style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
      
                        const SizedBox(height: 16),
                        const Padding(padding: EdgeInsets.all(5), child: Divider(thickness: 1)),
      
                        // ── RENTAL PRICING ─────────────────────────────────
                        const Text('Rental Pricing',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
      
                        if (_isRiceMill) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 14, color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text('Rice Mill uses per-kg tiered pricing',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.green.shade700)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Text('Rice Only Price (₱/kg)',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                CustomTextFormField(
                                  controller: _riceOnlyPriceController,
                                  hint: 'Default: ₱2.00/kg',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Required';
                                    final n = double.tryParse(v);
                                    if (n == null) return 'Invalid number';
                                    if (n < 2.0) return 'Minimum is ₱2.00/kg';
                                    if (n > 4.0) return 'Maximum is ₱4.00/kg';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text('Min ₱2.00 — Max ₱4.00 per kg',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                const SizedBox(height: 12),
                                const Text('Rice + Darak Price (₱/kg)',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                CustomTextFormField(
                                  controller: _ricePlusDarakPriceController,
                                  hint: 'Default: ₱3.00/kg',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Required';
                                    final n = double.tryParse(v);
                                    if (n == null) return 'Invalid number';
                                    if (n < 3.0) return 'Minimum is ₱3.00/kg';
                                    if (n > 6.0) return 'Maximum is ₱6.00/kg';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text('Min ₱3.00 — Max ₱6.00 per kg',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Rate Type', style: TextStyle(fontSize: 12)),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: selectedRentalUnit,
                                      isExpanded: true,
                                      dropdownColor: lightColorScheme.onPrimary,
                                      decoration: InputDecoration(
                                        hintText: 'Select Rental Rate',
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: lightColorScheme.primary.withOpacity(0.3)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide:
                                              BorderSide(color: lightColorScheme.primary, width: 2),
                                        ),
                                        prefixIcon: selectedRentalUnit != null
                                            ? IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () =>
                                                    setState(() => selectedRentalUnit = null),
                                              )
                                            : null,
                                      ),
                                      items: rentalUnit
                                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                          .toList(),
                                      onChanged: (v) => setState(() => selectedRentalUnit = v),
                                      validator: (v) => v == null ? 'Required' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Price', style: TextStyle(fontSize: 12)),
                                    const SizedBox(height: 6),
                                    CustomTextFormField(
                                      controller: _equipmentPriceController,
                                      hint: '₱',
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        if (v == null || v.isEmpty || v == '0') return 'Required';
                                        final n = double.tryParse(v);
                                        if (n == null) return 'Invalid';
                                        if (priceLimits != null) {
                                          if (n < priceLimits.$1) {
                                            return 'Min ₱${priceLimits.$1.toStringAsFixed(0)}';
                                          }
                                          if (n > priceLimits.$2) {
                                            return 'Max ₱${priceLimits.$2.toStringAsFixed(0)}';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // ── Price range banner (full width, sits cleanly below the row) ──
                          if (priceLimits != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: lightColorScheme.primary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: lightColorScheme.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: lightColorScheme.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Allowed price range: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: lightColorScheme.primary.withOpacity(0.8),
                                    ),
                                  ),
                                  Text(
                                    '₱${priceLimits.$1.toStringAsFixed(0)} – ₱${priceLimits.$2.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: lightColorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
      
                  const SizedBox(height: 15),
      
      Row(
        children: [
      Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: _onSavePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: lightColorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Save',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 1,
        child: OutlinedButton(
          onPressed: () => _confirmCancel(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text('Cancel',
              style: TextStyle(color: lightColorScheme.primary, fontSize: 16)),
        ),
      ),
        ],
      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? getConditionHelpText(String? condition) {
    switch (condition) {
      case 'Brand New':    return 'Never used equipment with zero operating hours.';
      case 'Excellent':   return 'Lightly used, fully functional, with minimal wear.';
      case 'Good':        return 'Regularly used, fully operational, with normal wear and tear.';
      case 'Fair':        return 'Functional but shows noticeable wear and may require monitoring.';
      case 'Needs Maintenance': return 'Operational but requires servicing or repair soon.';
      default:            return null;
    }
  }

  Future<void> pickImage(int tappedIndex) async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          int firstEmpty = images.indexWhere((img) => img == null);
          if (firstEmpty != -1) {
            images[firstEmpty] = picked;
          } else {
            images[tappedIndex] = picked;
          }
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = isStart ? now : (availableFrom ?? now);
    final DateTime first   = isStart ? now : (availableFrom ?? now);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          availableFrom = picked;
          if (availableUntil != null && availableUntil!.isBefore(picked)) {
            availableUntil = null;
          }
        } else {
          availableUntil = picked;
        }
      });
    }
  }

  Future<void> _onSavePressed() async {
    final isFormValid = _formKey.currentState!.validate();
    final hasImage    = images.any((img) => img != null);

    setState(() {
      showLandSizeError      = landSizeRequirement == null;
      showCropHeightError    = maxCropHeightRequirement == null;
      showCropConditionError = cropConditionRequirement == null;
      showImageError         = !hasImage;
      showAvailabilityError  = availableFrom == null || availableUntil == null;
      showAddressError       = !_addressIsValid;
      showCropShareError     = _isHarvester && cropShareRequired == null;
    });

    final List<String> missing = [];

    if (!hasImage)                                           missing.add('At least one photo');
    if (selectedCategory == null)                            missing.add('Equipment Category');
    if (_equipmentNameController.text.trim().isEmpty)        missing.add('Listing Name');
    if (_equipmentDescriptionController.text.trim().isEmpty) missing.add('Description');
    if (!_addressIsValid)                                    missing.add('Equipment Location');
    if (selectedCondition == null)                           missing.add('Condition');
    if (operatorIncluded == null)                            missing.add('Operator Included (Yes/No)');
    if (landSizeRequirement == null)                         missing.add('Land Size Requirement (Yes/No)');
    if (maxCropHeightRequirement == null)                    missing.add('Maximum Grass Height (Yes/No)');
    if (cropConditionRequirement == null)                    missing.add('Crop Condition Requirement (Yes/No)');
    if (_isHarvester && cropShareRequired == null)           missing.add('Crop Share (Yes/No)');
    if (availableFrom == null || availableUntil == null)     missing.add('Availability Dates');
    if (!_isRiceMill && selectedRentalUnit == null)          missing.add('Rate Type');
    if (!_isRiceMill && (_equipmentPriceController.text.trim().isEmpty ||
        _equipmentPriceController.text.trim() == '0'))       missing.add('Price');

    if (!isFormValid || missing.isNotEmpty) {
      _showMissingFieldsSheet(missing);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService      = AuthService();
      final firestoreService = FirestoreService();
      final currentUser      = authService.currentUser;

      if (currentUser == null) throw Exception('You must be logged in to create a listing');

      final userData  = await authService.getUserData(currentUser.uid);
      final ownerName = userData?['firstName'] != null && userData?['lastName'] != null
          ? '${userData!['firstName']} ${userData['lastName']}'
          : currentUser.email?.split('@')[0] ?? 'Unknown';

      final List<String> requirementsList = [];
      if (landSizeRequirement == true) {
        requirementsList.add(
          _landSizeMinController.text.isNotEmpty && _landSizeMaxController.text.isNotEmpty
              ? '${_landSizeMinController.text} – ${_landSizeMaxController.text}'
              : 'Land size requirement',
        );
      }
      if (maxCropHeightRequirement == true) {
        requirementsList.add(
          _maxCropHeightController.text.isNotEmpty
              ? _maxCropHeightController.text
              : 'Max grass height required',
        );
      }
      if (requirementsList.isEmpty) requirementsList.add('No specific requirements');

      final cloudinaryService = CloudinaryService();

      final List<XFile> newImages = images
          .where((img) => img != null && !img!.path.startsWith('http'))
          .map((img) => img!)
          .toList();
      final List<String> existingUrls = images
          .where((img) => img != null && img!.path.startsWith('http'))
          .map((img) => img!.path)
          .toList();

      List<String> uploadedUrls = [];
      if (newImages.isNotEmpty) {
        uploadedUrls = await cloudinaryService.uploadMultipleImages(
          newImages,
          onProgress: (current, total) =>
              debugPrint('Uploading image $current of $total'),
        );
      }
      final List<String> imageUrls = [...existingUrls, ...uploadedUrls];

      final rentRequestService = RentRequestService();
      final now = DateTime.now();
      final withinWindow =
          availableUntil != null && now.isBefore(availableUntil!);
      EquipmentStatus computedStatus =
          withinWindow ? EquipmentStatus.available : EquipmentStatus.unavailable;

      if (widget.existingEquipment != null &&
          widget.existingEquipment!.id != null) {
        if (widget.existingEquipment!.status == EquipmentStatus.underMaintenance) {
          computedStatus = EquipmentStatus.underMaintenance;
        }
        final hasApproved = await rentRequestService
            .hasActiveApprovedRequest(widget.existingEquipment!.id!);
        if (hasApproved) computedStatus = EquipmentStatus.unavailable;
      }

      final equipment = Equipment(
        name:        _equipmentNameController.text.trim(),
        description: _equipmentDescriptionController.text.trim(),
        category:    selectedCategory,
        brand:       selectedBrand,
        yearModel:   selectedYear,
        power: _powerController.text.trim().isEmpty
            ? 'N/A'
            : '${_powerController.text.trim()} HP',
        condition:   selectedCondition ?? 'Good',
        attachments: _attachmentsController.text.trim().isEmpty
            ? null
            : _attachmentsController.text.trim(),
        operatorIncluded:         operatorIncluded ?? false,
        availableFrom:            availableFrom,
        availableUntil:           availableUntil,
        requirements:             requirementsList,
        reviews:                  [],
        ownerId:                  currentUser.uid,
        ownerName:                ownerName,
        imageUrls:                imageUrls,
        fuelType:                 selectedFuel,
        defects:                  selectedCondition == 'Needs Maintenance'
            ? _defectsController.text.trim()
            : null,
        status:                   computedStatus,
        landSizeRequirement:      landSizeRequirement ?? false,
        maxCropHeightRequirement: maxCropHeightRequirement ?? false,
        landSizeMin:              _landSizeMinController.text,
        landSizeMax:              _landSizeMaxController.text,
        maxCropHeight:            _maxCropHeightController.text.trim().isEmpty
            ? null
            : _maxCropHeightController.text.trim(),
        rentRate:                 '',
        minimumVolumeRequired:    _isRiceMill,
        minimumVolumeKg:          _isRiceMill
            ? (selectedMinVolumeUnit == 'cavans'
                ? (double.tryParse(_minimumVolumeController.text) ?? 0) * 50
                : double.tryParse(_minimumVolumeController.text))
            : null,
        minimumVolumeUnit:        selectedMinVolumeUnit,
        batchingAllowed:          false,
        price: _isRiceMill
            ? (double.tryParse(_riceOnlyPriceController.text) ?? 2.0)
            : double.parse(_equipmentPriceController.text.trim()),
        rentalUnit: _isRiceMill ? 'Per kg' : (selectedRentalUnit ?? 'Per Day'),
        riceOnlyPricePerKg:      _isRiceMill
            ? double.tryParse(_riceOnlyPriceController.text)
            : null,
        ricePlusDarakPricePerKg: _isRiceMill
            ? double.tryParse(_ricePlusDarakPriceController.text)
            : null,
        location:  _resolvedLocation,
        latitude:  _resolvedLat,
        longitude: _resolvedLng,
        deliveryMode: operatorIncluded == true
            ? DeliveryMode.deliveryOnly
            : _selectedDeliveryMode,
        cropShareRequired:    _isHarvester && (cropShareRequired ?? false),
        cropSharePercent:     (_isHarvester && cropShareRequired == true)
            ? double.tryParse(_cropSharePercentController.text)
            : null,
        maintenanceRequired:      true,
        maintenanceIntervalHrs:   double.tryParse(_maintenanceIntervalController.text) ?? 240,
        cropConditionRequirement: cropConditionRequirement ?? false,
        cropCondition: (cropConditionRequirement == true)   // ← ADD THIS
            ? _cropConditionController.text.trim()
            : null,
      );

      if (widget.existingEquipment != null) {
        await firestoreService.updateEquipment(
            widget.existingEquipment!.id!, equipment.toMap());
      } else {
        await firestoreService.addEquipment(equipment.toMap());
      }

      if (mounted) Navigator.pop(context);
      if (mounted) {
        showConfirmSnackbar(
          context: context,
          title: 'Success!',
          message: widget.existingEquipment != null
              ? 'Equipment updated successfully!'
              : 'Equipment listed successfully!',
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, equipment);
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        showErrorSnackbar(context: context, title: 'Error', message: e.toString());
      }
    }
  }

  Future<void> _saveDraft() async {
    // ── Upload any new local images to Cloudinary first ──
  final cloudinaryService = CloudinaryService();

  final List<XFile> newImages = images
      .where((img) => img != null && !img!.path.startsWith('http'))
      .map((img) => img!)
      .toList();
  final List<String> existingUrls = images
      .where((img) => img != null && img!.path.startsWith('http'))
      .map((img) => img!.path)
      .toList();

  List<String> uploadedUrls = [];
  if (newImages.isNotEmpty) {
    uploadedUrls = await cloudinaryService.uploadMultipleImages(
      newImages,
      onProgress: (current, total) =>
          debugPrint('Uploading draft image $current of $total'),
    );
    // Replace local XFiles with the uploaded http URLs in the images list
    int uploadIndex = 0;
    for (int i = 0; i < images.length; i++) {
      if (images[i] != null && !images[i]!.path.startsWith('http')) {
        images[i] = XFile(uploadedUrls[uploadIndex++]);
      }
    }
  }

  final List<String> imageUrls = [...existingUrls, ...uploadedUrls];
  final draftData = {
    'name':                    _equipmentNameController.text.trim(),
    'description':             _equipmentDescriptionController.text.trim(),
    'category':                selectedCategory,
    'brand':                   selectedBrand,
    'yearModel':               selectedYear,
    'power':                   _powerController.text.trim(),
    'fuelType':                selectedFuel,
    'condition':               selectedCondition,
    'attachments':             _attachmentsController.text.trim(),
    'defects':                 _defectsController.text.trim(),
    'price':                   double.tryParse(_equipmentPriceController.text),
    'rentalUnit':              selectedRentalUnit,
    'landSizeMin':             _landSizeMinController.text.trim(),
    'landSizeMax':             _landSizeMaxController.text.trim(),
    'maxCropHeight':           _maxCropHeightController.text.trim(),
    'landSizeRequirement':     landSizeRequirement,
    'maxCropHeightRequirement':maxCropHeightRequirement,
    'cropConditionRequirement':cropConditionRequirement,
    'operatorIncluded':        operatorIncluded,
    'cropShareRequired':       cropShareRequired,
    'cropSharePercent':        double.tryParse(_cropSharePercentController.text),
    'riceOnlyPrice':           double.tryParse(_riceOnlyPriceController.text),
    'ricePlusDarakPrice':      double.tryParse(_ricePlusDarakPriceController.text),
    'maintenanceInterval':     double.tryParse(_maintenanceIntervalController.text),
     'cropCondition':           _cropConditionController.text.trim(), // ← missing
  'availableFrom':           availableFrom?.toIso8601String(),     // ← missing
  'availableUntil':          availableUntil?.toIso8601String(),    // ← missing
  'imageUrls':               imageUrls,
  };

  try {
    if (_currentDraftId != null) {
      await _draftService.updateDraft(_currentDraftId!, draftData);
    } else {
      _currentDraftId = await _draftService.saveDraft(draftData);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved!')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save draft: $e')),
      );
    }
  }
}

Future<void> _confirmCancel(BuildContext context) async {
   // If nothing meaningful has been filled, just leave without asking
  final bool isEmpty = _equipmentNameController.text.trim().isEmpty &&
      _equipmentDescriptionController.text.trim().isEmpty &&
      selectedCategory == null &&
      images.every((img) => img == null);

  
  if (isEmpty) {
    if (mounted) Navigator.pop(context);
    return;
  }

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Isara ang Form'),
      content: const Text('Gusto mo bang i-save ang iyong draft bago umalis?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'discard'),
          child: Text('Discard', style: TextStyle(color: Colors.red.shade400)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'save'),
          child: const Text('Save Draft'),
        ),
      ],
    ),
  );

  if (result == 'save') {
    await _saveDraft();
    if (mounted) Navigator.pop(context);
  } else if (result == 'discard') {
    if (mounted) Navigator.pop(context);
  }
  // null = tapped outside dialog = do nothing
}
}

// ── Address option card widget ────────────────────────────────────────────────

class _AddressOptionCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     isSelected;
  final bool     isDisabled;
  final VoidCallback onTap;

  const _AddressOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = lightColorScheme.primary;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withOpacity(0.08)
              : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? primary : Colors.black12,
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDisabled
                  ? Colors.grey.shade400
                  : isSelected
                      ? primary
                      : Colors.black45,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isDisabled
                          ? Colors.grey.shade400
                          : isSelected
                              ? primary
                              : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDisabled
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeliveryModeCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = lightColorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primary.withOpacity(0.08) : Colors.grey.shade50,
            border: Border.all(
              color: isSelected ? primary : Colors.black12,
              width: isSelected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? primary : Colors.black45),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primary : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}