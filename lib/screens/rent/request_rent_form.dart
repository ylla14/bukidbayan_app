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
  double? _farmLat;
  double? _farmLng;

  XFile? landSizeProof;
  XFile? cropHeightProof;

  final RentRequestService _requestService = RentRequestService();
  final ImagePicker _picker = ImagePicker();

  bool get hasLandSizeRequirement =>
      widget.item.landSizeRequirement &&
      (widget.item.landSizeMin != null || widget.item.landSizeMax != null);

  bool get hasCropHeightRequirement =>
      widget.item.maxCropHeightRequirement && widget.item.maxCropHeight != null;

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
    // volume input is in cavans, convert to kg
    final kg = widget.item.minimumVolumeUnit == 'cavans' ? vol * 50 : vol;
    return kg * price;
  }

  String? _addressLat;
  String? _addressLng;
  String? _profileAddress;
  double? _profileLat;
  double? _profileLng;

  // Add to _RequestRentFormState fields:
  DeliveryMethod _deliveryMethod = DeliveryMethod.pickup;

  @override
  void initState() {
    super.initState();

    nameController.addListener(_onFieldChanged);
    addressController.addListener(_onFieldChanged);
    _loadProfileAddress();
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
          // Seed addressController with profile address as default
          if (_profileAddress != null && addressController.text.isEmpty) {
            addressController.text = _profileAddress!;
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile address: $e');
    }
  }

  void _onFieldChanged() {
    setState(() {}); // rebuild to update isStep2Complete
  }

  @override
  void dispose() {
    nameController.removeListener(_onFieldChanged);
    addressController.removeListener(_onFieldChanged);
    nameController.dispose();
    addressController.dispose();
    farmAddressController.dispose();
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

            /// Components
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
              onReturnDatePicked: (date) {
                setState(() => returnDate = date);
              },
            ),

            if (isScheduleComplete) ...[
              UserInfoStep(
                nameController: nameController,
                // addressController: addressController,
              ),

              DeliveryMethodStep(
                selected: _deliveryMethod,
                equipmentLocation: widget.item.location,
                onChanged: (method) => setState(() {
                  _deliveryMethod = method;
                  // Clear address when switching back to pickup
                  if (method == DeliveryMethod.pickup) {
                    addressController.clear();
                  }
                }),
              ),

              AddressStep(
                profileAddress: _profileAddress,
                profileLat: _profileLat,
                profileLng: _profileLng,
                addressController: addressController,
                farmAddressController: farmAddressController,
                onFarmLocationPicked: (lat, lng) {
                  setState(() {
                    _farmLat = lat;
                    _farmLng = lng;
                  });
                },
                onLatChanged: (v) =>
                    setState(() => _addressLat = v?.toString()),
                onLngChanged: (v) =>
                    setState(() => _addressLng = v?.toString()),
              ),
            ],

            if (isScheduleComplete && hasAnyRequirement) ...[
              RequirementStep(
                item: widget.item,
                landSizeProof: landSizeProof,
                cropHeightProof: cropHeightProof,
                onLandPick: (file) => setState(() => landSizeProof = file),
                onLandRemove: () => setState(() => landSizeProof = null),
                onCropPick: (file) => setState(() => cropHeightProof = file),
                onCropRemove: () => setState(() => cropHeightProof = null),
                picker: _picker,
                volumeController: _volumeController,
                volumeError: _volumeError,
                keepDarak: _keepDarak,
                onToggleDarak: () => setState(() => _keepDarak = !_keepDarak),
                estimatedTotal: _estimatedTotal,
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
                landSizeProof: landSizeProof,
                cropHeightProof: cropHeightProof,
                item: widget.item,
                requestService: _requestService,
                volumeController: _volumeController,
                keepDarak: _keepDarak,
                estimatedMillingFee: _estimatedTotal,
                deliveryMethod: _deliveryMethod,
              ),
          ],
        ),
      ),
    );
  }
}
