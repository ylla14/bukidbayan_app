import 'package:bukidbayan_app/components/rent/rent_form/address_step.dart';
import 'package:bukidbayan_app/components/rent/rent_form/date_step.dart';
import 'package:bukidbayan_app/components/rent/rent_form/delivery_method_step.dart';
import 'package:bukidbayan_app/components/rent/rent_form/requirement_step.dart';
import 'package:bukidbayan_app/components/rent/rent_form/submit_button.dart';
import 'package:bukidbayan_app/components/rent/rent_form/user_info.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:flutter/material.dart';

import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/components/rent/rent_item_expandable.dart';
import 'package:image_picker/image_picker.dart';

class RequestRentForm extends StatefulWidget {
  final Equipment item;
  const RequestRentForm({super.key, required this.item});

  @override
  State<RequestRentForm> createState() => _RequestRentFormState();
}

class _RequestRentFormState extends State<RequestRentForm> {
  DateTime? startDate;
  DateTime? returnDate;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController farmAddressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController cropTypeController = TextEditingController();
  final TextEditingController farmingPhaseController = TextEditingController();
  final TextEditingController intendedUseController = TextEditingController();

  double? _farmLat;
  double? _farmLng;

  String? _profileFarmAddress;
  double? _profileFarmLat;
  double? _profileFarmLng;

  // ── Changed from single XFile? to List<XFile> ──────────────
  List<XFile> _landSizeProofs = [];
  List<XFile> _cropHeightProofs = [];
  final List<XFile> _cropConditionProofs = [];

  final RentRequestService _requestService = RentRequestService();
  final ImagePicker _picker = ImagePicker();

  bool get hasLandSizeRequirement => widget.item.landSizeRequirement == true;

  bool get hasCropHeightRequirement =>
      widget.item.maxCropHeightRequirement == true;

  bool get isRiceMill =>
      widget.item.category?.toLowerCase().contains('rice mill') == true;

  bool get hasAnyRequirement =>
      hasLandSizeRequirement || hasCropHeightRequirement || isRiceMill;

  bool get isScheduleComplete => startDate != null && returnDate != null;
  bool get isStep2Complete =>
      nameController.text.isNotEmpty &&
      (_deliveryMethod == DeliveryMethod.pickup ||
          addressController.text.isNotEmpty);

  final _volumeController = TextEditingController();
  String? _volumeError;

  bool _keepDarak = false;

  double? get _estimatedTotal {
    final vol = double.tryParse(_volumeController.text);
    if (vol == null) return null;
    final price = _keepDarak
        ? (widget.item.ricePlusDarakPricePerKg ?? 3.0)
        : (widget.item.riceOnlyPricePerKg ?? 2.0);
    final kg = widget.item.minimumVolumeUnit == 'cavans' ? vol * 50 : vol;
    return kg * price;
  }

  String? _addressLat;
  String? _addressLng;
  String? _profileAddress;
  double? _profileLat;
  double? _profileLng;
  double? _hectaresEntered;

  bool get _onlyHasLandReq =>
      hasLandSizeRequirement &&
      !hasCropHeightRequirement &&
      !widget.item.cropConditionRequirement &&
      !isRiceMill;

  bool get _isAutoComputedCategory => () {
    final cat = widget.item.category?.toLowerCase();
    return cat == 'tractor' ||
        cat == 'harvester (halimaw)' ||
        cat == 'hand tractor (kuliglig)' ||
        cat == 'floating tiller (pagong)';
  }();

  DeliveryMethod _deliveryMethod = DeliveryMethod.pickup;

  @override
  void initState() {
    super.initState();
    nameController.addListener(_onFieldChanged);
    addressController.addListener(_onFieldChanged);
    phoneController.addListener(_onFieldChanged);

    _loadProfileAddress();

    // Auto-select the only available method if restricted
    if (widget.item.deliveryMode == DeliveryMode.deliveryOnly) {
      _deliveryMethod = DeliveryMethod.delivery;
    } else if (widget.item.deliveryMode == DeliveryMode.pickupOnly) {
      _deliveryMethod = DeliveryMethod.pickup;
    }
  }

  Future<void> _loadProfileAddress() async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) return;
      final data = await authService.getUserData(user.uid);
      if (data != null && mounted) {
        setState(() {
          _profileAddress = data['address'] as String?;
          _profileLat = (data['latitude'] as num?)?.toDouble();
          _profileLng = (data['longitude'] as num?)?.toDouble();

          // add these:
          _profileFarmAddress = data['farmAddress'] as String?;
          _profileFarmLat = (data['farmLatitude'] as num?)?.toDouble();
          _profileFarmLng = (data['farmLongitude'] as num?)?.toDouble();

          if (_profileAddress != null && addressController.text.isEmpty) {
            addressController.text = _profileAddress!;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile address: $e');
    }
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    nameController.removeListener(_onFieldChanged);
    addressController.removeListener(_onFieldChanged);
    phoneController.removeListener(_onFieldChanged);
    phoneController.dispose();
    nameController.dispose();
    addressController.dispose();
    farmAddressController.dispose();
    _volumeController.dispose();
    cropTypeController.dispose();
    farmingPhaseController.dispose();
    intendedUseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Request Form',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: lightColorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            RentItemExpandable(item: widget.item),
            const SizedBox(height: 16),

            DateStep(
              item: widget.item,
              startDate: startDate,
              returnDate: returnDate,
              onStartDatePicked: (date) {
                setState(() {
                  startDate = date;
                  returnDate = null;
                });
              },
              onReturnDatePicked: (date) => setState(() => returnDate = date),
              onHectaresChanged: (ha) =>
                  setState(() => _hectaresEntered = ha), // ADD
            ),

            if (isScheduleComplete) ...[
              UserInfoStep(
                nameController: nameController,
                phoneController: phoneController, // ← add this
                farmAddressController: farmAddressController,
                onFarmLocationPicked: (lat, lng) {
                  setState(() {
                    _farmLat = lat;
                    _farmLng = lng;
                  });
                },
              ),

              DeliveryMethodStep(
                selected: _deliveryMethod,
                equipmentLocation: widget.item.location,
                deliveryMode: widget.item.deliveryMode, // ← add this
                onChanged: (method) => setState(() {
                  _deliveryMethod = method;
                  if (method == DeliveryMethod.pickup) {
                    addressController.clear();
                  }
                }),
              ),

              AddressStep(
                profileAddress: _profileAddress,
                profileLat: _profileLat,
                profileLng: _profileLng,
                profileFarmAddress: _profileFarmAddress,
                profileFarmLat: _profileFarmLat,
                profileFarmLng: _profileFarmLng,
                addressController: addressController,
                onLatChanged: (v) =>
                    setState(() => _addressLat = v?.toString()),
                onLngChanged: (v) =>
                    setState(() => _addressLng = v?.toString()),
              ),
            ],

            if (isScheduleComplete &&
                hasAnyRequirement &&
                !(_isAutoComputedCategory && _onlyHasLandReq)) ...[
              RequirementStep(
                item: widget.item,
                landSizeProofs: _landSizeProofs,
                cropHeightProofs: _cropHeightProofs,
                cropConditionProofs: _cropConditionProofs, // NEW
                onLandAdd: (file) => setState(() => _landSizeProofs.add(file)),
                onLandRemove: (index) =>
                    setState(() => _landSizeProofs.removeAt(index)),
                onCropAdd: (file) =>
                    setState(() => _cropHeightProofs.add(file)),
                onCropRemove: (index) =>
                    setState(() => _cropHeightProofs.removeAt(index)),
                onCropConditionAdd:
                    (file) => // NEW
                        setState(() => _cropConditionProofs.add(file)),
                onCropConditionRemove:
                    (index) => // NEW
                        setState(() => _cropConditionProofs.removeAt(index)),
                picker: _picker,
                volumeController: _volumeController,
                volumeError: _volumeError,
                keepDarak: _keepDarak,
                onToggleDarak: () => setState(() => _keepDarak = !_keepDarak),
                estimatedTotal: _estimatedTotal,
              ),
            ],

            if (isScheduleComplete) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: lightColorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forecast Inputs',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: lightColorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optional fields for future demand forecasting and barangay planning analytics.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cropTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Crop Type',
                        hintText: 'Rice, corn, vegetables, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: farmingPhaseController,
                      decoration: const InputDecoration(
                        labelText: 'Farming Phase',
                        hintText: 'Land preparation, planting, harvest, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: intendedUseController,
                      decoration: const InputDecoration(
                        labelText: 'Intended Use',
                        hintText: 'Plowing, hauling, milling, spraying, etc.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            if (isScheduleComplete)
              SubmitButton(
                isStep2Complete: isStep2Complete,
                startDate: startDate!,
                returnDate: returnDate!,
                name: nameController.text,
                address: addressController.text,
                farmAddress: farmAddressController.text.trim().isEmpty
                    ? null
                    : farmAddressController.text.trim(),
                farmLatitude: _farmLat,
                farmLongitude: _farmLng,
                landSizeProofs: _landSizeProofs,
                cropHeightProofs: _cropHeightProofs,
                cropConditionProofs: _cropConditionProofs,
                item: widget.item,
                requestService: _requestService,
                volumeController: _volumeController,
                keepDarak: _keepDarak,
                estimatedMillingFee: _estimatedTotal,
                deliveryMethod: _deliveryMethod,
                hectaresEntered: _hectaresEntered, // ADD
                phoneNumber: phoneController.text,
                cropType: cropTypeController.text.trim().isEmpty
                    ? null
                    : cropTypeController.text.trim(),
                farmingPhase: farmingPhaseController.text.trim().isEmpty
                    ? null
                    : farmingPhaseController.text.trim(),
                intendedUse: intendedUseController.text.trim().isEmpty
                    ? null
                    : intendedUseController.text.trim(),
              ),
          ],
        ),
      ),
    );
  }
}
