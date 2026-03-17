import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/review.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:math' show sin, cos, sqrt, atan2;

class NearbyEquipmentResult {
  final Equipment equipment;
  final double? distanceKm;

  const NearbyEquipmentResult({
    required this.equipment,
    required this.distanceKm,
  });
}

class FirestoreService {
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  FirestoreService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

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
  Future<void> updateEquipment(
    String equipmentId,
    Map<String, dynamic> data,
  ) async {
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
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error updating user profile: $e');
    }
  }

  // ── Crop Preferences ────────────────────────────────────────────────────

  /// Returns the user's saved crop preferences, or null if never set.
  /// null → show the onboarding dialog; [] → user saved with no selections.
  Future<List<String>?> getCropPreferences(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || !data.containsKey('cropPreferences')) return null;
      return List<String>.from(data['cropPreferences'] ?? []);
    } catch (e) {
      debugPrint('Error fetching crop preferences: $e');
      return null;
    }
  }

  Future<void> saveCropPreferences(String userId, List<String> crops) async {
    await _firestore.collection('users').doc(userId).update({
      'cropPreferences': crops,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Category seeding ─────────────────────────────────────────────────────

  /// Ensures the three new categories exist in the Firestore categories doc.
  Future<void> ensureNewCategoriesExist() async {
    const newCategories = ['Hand Tractor', 'Floating Tiller', 'Implements'];
    final docRef = _firestore
        .collection('categories')
        .doc('equipment_categories');
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({'categories': newCategories});
      return;
    }

    final existing = List<String>.from(doc.data()?['categories'] ?? []);
    final toAdd = newCategories.where((c) => !existing.contains(c)).toList();
    if (toAdd.isNotEmpty) {
      await docRef.update({'categories': FieldValue.arrayUnion(toAdd)});
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
  // Stream<QuerySnapshot> getAvailableEquipment() {
  //   return _firestore
  //       .collection('equipment')
  //       .orderBy('isAvailable', descending: true) // Available first
  //       .orderBy('createdAt', descending: true)   // Most recent first
  //       .snapshots();
  // }

  Stream<QuerySnapshot> getAvailableEquipment() {
    return _firestore
        .collection('equipment')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ New Cubit-friendly method
  Stream<List<Equipment>> getAvailableEquipmentStream() {
    return _firestore.collection('equipment').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Equipment.fromFirestore(doc)).toList();
    });
  }

  /// Dashboard-specific browse stream compatible with rules (`isAvailable == true`).
  Stream<List<Equipment>> getDashboardBrowseEquipmentStream() {
    return _firestore
        .collection('equipment')
        .where('isAvailable', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return Equipment.fromFirestore(doc);
                } catch (e) {
                  debugPrint('Skipping malformed equipment doc ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<Equipment>()
              .toList();
        });
  }

  bool isEquipmentEffectivelyAvailable(Equipment equipment, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final availableUntil = equipment.availableUntil;

    if (equipment.status != EquipmentStatus.available) return false;
    if (availableUntil == null) return false;

    // Keep consistent with existing browse semantics: available if not yet expired.
    return current.isBefore(availableUntil);
  }

  List<NearbyEquipmentResult> buildDashboardNearbyResults({
    required Iterable<Equipment> equipmentList,
    required String currentUserId,
    required double originLat,
    required double originLng,
    required bool nearbyOnly,
    required double radiusKm,
    required bool sortByDistanceWhenNearbyEnabled,
    Set<String>? allowedCategories,
    bool includeWithoutCoordinatesWhenNearbyDisabled = false,
  }) {
    final normalizedCategories = (allowedCategories ?? <String>{})
        .map((e) => e.trim())
        .toSet();

    final results = <NearbyEquipmentResult>[];

    for (final equipment in equipmentList) {
      if (equipment.ownerId == currentUserId) continue;
      if (!isEquipmentEffectivelyAvailable(equipment)) continue;

      if (normalizedCategories.isNotEmpty) {
        final category = equipment.category?.trim();
        if (category == null || !normalizedCategories.contains(category)) {
          continue;
        }
      }

      final lat = equipment.latitude;
      final lng = equipment.longitude;

      if (lat == null || lng == null) {
        if (nearbyOnly || !includeWithoutCoordinatesWhenNearbyDisabled) {
          continue;
        }
        results.add(
          NearbyEquipmentResult(equipment: equipment, distanceKm: null),
        );
        continue;
      }

      final distance = calculateDistanceKm(
        fromLat: originLat,
        fromLng: originLng,
        toLat: lat,
        toLng: lng,
      );

      if (nearbyOnly && distance > radiusKm) continue;
      results.add(
        NearbyEquipmentResult(equipment: equipment, distanceKm: distance),
      );
    }

    if (nearbyOnly && sortByDistanceWhenNearbyEnabled) {
      results.sort(
        (a, b) => (a.distanceKm ?? double.infinity).compareTo(
          b.distanceKm ?? double.infinity,
        ),
      );
    }

    return results;
  }

  /// Get unique equipment categories from Firestore
  Future<List<String>> getUniqueEquipmentCategories() async {
    try {
      final doc = await _firestore
          .collection('categories')
          .doc('equipment_categories')
          .get();

      if (!doc.exists || doc.data() == null) {
        return [];
      }

      return List<String>.from(doc.data()!['categories'] ?? []);
    } catch (e) {
      print('Error fetching categories: $e');
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
    await _firestore.collection('equipment').doc(equipmentId).update({
      'isAvailable': value,
    });
  }

  //   Future<void> validateEquipmentAvailability(String equipmentId) async {
  //   final equipmentRef = FirebaseFirestore.instance.collection('equipment').doc(equipmentId);
  //   final equipmentDoc = await equipmentRef.get();
  //   final data = equipmentDoc.data() as Map<String, dynamic>?;
  //   if (data == null) return;

  //   final availableUntil = data['availableUntil'] as Timestamp?;
  //   bool isAvailable = false;

  //   final now = DateTime.now();

  //   // 1️⃣ Check date-based availability
  //   if (availableUntil != null) {
  //     final until = availableUntil.toDate();
  //     isAvailable = now.isBefore(until);
  //   }

  //   // 2️⃣ Check rent requests for this equipment
  //   final rentRequestsSnapshot = await FirebaseFirestore.instance
  //       .collection('rentRequests')
  //       .where('itemId', isEqualTo: equipmentId)
  //       .where('status', whereIn: ['approved', 'inProgress'])
  //       .get();

  //   if (rentRequestsSnapshot.docs.isNotEmpty) {
  //     // If there’s an active request, mark as unavailable
  //     isAvailable = false;
  //   }

  //   // ✅ Update Firestore
  //   await equipmentRef.update({'isAvailable': isAvailable});
  // }

  Future<void> validateAllEquipmentAvailability() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('equipment')
        .get();

    for (var doc in snapshot.docs) {
      await validateEquipmentAvailability(doc.id);
    }
  }

  // Add this method to check for booking conflicts
  Future<bool> hasBookingConflict(
    String equipmentId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('rentRequests')
          .where('itemId', isEqualTo: equipmentId)
          .where('status', whereIn: ['approved', 'onTheWay', 'inProgress'])
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final bookedStart = (data['start'] as Timestamp).toDate();
        final bookedEnd = (data['end'] as Timestamp).toDate();

        // Check if dates overlap
        // Overlap occurs if: new start is before booked end AND new end is after booked start
        if (startDate.isBefore(bookedEnd) && endDate.isAfter(bookedStart)) {
          return true; // Conflict found
        }
      }

      return false; // No conflicts
    } catch (e) {
      print('Error checking booking conflict: $e');
      return true; // Assume conflict on error to be safe
    }
  }

  // Get all booked date ranges for an equipment (useful for UI)
  Future<List<Map<String, DateTime>>> getBookedDateRanges(
    String equipmentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('rentRequests')
          .where('itemId', isEqualTo: equipmentId)
          .where('status', whereIn: ['approved', 'onTheWay', 'inProgress'])
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'start': (data['start'] as Timestamp).toDate(),
          'end': (data['end'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error fetching booked dates: $e');
      return [];
    }
  }

  bool _areAllDatesBooked(
    DateTime availableFrom,
    DateTime availableUntil,
    List<Map<String, DateTime>> bookedRanges,
  ) {
    final earliestBookable = getEarliestBookingDate();
    final checkFrom = earliestBookable.isAfter(availableFrom)
        ? earliestBookable
        : availableFrom;
    DateTime current = DateTime(checkFrom.year, checkFrom.month, checkFrom.day);

    while (!current.isAfter(availableUntil)) {
      bool isBooked = false;

      for (var range in bookedRanges) {
        final rangeStart = DateTime(
          range['start']!.year,
          range['start']!.month,
          range['start']!.day,
        );
        final rangeEnd = DateTime(
          range['end']!.year,
          range['end']!.month,
          range['end']!.day,
        );

        // Same logic as DateStep._isDateBooked
        if ((current.isAfter(rangeStart) ||
                current.isAtSameMomentAs(rangeStart)) &&
            (current.isBefore(rangeEnd) ||
                current.isAtSameMomentAs(rangeEnd))) {
          isBooked = true;
          break;
        }
      }

      if (!isBooked) return false; // found a free day

      current = current.add(const Duration(days: 1));
    }

    return true; // all days booked
  }

  Future<void> validateEquipmentAvailability(String equipmentId) async {
    final equipmentRef = FirebaseFirestore.instance
        .collection('equipment')
        .doc(equipmentId);

    final equipmentDoc = await equipmentRef.get();
    final data = equipmentDoc.data() as Map<String, dynamic>?;
    if (data == null) return;

    final status = data['status'] as String?;
    if (status == 'under_maintenance') {
      return;
    }

    final availableFrom = (data['availableFrom'] as Timestamp?)?.toDate();
    final availableUntil = (data['availableUntil'] as Timestamp?)?.toDate();

    if (availableFrom == null || availableUntil == null) {
      await equipmentRef.update({
        'isAvailable': false,
        'status': EquipmentStatus.unavailable.toValue(),
      });
      return;
    }

    final now = DateTime.now();

    if (now.isAfter(availableUntil)) {
      await equipmentRef.update({
        'isAvailable': false,
        'status': EquipmentStatus.unavailable.toValue(),
      });
      return;
    }

    final bookedSnapshot = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: ['approved', 'onTheWay', 'inProgress'])
        .get();

    List<Map<String, DateTime>> bookedRanges = bookedSnapshot.docs.map((doc) {
      final d = doc.data();
      return {
        'start': (d['start'] as Timestamp).toDate(),
        'end': (d['end'] as Timestamp).toDate(),
      };
    }).toList();

    final earliestBookable = getEarliestBookingDate();
    final checkFrom = earliestBookable.isAfter(availableFrom)
        ? earliestBookable
        : availableFrom;
    DateTime current = DateTime(checkFrom.year, checkFrom.month, checkFrom.day);

    final hasFreeDay = !_areAllDatesBooked(
      availableFrom,
      availableUntil,
      bookedRanges,
    );

    await equipmentRef.update({
      'isAvailable': hasFreeDay,
      'status': hasFreeDay
          ? EquipmentStatus.available.toValue()
          : EquipmentStatus.unavailable.toValue(),
    });
  }

  /// Force refresh equipment availability and ensure stream updates
  Future<void> validateEquipmentAvailabilityWithNotification(
    String equipmentId,
  ) async {
    print('🔄 Validating availability for equipment: $equipmentId');

    final equipmentRef = FirebaseFirestore.instance
        .collection('equipment')
        .doc(equipmentId);

    final equipmentDoc = await equipmentRef.get();
    final data = equipmentDoc.data() as Map<String, dynamic>?;
    if (data == null) {
      print('❌ Equipment not found');
      return;
    }

    final status = data['status'] as String?;
    if (status == 'under_maintenance') {
      //removed 'unavailable' check
      print('🔒 Equipment is under maintenance, skipping validation');
      return;
    }

    final availableFrom = (data['availableFrom'] as Timestamp?)?.toDate();
    final availableUntil = (data['availableUntil'] as Timestamp?)?.toDate();

    if (availableFrom == null || availableUntil == null) {
      print('⚠️ No availability dates, setting unavailable');
      await equipmentRef.update({
        'isAvailable': false,
        'status': EquipmentStatus.unavailable.toValue(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final now = DateTime.now();

    if (now.isAfter(availableUntil)) {
      print('⏰ Equipment expired');
      await equipmentRef.update({
        'isAvailable': false,
        'status': EquipmentStatus.unavailable.toValue(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    print('🔍 Checking for existing bookings...');
    final bookedSnapshot = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: ['approved', 'onTheWay', 'inProgress'])
        .get();

    print('📊 Found ${bookedSnapshot.docs.length} active bookings');

    List<Map<String, DateTime>> bookedRanges = bookedSnapshot.docs.map((doc) {
      final d = doc.data();
      final start = (d['start'] as Timestamp).toDate();
      final end = (d['end'] as Timestamp).toDate();
      print('   📅 Booking: $start → $end');
      return {'start': start, 'end': end};
    }).toList();

    // Use the same _areAllDatesBooked helper
    final hasFreeDay = !_areAllDatesBooked(
      availableFrom,
      availableUntil,
      bookedRanges,
    );

    print('✅ hasFreeDay: $hasFreeDay');

    await equipmentRef.update({
      'isAvailable': hasFreeDay,
      'status': hasFreeDay
          ? EquipmentStatus.available.toValue()
          : EquipmentStatus.unavailable.toValue(),
      'updatedAt': FieldValue.serverTimestamp(),
      '_lastValidated': FieldValue.serverTimestamp(),
    });

    print(
      '✅ Updated isAvailable: $hasFreeDay, status: ${hasFreeDay ? 'available' : 'unavailable'}',
    );
  }

  /// Returns the earliest selectable date based on lead time (2 working days from now).
  // DateTime getEarliestBookingDate({int leadWorkingDays = 2}) {
  //   DateTime date = DateTime.now();
  //   int daysAdded = 0;

  //   while (daysAdded < leadWorkingDays) {
  //     date = date.add(const Duration(days: 1));
  //     // Skip weekends (Saturday = 6, Sunday = 7)
  //     if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
  //       daysAdded++;
  //     }
  //   }

  //   // Return normalized to midnight
  //   return DateTime(date.year, date.month, date.day);
  // }

  //ver that doesnt skip weekends
  DateTime getEarliestBookingDate() {
    final date = DateTime.now().add(const Duration(days: 2));
    return DateTime(date.year, date.month, date.day);
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

  // Calculate distance between two coordinates (Haversine formula).
  double calculateDistanceKm({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    const double earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(toLat - fromLat);
    final dLon = _degreesToRadians(toLng - fromLng);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_degreesToRadians(fromLat)) *
            cos(_degreesToRadians(toLat)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return calculateDistanceKm(
      fromLat: lat1,
      fromLng: lon1,
      toLat: lat2,
      toLng: lon2,
    );
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

            print(
              '✓ Migrating ${doc.id}: ${availableFrom.toDate()} → ${availableUntil.toDate()}',
            );
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

  // REVIEW METHODS

  /// Submit a review to the 'reviews' collection
  Future<String> submitReview(Review review) async {
    try {
      final docRef = await _firestore.collection('reviews').add({
        ...review.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Error submitting review: $e');
    }
  }

  /// Get all reviews for a specific equipment item
  Future<List<Review>> getReviewsForEquipment(String itemId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('itemId', isEqualTo: itemId)
          .get();

      final reviews = snapshot.docs.map((doc) => Review.fromDoc(doc)).toList();
      reviews.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return reviews;
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  /// Check if a user has already reviewed a specific request
  Future<bool> hasUserReviewedRequest(
    String requestId,
    String reviewerId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('requestId', isEqualTo: requestId)
          .where('reviewerId', isEqualTo: reviewerId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking existing review: $e');
      return false;
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
