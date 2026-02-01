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

  if (availableFrom == null || availableUntil == null) {
    return false; // no dates = unavailable
  }

  final now = DateTime.now();
  final from = availableFrom.toDate();
  final until = availableUntil.toDate();

  return now.isAfter(from) && now.isBefore(until);
}



    Future<void> setAvailability(String equipmentId, bool value) async {
    await _firestore
        .collection('equipment')
        .doc(equipmentId)
        .update({'isAvailable': value});
  }

  Future<void> validateEquipmentAvailability(String equipmentId) async {
    final docRef = FirebaseFirestore.instance.collection('equipment').doc(equipmentId);
    final doc = await docRef.get();

    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) return;

    final availableFrom = data['availableFrom'];
    final availableUntil = data['availableUntil'];

    bool isAvailable;

    if (availableFrom != null && availableUntil != null) {
      final now = DateTime.now();
      final from = (availableFrom as Timestamp).toDate();
      final until = (availableUntil as Timestamp).toDate();
      isAvailable = now.isAfter(from) && now.isBefore(until);
    } else {
      // Dates missing → mark as unavailable
      isAvailable = false;
    }

    // Update Firestore
    await docRef.update({'isAvailable': isAvailable});
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

  
}