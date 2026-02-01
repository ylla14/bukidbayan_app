import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyEquipment extends StatelessWidget {
  MyEquipment({super.key});

  final FirestoreService _firestoreService = FirestoreService();


  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('equipment')
                  .where('ownerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No equipment listed yet.'));
                }

                final equipmentList = snapshot.data!.docs
                    .map((doc) => Equipment.fromFirestore(doc))
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: equipmentList.length,
                  itemBuilder: (context, index) {
                    return buildEquipmentCard(equipmentList[index]);
                  },
                );
              },
            ),
          ),

          

          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: addSampleEquipment,
              child: const Text('Add Sample Equipment'),
            ),
          ),
        ],
      ),
    );
  }

Widget buildEquipmentCard(Equipment equipment) {
  return FutureBuilder<String?>(
    future: _firestoreService.getUserNameById(equipment.ownerId),
    builder: (context, snapshot) {
      final ownerName = snapshot.data ?? 'Unknown Owner';

      return GestureDetector(
        onTap: () {
          final tempItem = Equipment(
            name: equipment.name,
            imageUrls: equipment.imageUrls.isNotEmpty
                ? equipment.imageUrls
                : ['assets/images/rent1.jpg'],
            category: equipment.category ?? 'Other',
            price: equipment.price,
            availableFrom: equipment.availableFrom,
            availableUntil: equipment.availableUntil,
            brand: equipment.brand,
            yearModel: equipment.yearModel,
            power: equipment.power,
            fuelType: equipment.fuelType,
            condition: equipment.condition,
            attachments: equipment.attachments,
            operatorIncluded: equipment.operatorIncluded,
            rentRate: equipment.rentRate ?? 'Unknown Rent Rate',
            landSizeRequirement: equipment.landSizeRequirement,
            maxCropHeightRequirement: equipment.maxCropHeightRequirement,
            id: equipment.id ?? 'UNKNOWN ID',
            description: equipment.description,
            landSizeMax: equipment.landSizeMax,
            landSizeMin: equipment.landSizeMin,
            maxCropHeight: equipment.maxCropHeight,
            ownerName: ownerName,
            rentalUnit: equipment.rentalUnit,
            ownerId: equipment.ownerId
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductPage(item: tempItem),
            ),
          );
        },
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(equipment.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(equipment.category ?? 'No category'),
                Text('₱${equipment.price} ${equipment.rentalUnit}'),
                Text(
                  equipment.isAvailable ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    color: equipment.isAvailable ? Colors.green : Colors.red,
                  ),
                ),
                Text('Owner: $ownerName'),
              ],
            ),
          ),
        ),
      );
    },
  );
}


void addSampleEquipment() async {
  final List<Equipment> sampleEquipment = [
    Equipment(
      name: 'John Deere S700 Harvester',
      description: 'A high-efficiency combine harvester suitable for large-scale rice and corn harvesting.',
      category: 'Harvester',
      brand: 'John Deere',
      yearModel: '2021',
      power: '460 HP',
      condition: 'Excellent',
      attachments: 'Grain header, corn header',
      fuelType: 'Diesel',
      defects: null,
      price: 15000.0,
      rentalUnit: 'Per Day',
      rentRate: 'Fixed',
      requirements: ['Valid ID', 'Signed Rental Agreement'],
      landSizeRequirement: true,
      maxCropHeightRequirement: true,
      landSizeMin: '2 hectares',
      landSizeMax: '50 hectares',
      maxCropHeight: '250 cm',
      operatorIncluded: true,
      isAvailable: true,
      availableFrom: DateTime.now(),
      availableUntil: DateTime.now().add(Duration(days: 30)),
      ownerId: '01QlKC8JOfdvXkDC9fM4PRNmTOG2',
      ownerName: 'Yaeno Muteki',
      location: 'Laguna, Philippines',
      latitude: 14.1700,
      longitude: 121.2500,
      imageUrls: [
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411693/22ea101a99634bd98f9f1ad168a872cd_tymcwb.jpg',
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411693/e65a7f3d8b7399f85b7ec22b5ad7595c_uvyoz2.jpg',
      ],
      reviews: ['Very efficient!', 'Well-maintained equipment.'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  for (var equipment in sampleEquipment) {
    await FirebaseFirestore.instance
        .collection('equipment')
        .add(equipment.toMap())
        .then((docRef) => print('Added: ${equipment.name} with ID ${docRef.id}'))
        .catchError((error) => print('Error adding ${equipment.name}: $error'));
  }
}

}