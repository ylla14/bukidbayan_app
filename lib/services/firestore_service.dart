import 'package:bukidbayan_app/models/equipment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' show sin, cos, sqrt, atan2;

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // EQUIPMENT METHODS

  // Add new equipment
  Future<String> addEquipment(Map<String, dynamic> equipmentData) async {
    try {
      DocumentReference docRef = await _firestore.collection('equipment').add({
        ...equipmentData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Error adding equipment: $e');
    }
  }

  // Get all equipment
  Stream<QuerySnapshot> getAllEquipment() {
    return _firestore
        .collection('equipment')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get equipment by owner
  Stream<QuerySnapshot> getEquipmentByOwner(String ownerId) {
    return _firestore
        .collection('equipment')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get single equipment by ID
  Future<DocumentSnapshot> getEquipmentById(String equipmentId) async {
    return await _firestore.collection('equipment').doc(equipmentId).get();
  }

  // Update equipment
  Future<void> updateEquipment(String equipmentId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('equipment').doc(equipmentId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating equipment: $e');
    }
  }

  // Delete equipment
  Future<void> deleteEquipment(String equipmentId) async {
    try {
      await _firestore.collection('equipment').doc(equipmentId).delete();
    } catch (e) {
      throw Exception('Error deleting equipment: $e');
    }
  }

  // RENTAL/BOOKING METHODS

  // Create a rental booking
  Future<String> createBooking(Map<String, dynamic> bookingData) async {
    try {
      DocumentReference docRef = await _firestore.collection('bookings').add({
        ...bookingData,
        'status': 'pending', // pending, confirmed, completed, cancelled
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating booking: $e');
    }
  }

  // Get bookings by renter (user who is renting)
  Stream<QuerySnapshot> getBookingsByRenter(String renterId) {
    return _firestore
        .collection('bookings')
        .where('renterId', isEqualTo: renterId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get bookings by owner (user who owns the equipment)
  Stream<QuerySnapshot> getBookingsByOwner(String ownerId) {
    return _firestore
        .collection('bookings')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Update booking status
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating booking status: $e');
    }
  }

  // USER PROFILE METHODS

  // Get user profile
  Future<DocumentSnapshot> getUserProfile(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating user profile: $e');
    }
  }

  /// 🔹 NEW METHOD
  /// Fetch user name by ID (useful for ownerId -> display owner name)
  Future<String?> getUserNameById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final firstName = data['firstName'] as String?;
          final lastName = data['lastName'] as String?;
          final fullName = [firstName, lastName].whereType<String>().join(' ');
          print('Fetched name for userId $userId: $fullName');
          return fullName.isNotEmpty ? fullName : null;
        }
      } else {
        print('No user document found for userId: $userId');
      }
      return null;
    } catch (e) {
      print('Error fetching user name: $e');
      return null;
    }
  }



  // SEARCH AND FILTER METHODS (KF8 - Equipment Discovery)

  // Search equipment by category
  Stream<QuerySnapshot> searchEquipmentByCategory(String category) {
    return _firestore
        .collection('equipment')
        .where('category', isEqualTo: category)
        .where('isAvailable', isEqualTo: true)
        // Note: orderBy requires a composite index
        // .orderBy('createdAt', descending: true)
        .snapshots();
  }

// Search equipment by availability (all items, available first)
  Stream<QuerySnapshot> getAvailableEquipment() {
    return _firestore
        .collection('equipment')
        .orderBy('isAvailable', descending: true) // Available first
        .orderBy('createdAt', descending: true)   // Most recent first
        .snapshots();
  }

   /// ✅ New Cubit-friendly method
  Stream<List<Equipment>> getAvailableEquipmentStream() {
    return _firestore.collection('equipment').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Equipment.fromFirestore(doc)).toList();
    });
  }

  /// Get unique equipment categories from Firestore
  Future<List<String>> getUniqueEquipmentCategories() async {
    try {
      final snapshot = await _firestore.collection('equipment').get();

      // Map all documents to their category
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final category = data['category'] as String?;
            return category;
          })
          .where((category) => category != null && category.isNotEmpty)
          .cast<String>()
          .toList();

      // Convert to a set to remove duplicates, then back to a list
      final uniqueCategories = categories.toSet().toList();

      return uniqueCategories;
    } catch (e) {
      print('Error fetching unique categories: $e');
      return [];
    }
  }


  bool calculateAvailability(Map<String, dynamic> data) {
    final availableFrom = data['availableFrom'] as Timestamp?;
    final availableUntil = data['availableUntil'] as Timestamp?;

    if (availableUntil == null) return false; // no end date = unavailable

    final now = DateTime.now();
    final from = availableFrom?.toDate();
    final until = availableUntil.toDate();

    // Available if the end date is in the future (can book now even if starts later)
    return now.isBefore(until);
  } 




    Future<void> setAvailability(String equipmentId, bool value) async {
    await _firestore
        .collection('equipment')
        .doc(equipmentId)
        .update({'isAvailable': value});
  }

  Future<void> validateEquipmentAvailability(String equipmentId) async {
  final equipmentRef = FirebaseFirestore.instance.collection('equipment').doc(equipmentId);
  final equipmentDoc = await equipmentRef.get();
  final data = equipmentDoc.data() as Map<String, dynamic>?;
  if (data == null) return;

  final availableUntil = data['availableUntil'] as Timestamp?;
  bool isAvailable = false;

  final now = DateTime.now();

  // 1️⃣ Check date-based availability
  if (availableUntil != null) {
    final until = availableUntil.toDate();
    isAvailable = now.isBefore(until);
  }

  // 2️⃣ Check rent requests for this equipment
  final rentRequestsSnapshot = await FirebaseFirestore.instance
      .collection('rentRequests')
      .where('itemId', isEqualTo: equipmentId)
      .where('status', whereIn: ['approved', 'inProgress'])
      .get();

  if (rentRequestsSnapshot.docs.isNotEmpty) {
    // If there’s an active request, mark as unavailable
    isAvailable = false;
  }

  // ✅ Update Firestore
  await equipmentRef.update({'isAvailable': isAvailable});
}


  Future<void> validateAllEquipmentAvailability() async {
    final snapshot = await FirebaseFirestore.instance.collection('equipment').get();

    for (var doc in snapshot.docs) {
      await validateEquipmentAvailability(doc.id);
    }
  }


  // Filter equipment by operator availability
  Stream<QuerySnapshot> searchEquipmentByOperator(bool operatorIncluded) {
    return _firestore
        .collection('equipment')
        .where('isAvailable', isEqualTo: true)
        .where('operatorIncluded', isEqualTo: operatorIncluded)
        // Note: orderBy requires a composite index
        // .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Combined filter: category + operator availability
  Stream<QuerySnapshot> searchEquipmentByCategoryAndOperator(
    String category,
    bool operatorIncluded,
  ) {
    return _firestore
        .collection('equipment')
        .where('category', isEqualTo: category)
        .where('isAvailable', isEqualTo: true)
        .where('operatorIncluded', isEqualTo: operatorIncluded)
        // Note: orderBy requires a composite index
        // .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get equipment by location (requires latitude/longitude for proximity search)
  // Note: For location proximity, we need to fetch all equipment and filter client-side
  // or use a geohashing solution like GeoFlutterFire (requires additional package)
  
  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  Future<List<DocumentSnapshot>> searchEquipmentByLocation(
    double userLat,
    double userLng,
    double radiusInKm,
  ) async {
    // Fetch all available equipment
    final snapshot = await _firestore
        .collection('equipment')
        .where('isAvailable', isEqualTo: true)
        .get();

    // Filter by distance client-side
    final nearbyEquipment = snapshot.docs.where((doc) {
      final data = doc.data();
      final lat = data['latitude'];
      final lng = data['longitude'];

      if (lat == null || lng == null) return false;

      final distance = _calculateDistance(
        userLat,
        userLng,
        lat.toDouble(),
        lng.toDouble(),
      );

      return distance <= radiusInKm;
    }).toList();

    return nearbyEquipment;
  }

  // ADVANCED SEARCH (combines multiple criteria)
  Future<List<DocumentSnapshot>> advancedEquipmentSearch({
    String? category,
    bool? operatorIncluded,
    double? minPrice,
    double? maxPrice,
    String? condition,
  }) async {
    Query query = _firestore
        .collection('equipment')
        .where('isAvailable', isEqualTo: true);

    // Apply filters
    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }

    if (operatorIncluded != null) {
      query = query.where('operatorIncluded', isEqualTo: operatorIncluded);
    }

    if (condition != null) {
      query = query.where('condition', isEqualTo: condition);
    }

    final snapshot = await query.get();

    // Filter by price range client-side (Firestore has limitations with range queries)
    var results = snapshot.docs;

    if (minPrice != null || maxPrice != null) {
      results = results.where((doc) {
        final price = (doc.data() as Map<String, dynamic>)['price'] ?? 0;
        final priceValue = price is int ? price.toDouble() : price as double;

        if (minPrice != null && priceValue < minPrice) return false;
        if (maxPrice != null && priceValue > maxPrice) return false;

        return true;
      }).toList();
    }

    return results;
  }

  // DROPDOWN OPTIONS (fetched from Firestore for maintainability)

  /// Fetch equipment dropdown options (brands, fuel) from Firestore.
  /// Returns a map with keys: 'brands', 'fuelTypes'.
  Future<Map<String, List<String>>> fetchEquipmentDropdownOptions() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('equipment_options')
          .get();

      if (!doc.exists || doc.data() == null) {
        return {'brands': [], 'fuelTypes': []};
      }

      final data = doc.data()!;
      return {
        'brands': List<String>.from(data['brands'] ?? []),
        'fuelTypes': List<String>.from(data['fuelTypes'] ?? []),
      };
    } catch (e) {
      print('Error fetching dropdown options: $e');
      return {'brands': [], 'fuelTypes': []};
    }
  }

  /// Seed the equipment dropdown options document if it doesn't already exist.
  /// Safe to call on every app start — it's a no-op when the document exists.
  Future<void> seedEquipmentDropdownOptions() async {
    final docRef = _firestore.collection('app_config').doc('equipment_options');
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'brands': ['Mitsubishi', 'Kubota', 'John Deere', 'Honda', 'Stihl'],
        'fuelTypes': ['Diesel', 'Gasoline', 'Electric', 'Hybrid', 'Oil'],
      });
      print('Seeded equipment dropdown options in Firestore.');
    }
  }

  Future<void> migrateEquipmentToMultiPeriods() async {
  try {
    final equipmentSnapshot = await _firestore.collection('equipment').get();
    
    int migratedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var doc in equipmentSnapshot.docs) {
      try {
        final data = doc.data();
        
        // Check if already migrated
        if (data.containsKey('availabilityPeriods') && 
            data['availabilityPeriods'] != null &&
            (data['availabilityPeriods'] as List).isNotEmpty) {
          print('✓ ${doc.id} already migrated');
          skippedCount++;
          continue;
        }

        // Get old single dates
        final availableFrom = data['availableFrom'] as Timestamp?;
        final availableUntil = data['availableUntil'] as Timestamp?;

        List<Map<String, dynamic>> periods = [];

        // Convert to new format if dates exist
        if (availableFrom != null && availableUntil != null) {
          periods.add({
            'from': availableFrom,
            'until': availableUntil,
            'id': 'migrated_period_${DateTime.now().millisecondsSinceEpoch}',
          });
          
          print('✓ Migrating ${doc.id}: ${availableFrom.toDate()} → ${availableUntil.toDate()}');
        } else {
          print('⚠ ${doc.id} has no dates, setting empty periods');
        }

        // 🔒 BACKUP: Keep old fields (don't delete them)
        // Update the document with NEW fields while keeping OLD ones
        await doc.reference.update({
          'availabilityPeriods': periods,
          // availableFrom and availableUntil are NOT deleted, just left as-is
          'isAvailable': periods.isNotEmpty,
          'updatedAt': FieldValue.serverTimestamp(),
          '_migrated': true, // Flag to track migration
          '_migratedAt': FieldValue.serverTimestamp(),
        });

        migratedCount++;
        
      } catch (e) {
        print('❌ Error migrating ${doc.id}: $e');
        errorCount++;
      }
    }

    print('\n=== MIGRATION COMPLETE ===');
    print('✓ Migrated: $migratedCount');
    print('⊘ Skipped (already migrated): $skippedCount');
    print('❌ Errors: $errorCount');
    print('📝 Old fields (availableFrom/Until) preserved for rollback');
    print('==========================\n');
    
  } catch (e) {
    print('❌ Migration failed: $e');
    throw Exception('Migration failed: $e');
  }
}

/// ⏪ ROLLBACK: Restore old format, remove new format
Future<void> rollbackEquipmentMigration() async {
  try {
    final equipmentSnapshot = await _firestore.collection('equipment').get();
    
    int rolledBackCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (var doc in equipmentSnapshot.docs) {
      try {
        final data = doc.data();
        
        // Check if it was migrated
        if (data['_migrated'] != true) {
          print('⊘ ${doc.id} was not migrated, skipping');
          skippedCount++;
          continue;
        }

        // Restore old availability logic
        final availableFrom = data['availableFrom'] as Timestamp?;
        final availableUntil = data['availableUntil'] as Timestamp?;
        
        bool isAvailable = false;
        if (availableUntil != null) {
          final now = DateTime.now();
          final until = availableUntil.toDate();
          isAvailable = now.isBefore(until);
        }

        // Remove new fields, restore old isAvailable logic
        await doc.reference.update({
          'availabilityPeriods': FieldValue.delete(),
          '_migrated': FieldValue.delete(),
          '_migratedAt': FieldValue.delete(),
          'isAvailable': isAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('✓ Rolled back ${doc.id}');
        rolledBackCount++;
        
      } catch (e) {
        print('❌ Error rolling back ${doc.id}: $e');
        errorCount++;
      }
    }

    print('\n=== ROLLBACK COMPLETE ===');
    print('✓ Rolled back: $rolledBackCount');
    print('⊘ Skipped (not migrated): $skippedCount');
    print('❌ Errors: $errorCount');
    print('📝 Original fields (availableFrom/Until) restored');
    print('==========================\n');
    
  } catch (e) {
    print('❌ Rollback failed: $e');
    throw Exception('Rollback failed: $e');
  }
}

}