import 'package:bukidbayan_app/mock_data/rent_items.dart';
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
          final tempItem = RentItem(
            title: equipment.name,
            imageUrl: equipment.imageUrls.isNotEmpty
                ? equipment.imageUrls
                : ['assets/images/rent1.jpg'],
            category: equipment.category ?? 'Other',
            price: equipment.price.toString(),
            availableFrom: equipment.availableFrom,
            availableTo: equipment.availableUntil,
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
      name: 'Hand Tractor | "Kuliglig"',
      description: 'Powerful hand tractor for small farms.',
      category: 'Machine',
      brand: 'Kubota',
      yearModel: '2024',
      power: '8 HP',
      condition: 'Brand New',
      fuelType: 'Diesel',
      price: 1500,
      rentalUnit: 'Per Day',
      rentRate: 'Fixed',
      landSizeRequirement: true,
      maxCropHeightRequirement: true,
      operatorIncluded: false,
      isAvailable: true,
      ownerId: '01QlKC8JOfdvXkDC9fM4PRNmTOG2',
      imageUrls: [
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411406/0c0f224390f336992685d157655b689a_hhkout.jpg',
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411407/3f09299c57ed9d94b1b4412c1bc85a8f_obtbzl.jpg',
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411407/5cd722318b19c69d1c9a6d4bdeaecb4d_j3ojus.jpg'
      ],
    ),
      Equipment(
      name: 'Rotavator | "Giling - Bundok"',
      description: 'Rotavator for soil preparation.',
      category: 'Machine',
      brand: 'John Deere',
      yearModel: '2022',
      power: '15 HP',
      condition: 'Used',
      fuelType: 'Diesel',
      price: 2000,
      rentalUnit: 'Per Day',
      rentRate: 'Negotiable',
      landSizeRequirement: true,
      maxCropHeightRequirement: true,
      operatorIncluded: true,
      isAvailable: true,
      ownerId: 'ajqjR0HzfWaMQr2zKotP59oh81e2',
      imageUrls: [
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411693/22ea101a99634bd98f9f1ad168a872cd_tymcwb.jpg',
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411693/e65a7f3d8b7399f85b7ec22b5ad7595c_uvyoz2.jpg',
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411693/6cf9ab0aa67b280450ae85fe35c3a329_ura3pb.jpg',
      ],
    ),
    Equipment(
      name: 'Pampatubig', // Nickname: “Water Pump”
      description: 'Ideal for irrigating medium-sized rice fields.',
      category: 'Machine',
      brand: 'Honda',
      yearModel: '2023',
      power: '5 HP',
      condition: 'Brand New',
      fuelType: 'Oil',
      price: 800,
      rentalUnit: 'Per Day',
      rentRate: 'Fixed',
      landSizeRequirement: true,
      maxCropHeightRequirement: false,
      operatorIncluded: false,
      isAvailable: true,
      ownerId: 'Msl2UVxTplNWkx8QVRUMvrAYgyA2',
      imageUrls: [
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411861/00bf7f3b2f18bee3c753106608e13c82_lalfni.jpg',
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411861/db087407776360db50bc961f94e9977e_bt6goj.jpg',
      ],
    ),
    Equipment(
      name: 'Water Sprayer',
      description: 'Electric water sprayer for crops.',
      category: 'Machine',
      brand: 'Stihl',
      yearModel: '2025',
      power: '2 HP',
      condition: 'Brand New',
      fuelType: 'Electric',
      price: 500,
      rentalUnit: 'Per Day',
      rentRate: 'Fixed',
      landSizeRequirement: false,
      maxCropHeightRequirement: false,
      operatorIncluded: false,
      isAvailable: true,
      ownerId: 'EN3Nlympc7Xon6Kdkqygsmr8al73',
      imageUrls: [
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769411966/7d86410f82f146b7c146b42f986be013_honwwg.jpg',
      ],
    ),
    Equipment(
      name: 'Seeder',
      description: 'Seeder for planting seeds efficiently.',
      category: 'Machine',
      brand: 'AGCO',
      yearModel: '2023',
      power: '10 HP',
      condition: 'Brand New',
      fuelType: 'Diesel',
      price: 1800,
      rentalUnit: 'Per Day',
      rentRate: 'Fixed',
      landSizeRequirement: true,
      maxCropHeightRequirement: true,
      operatorIncluded: true,
      isAvailable: true,
      ownerId: '2rRsSFFaPFMHU9mu1z9yDjkjuQm1',
      imageUrls: [
        'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1769412140/fe6031ffa4cc30951c80857e3783aaed_etjtvn.jpg',
      ],
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