import 'package:cloud_firestore/cloud_firestore.dart';

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

  // SEARCH AND FILTER METHODS

  // Search equipment by category
  Stream<QuerySnapshot> searchEquipmentByCategory(String category) {
    return _firestore
        .collection('equipment')
        .where('category', isEqualTo: category)
        .snapshots();
  }

  // Search equipment by availability
  Stream<QuerySnapshot> getAvailableEquipment() {
    return _firestore
        .collection('equipment')
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }
}
