import 'package:bukidbayan_app/models/equipment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MyEquipment extends StatelessWidget {
  const MyEquipment({super.key});

  @override
  Widget build(BuildContext context) {
    return  ElevatedButton(
      onPressed: addSampleEquipment,
      child: Text('Add 5 Sample Equipment'),
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