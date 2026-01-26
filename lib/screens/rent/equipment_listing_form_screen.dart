import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_dropdown_form_field.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'package:bukidbayan_app/mock_data/rent_items.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/cloudinary_service.dart';

// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/services/rent_service.dart';


const List<String> rentalUnit = <String>['Per Hour', 'Per Day', 'Per Week', 'Per Month'];
const List<String> condition = <String>['Brand New', 'Excellent', 'Good', 'Fair', 'Needs Maintenance'];

// Options for dropdowns
final List<String> brandOptions = ['Mitsubishi', 'Kubota', 'John Deere', 'Honda', 'Stihl'];
final List<String> yearOptions = List.generate(20, (i) => (DateTime.now().year - i).toString());
final List<String> powerOptions = ['10 HP', '20 HP', '34 HP', '50 HP', '75 HP'];
final List<String> fuelOptions = ['Diesel', 'Gasoline', 'Electric', 'Hybrid'];



class EquipmentListingScreen extends StatefulWidget {
  const EquipmentListingScreen({super.key});

  @override
  State<EquipmentListingScreen> createState() => _EquipmentListingScreenState();
}

class _EquipmentListingScreenState extends State<EquipmentListingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _equipmentNameController = TextEditingController();
  final _equipmentDescriptionController = TextEditingController();
  final _equipmentPriceController = TextEditingController();
  final _equipmentBrandController = TextEditingController();
  final _landSizeController = TextEditingController();
  final _yearController = TextEditingController();
  final _powerController = TextEditingController();
  final _fuelController = TextEditingController();
  final _attachmentsController = TextEditingController();
  final _defectsController = TextEditingController();
  final _landSizeMinController = TextEditingController();
  final _landSizeMaxController = TextEditingController();
  final _maxCropHeightController = TextEditingController();

  String? selectedBrand;
  String? selectedYear;
  String? selectedPower;
  String? selectedFuel;

  bool? operatorIncluded;
  bool? landSizeRequirement;
  bool? maxCropHeightRequirement;

  bool showLandSizeError = false;
  bool showCropHeightError = false;
  bool showImageError = false;

  DateTime? availableFrom;
  DateTime? availableUntil;
  bool showAvailabilityError = false;

  List<RentItem> itemCategories = items;
  final List<String> uniqueCategories = items
    .map((item) => item.category)
    .toSet()
    .toList();

//   List<String> uniqueCategories = [];

// @override
// void initState() {
//   super.initState();
//   _loadCategories();
// }

// Future<void> _loadCategories() async {
//   await _rentService.seedRentItems();
//   final allItems = await _rentService.getAllItems();
//   setState(() {
//     uniqueCategories = allItems
//         .map((item) => item.category)
//         .toSet()
//         .toList();
//   });
// }

  String? selectedCategory;
  String? selectedRentalUnit;
  String? selectedCondition;
  

  final ImagePicker _picker = ImagePicker();
  // Max 10 images (null = empty slot)
  final List<XFile?> images = List.generate(10, (_) => null);
  bool _isPickingImage = false;

  // final RentService _rentService = RentService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
              stops: [0.0, 0.9],
            ),
          ),
        ),
        centerTitle: true,
      ),

      body: Form(
        key: _formKey, 
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Equipment Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: lightColorScheme.primary),
                  ),
                ),
        
                //IMAGE PICKER
                const SizedBox(height: 10,),
                SizedBox(
                  height: 100, // height of the row
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final image = images[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8, left: 8),
                        child: GestureDetector(
                          onTap: () => pickImage(index),
                          child: Container(
                            width: 90, // 👈 FIXED SIZE
                            height: 90, // 👈 FIXED SIZE
                            decoration: BoxDecoration(
                              border: Border.all(color: lightColorScheme.primary),
                              borderRadius: BorderRadius.circular(8),
                              color: lightColorScheme.primary.withOpacity(0.2),
                            ),
                            child: image == null
                                ? const Center(
                                    child: Icon(
                                      Icons.add,
                                      size: 32,
                                      color: Colors.white,
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? Image.network(
                                            image.path,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.file(
                                            File(image.path),
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (showImageError)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Please upload at least one image',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

                const SizedBox(height: 15),
               
                //CATEGORY
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// CATEGORY
                      const Text(
                        'Equipment Category',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        dropdownColor: lightColorScheme.onPrimary,
                        decoration: InputDecoration(
                          hintText: 'Select Category',
                          hintStyle: TextStyle(color: Colors.black12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: lightColorScheme.primary.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: lightColorScheme.primary, width: 2),
                          ),
                          prefixIcon: selectedCategory != null
                            ?IconButton(
                              icon: Icon(Icons.close),
                              onPressed: (){
                                setState(() {
                                  selectedCategory = null;
                                });
                              },
                            )
                            :null
                        ), 
                        items: uniqueCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                            
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Please select a category' : null,
                      ),
        
                      const SizedBox(height: 16),
        
                      /// LISTING NAME
                      const Text(
                        'Listing Name',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      CustomTextFormField(
                        controller: _equipmentNameController,
                        hint: 'Equipment Name (e.g. Tractor)',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter equipment name';
                          }
                          return null;
                        },
                      ),
        
                      const SizedBox(height: 16),
        
                      /// DESCRIPTION
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      CustomTextFormField(
                        controller: _equipmentDescriptionController,
                        hint: 'Brief description of the equipment',
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
        
                      const Padding(
                        padding: EdgeInsets.all(5),
                        child: Divider(
                          thickness: 1,
                        ),
                      ),
        
                      /// TECHNICAL SPECS
                      const Text(
                        'Technical Specifications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
        
                     // BRAND & YEAR
Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Brand / Model', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          CustomDropdownFormField(
            value: selectedBrand,
            options: brandOptions,
            hint: 'Select Brand',
            onChanged: (value) => setState(() => selectedBrand = value),
            // validator: (value) => value == null ? 'Required' : null,
          ),
        ],
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Year Model', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          CustomDropdownFormField(
            value: selectedYear,
            options: yearOptions,
            hint: 'Select Year',
            onChanged: (value) => setState(() => selectedYear = value),
            // validator: (value) => value == null ? 'Required' : null,
          ),
        ],
      ),
    ),
  ],
),

const SizedBox(height: 12),

// POWER & FUEL
Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Power / Capacity', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          CustomDropdownFormField(
            value: selectedPower,
            options: powerOptions,
            hint: 'Select Power',
            onChanged: (value) => setState(() => selectedPower = value),
            // validator: (value) => value == null ? 'Required' : null,
          ),
        ],
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fuel Type', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          CustomDropdownFormField(
            value: selectedFuel,
            options: fuelOptions,
            hint: 'Select Fuel Type',
            onChanged: (value) => setState(() => selectedFuel = value),
            // validator: (value) => value == null ? 'Required' : null,
          ),
        ],
      ),
    ),
  ],
),

                      
                      /// CONDI 
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Condition', style: TextStyle(fontSize: 12)),
                          SizedBox(height: 6),
                          // CustomTextFormField(
                          //   hint: 'e.g. Good / Excellent', controller: _equipmentBrandController
                          // ),
                      
                          DropdownButtonFormField<String>(
                            value: selectedCondition,
                            isExpanded: true,
                            dropdownColor: lightColorScheme.onPrimary,
                            decoration: InputDecoration(
                              hintText: 'e.g. Brand New / Excellent',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: lightColorScheme.primary.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: lightColorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: selectedCondition != null
                                  ? IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        setState(() {
                                          selectedCondition = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            items: condition.map((cond) {
                              return DropdownMenuItem<String>(
                                value: cond,
                                child: Text(cond),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCondition = value;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'Required' : null,
                          ),
                          if (getConditionHelpText(selectedCondition) != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              getConditionHelpText(selectedCondition)!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          
                          if (selectedCondition == 'Needs Maintenance') ...[
                            const SizedBox(height: 6),
                            Text(
                              'Please list the defects or issues:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            CustomTextFormField(
                              controller: _defectsController,
                              hint: 'e.g. Broken hydraulic pump, worn tires',
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please describe the defects';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
        
                      SizedBox(width: 12),
        
                      //ATTACHEMENTS (UNSURE PA)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:  [
                          Text('Attachments Included', style: TextStyle(fontSize: 12)),
                          SizedBox(height: 6),
                          CustomTextFormField(
                            hint: 'e.g. Plow, Harrow', controller: _attachmentsController
                          ),
                        ],
                      ),
        
                      /// OPERATOR INCLUDED (YES / NO)
                      const SizedBox(height: 16),
                      const Text(
                        'Operator Included',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
        
                      ToggleButtons(
                        isSelected: [
                          operatorIncluded == true,
                          operatorIncluded == false,
                        ],
                        onPressed: (index) {
                          setState(() {
                            operatorIncluded = index == 0;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        selectedBorderColor: lightColorScheme.primary,
                        selectedColor: Colors.white,
                        fillColor: lightColorScheme.primary,
                        color: lightColorScheme.primary,
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          minWidth: 80,
                        ),
                        children: const [
                          Text('Yes'),
                          Text('No'),
                        ],
                      ),
        
                      const SizedBox(height: 10),
        
                      const Padding(
                        padding: EdgeInsets.all(5),
                        child: Divider(
                          thickness: 1,
                        ),
                      ),
        
                      
                      
                      //PRE REQS/REQUIREMENTS
                      const Text(
                        'Usage Requirements & Conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pumili ng anumang kundisyon o kinakailangan upang magamit ang kagamitang ito. '
                        'Maaaring humingi ng karagdagang detalye o patunay mula sa umuupa.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
        
        
                      /// LAND REQS
                      const SizedBox(height: 16),
                      const Text(
                        'Land Size Requirement',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 8),
                      ToggleButtons(
                        isSelected: [
                          landSizeRequirement == true,
                          landSizeRequirement == false,
                        ],
                        onPressed: (index) {
                          setState(() {
                            landSizeRequirement = index == 0;
                            showLandSizeError = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        selectedBorderColor: lightColorScheme.primary,
                        selectedColor: Colors.white,
                        fillColor: lightColorScheme.primary,
                        color: lightColorScheme.primary,
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          minWidth: 80,
                        ),
                        children: const [
                          Text('Yes'),
                          Text('No'),
                        ],
                      ),

                      /// ERROR TEXT (only shows if not selected)
                      if (showLandSizeError)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Required',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),

                      if (landSizeRequirement == true) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Specify the land size range:',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),

                        /// Row for Min - Max
                        Row(
                          children: [
                            /// Minimum Size Field
                            Expanded(
                              child: CustomTextFormField(
                                controller: _landSizeMinController,
                                keyboardType: TextInputType.number,
                                hint: 'Min (e.g. 1 ha)',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),

                            /// Maximum Size Field
                            Expanded(
                              child: CustomTextFormField(
                                controller: _landSizeMaxController,
                                keyboardType: TextInputType.number,
                                hint: 'Max (e.g. 5 ha)',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],


                      
        
                      /// GRASS / CROP HEIGHT
                      const SizedBox(height: 16),
                      const Text(
                        'Maximum Grass / Crop Height?',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
        
                      ToggleButtons(
                        isSelected: [
                          maxCropHeightRequirement == true,
                          maxCropHeightRequirement == false,
                        ],
                        onPressed: (index) {
                          setState(() {
                            maxCropHeightRequirement = index == 0;
                            showCropHeightError = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        selectedBorderColor: lightColorScheme.primary,
                        selectedColor: Colors.white,
                        fillColor: lightColorScheme.primary,
                        color: lightColorScheme.primary,
                        constraints: const BoxConstraints(
                          minHeight: 40,
                          minWidth: 80,
                        ),
                        children: const [
                          Text('Yes'),
                          Text('No'),
                        ],
                      ),

                      /// ERROR TEXT (only shows if not selected)
                      if (showCropHeightError)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                      'Required',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
        
                      if (maxCropHeightRequirement == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Ilagay ang pinapayagang taas ng damo o pananim:',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        CustomTextFormField(
                          hint: 'e.g. Hanggang 30 cm lamang',
                          maxLines: 1,
                          controller: _maxCropHeightController,
                          validator: (value) {
                            if (maxCropHeightRequirement == true &&
                                (value == null || value.isEmpty)) {
                              return 'Required';
                            }
                            return null;
                                },
                        ),
                      ],

                      const Padding(
                        padding: EdgeInsets.all(5),
                        child: Divider(
                          thickness: 1,
                        ),
                      ),
        

                      const SizedBox(height: 16),
                      //DATE PRICKER
                      const Text(
                        'Availability',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
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
                          child: Text(
                            'Please select availability dates',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
      
                      const SizedBox(height: 16),

                      const Padding(
                        padding: EdgeInsets.all(5),
                        child: Divider(
                          thickness: 1,
                        ),
                      ),

                      /// RENTAL RATE & PRICE
                      const Text(
                        'Rental Pricing',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
        
                      Row(
                        children: [
                          /// RENTAL UNIT
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rate Type',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: selectedRentalUnit,
                                  isExpanded: true,
                                  dropdownColor: lightColorScheme.onPrimary,
                                  decoration: InputDecoration(
                                    hintText: 'Select Rental Rate',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: lightColorScheme.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: lightColorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    prefixIcon: selectedRentalUnit != null
                                        ? IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              setState(() {
                                                selectedRentalUnit = null;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  items: rentalUnit.map((unit) {
                                    return DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedRentalUnit = value;
                                    });
                                  },
                                  validator: (value) =>
                                      value == null ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
        
                          const SizedBox(width: 12),
        
                          /// PRICE
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Price',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                CustomTextFormField(
                                  controller: _equipmentPriceController,
                                  hint: '₱',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty || value == '0') {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        
        
                const SizedBox(height: 15),
        
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onSavePressed, // 👈 just call the function
                        child: Text(
                          'Save',
                          style: TextStyle(
                            color: lightColorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: lightColorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  //FUNCTIONS AND STUFF

    String? getConditionHelpText(String? condition) {
    switch (condition) {
      case 'Brand New':
        return 'Never used equipment with zero operating hours.';
      case 'Excellent':
        return 'Lightly used, fully functional, with minimal wear.';
      case 'Good':
        return 'Regularly used, fully operational, with normal wear and tear.';
      case 'Fair':
        return 'Functional but shows noticeable wear and may require monitoring.';
      case 'Needs Maintenance':
        return 'Operational but requires servicing or repair soon.';
      default:
        return null;
    }
  }
    

  Future<void> pickImage(int tappedIndex) async {
    if (_isPickingImage) return;
    _isPickingImage = true;

    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);

      if (picked != null) {
        setState(() {
          // find first empty slot
          int firstEmptyIndex = images.indexWhere((img) => img == null);
          if (firstEmptyIndex != -1) {
            images[firstEmptyIndex] = picked;
          } else {
            // fallback: replace the tapped box
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

    final DateTime initial = isStart
        ? now
        : (availableFrom ?? now);

    final DateTime first = isStart
        ? now
        : (availableFrom ?? now);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first, // 👈 THIS is the important part
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          availableFrom = picked;

          // Auto-clear "until" if it becomes invalid
          if (availableUntil != null &&
              availableUntil!.isBefore(picked)) {
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

    bool hasImage = images.any((img) => img != null);

    setState(() {
      showLandSizeError = landSizeRequirement == null;
      showCropHeightError = maxCropHeightRequirement == null;
      showImageError = !hasImage;
      showAvailabilityError = availableFrom == null || availableUntil == null;
    });

    if (!isFormValid ||
        landSizeRequirement == null ||
        maxCropHeightRequirement == null ||
        !hasImage ||
        availableFrom == null ||
        availableUntil == null) {
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final authService = AuthService();
      final firestoreService = FirestoreService();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('You must be logged in to create a listing');
      }

      // Get user data for owner name
      final userData = await authService.getUserData(currentUser.uid);
      final ownerName = userData?['firstName'] != null && userData?['lastName'] != null
          ? '${userData!['firstName']} ${userData['lastName']}'
          : currentUser.email?.split('@')[0] ?? 'Unknown';

      final List<String> requirementsList = [];

    print('MIN: ${_landSizeMinController.text}');
    print('MAX: ${_landSizeMaxController.text}');
    print('CROP: ${_maxCropHeightController.text}');

    if (landSizeRequirement == true) {
      requirementsList.add(
        _landSizeMinController.text.isNotEmpty &&
        _landSizeMaxController.text.isNotEmpty
            ? '${_landSizeMinController.text} – ${_landSizeMaxController.text}'
            : 'Land size requirement',
      );
    }

    if (maxCropHeightRequirement == true) {
      requirementsList.add(
        _maxCropHeightController.text.isNotEmpty
            ? '${_maxCropHeightController.text}'
            : 'Max crop height required',
      );
    }


    if (requirementsList.isEmpty) {
      requirementsList.add('No specific requirements');
    }
      // Upload images to Cloudinary
      final cloudinaryService = CloudinaryService();
      final selectedImages = images.where((img) => img != null).map((img) => img!).toList();

      List<String> imageUrls = [];

      if (selectedImages.isNotEmpty) {
        try {
          // Upload all images to Cloudinary
          imageUrls = await cloudinaryService.uploadMultipleImages(
            selectedImages,
            onProgress: (current, total) {
              print('Uploading image $current of $total');
            },
          );

          print('Successfully uploaded ${imageUrls.length} images to Cloudinary');
        } catch (e) {
          // If Cloudinary upload fails, throw error
          throw Exception('Failed to upload images: $e');
        }
      }

      // Create Equipment object
      final equipment = Equipment(
        name: _equipmentNameController.text.trim(),
        description: _equipmentDescriptionController.text.trim(),
        category: selectedCategory,
        brand: selectedBrand, // ✅ use dropdown value
        yearModel: selectedYear, // ✅ use dropdown value
        power: selectedPower ?? 'N/A', // ✅ use dropdown value
        condition: selectedCondition ?? 'Good',
        attachments: _attachmentsController.text.trim().isEmpty
            ? null
            : _attachmentsController.text.trim(),
        operatorIncluded: operatorIncluded ?? false,
        availableFrom: availableFrom,
        availableUntil: availableUntil,
        requirements: requirementsList,
        reviews: [],
        price: double.parse(_equipmentPriceController.text.trim()),
        rentalUnit: selectedRentalUnit ?? 'Per Day',
        ownerId: currentUser.uid,
        ownerName: ownerName,
        imageUrls: imageUrls,
        fuelType: selectedFuel,
        defects: selectedCondition == 'Needs Maintenance'
            ? _defectsController.text.trim()
            : null,
        isAvailable: true, 
        landSizeRequirement: landSizeRequirement ?? false,
        maxCropHeightRequirement: maxCropHeightRequirement ?? false,
        landSizeMin:  _landSizeMinController.text,
        landSizeMax:  _landSizeMaxController.text,
        maxCropHeight: _maxCropHeightController.text.trim().isEmpty
            ? null
            : _maxCropHeightController.text.trim(),

        

      );

      // Save to Firestore
      await firestoreService.addEquipment(equipment.toMap());

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        showConfirmSnackbar(
          context: context,
          title: 'Success!',
          message: 'Equipment listed successfully!',
        );

        // Navigate back after short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        showErrorSnackbar(
          context: context,
          title: 'Error',
          message: e.toString(),
        );
      }
    }
  }

//   void _onSavePressed() async {
//   final isFormValid = _formKey.currentState!.validate();

//   bool hasImage = images.any((img) => img != null);

//   setState(() {
//     showLandSizeError = landSizeRequired == null;
//     showCropHeightError = cropHeightRequired == null;
//     showImageError = !hasImage;
//     showAvailabilityError = availableFrom == null || availableUntil == null;
//   });

//   if (!isFormValid ||
//       landSizeRequired == null ||
//       cropHeightRequired == null ||
//       !hasImage ||
//       availableFrom == null ||
//       availableUntil == null) {
//     // Show error message
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: const Text('Please fill in all required fields'),
//         backgroundColor: Colors.red,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//     return;
//   }

//   try {
//     // Generate unique ID (in real app, this would come from database)
//     final String newId = DateTime.now().millisecondsSinceEpoch.toString();

//     // Collect image paths (convert XFile to asset-style paths or file paths)
//     final List<String> imageUrls = images
//         .where((img) => img != null)
//         .map((img) => img!.path)
//         .toList();

//     // Format dates
//     final String formattedFrom = "${availableFrom!.month.toString().padLeft(2, '0')}/${availableFrom!.day.toString().padLeft(2, '0')}/${availableFrom!.year}";
//     final String formattedTo = "${availableUntil!.month.toString().padLeft(2, '0')}/${availableUntil!.day.toString().padLeft(2, '0')}/${availableUntil!.year}";

//     // Parse land size values if applicable
//     int? minLandSize;
//     int? maxLandSize;
//     if (landSizeRequired == true) {
//       minLandSize = int.tryParse(_minLandSizeController.text.replaceAll(RegExp(r'[^0-9]'), ''));
//       maxLandSize = int.tryParse(_maxLandSizeController.text.replaceAll(RegExp(r'[^0-9]'), ''));
//     }

//     // Parse crop height if applicable
//     double? maxCropHeightValue;
//     if (cropHeightRequired == true) {
//       maxCropHeightValue = double.tryParse(_cropHeightController.text.replaceAll(RegExp(r'[^0-9]'), ''));
//     }

//     // Create new RentItem
//     final RentItem newItem = RentItem(
//       id: newId,
//       title: _equipmentNameController.text.trim(),
//       imageUrls: imageUrls,
//       category: selectedCategory!,
//       price: _equipmentPriceController.text.trim(),
//       rentRate: selectedRentalUnit!.toLowerCase().replaceAll('per ', ''),
//       availableFrom: formattedFrom,
//       availableTo: formattedTo,
//       brand: _equipmentBrandController.text.trim().isNotEmpty 
//           ? _equipmentBrandController.text.trim() 
//           : null,
//       yearModel: _yearController.text.trim().isNotEmpty 
//           ? _yearController.text.trim() 
//           : null,
//       power: _powerController.text.trim().isNotEmpty 
//           ? _powerController.text.trim() 
//           : null,
//       fuelType: _fuelController.text.trim().isNotEmpty 
//           ? _fuelController.text.trim() 
//           : null,
//       condition: selectedCondition,
//       defects: selectedCondition == 'Needs Maintenance' && _defectsController.text.trim().isNotEmpty
//           ? _defectsController.text.trim()
//           : null,
//       attachments: _attachmentsController.text.trim().isNotEmpty 
//           ? _attachmentsController.text.trim() 
//           : null,
//       operatorIncluded: operatorIncluded,
//       landSizeRequirement: landSizeRequired ?? false,
//       landSizeMin: minLandSize,
//       landSizeMax: maxLandSize,
//       maxCropHeightRequirement: cropHeightRequired ?? false,
//       maxCropHeight: maxCropHeightValue,
//       description: _equipmentDescriptionController.text.trim(),
//     );

//     // Save to service
//     await _rentService.addRentItem(newItem);

//     // Show success message
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Equipment listing created successfully!'),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );

//       // Navigate back to previous screen
//       Navigator.pop(context);
//     }

//   } catch (e) {
//     // Show error message
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error saving equipment: $e'),
//           backgroundColor: Colors.red,
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//     debugPrint('Error saving equipment: $e');
//   }
// }


}
