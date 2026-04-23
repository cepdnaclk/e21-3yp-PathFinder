import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device_model.dart';
import '../models/alert_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==============================
  // CARETAKER ↔ DEVICE LINKING
  // ==============================

  Future<String?> getLinkedDeviceId(String uid) async {
    final caretakerDoc =
        await _firestore.collection('caretakers').doc(uid).get();

    if (!caretakerDoc.exists) return null;

    final data = caretakerDoc.data();
    if (data == null) return null;

    return data['deviceId'] as String?;
  }

  Future<Map<String, dynamic>?> getCaretakerData(String uid) async {
    final doc = await _firestore.collection('caretakers').doc(uid).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getDeviceData(String deviceId) async {
    final doc = await _firestore.collection('devices').doc(deviceId).get();
    return doc.data();
  }

  Future<void> unlinkCaretakerFromDevice({
    required String uid,
    required String deviceId,
  }) async {
    final caretakerRef = _firestore.collection('caretakers').doc(uid);
    final deviceRef = _firestore.collection('devices').doc(deviceId);

    await caretakerRef.set({
      'deviceId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await deviceRef.set({
      'ownerId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> linkCaretakerToDevice(String deviceId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No logged in user");

    final caretakerRef = _firestore.collection('caretakers').doc(user.uid);
    final deviceRef = _firestore.collection('devices').doc(deviceId);

    final deviceDoc = await deviceRef.get();

    if (deviceDoc.exists) {
      final existingOwner = deviceDoc.data()?['ownerId'];
      if (existingOwner != null && existingOwner != user.uid) {
        throw Exception("This device is already linked to another caretaker.");
      }
    }

    await caretakerRef.set({
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'deviceId': deviceId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await deviceRef.set({
      'deviceName': deviceId,
      'ownerId': user.uid,
      'userName': user.displayName ?? 'Unknown',
      'gpsLat': 0.0,
      'gpsLng': 0.0,
      'online': false,
      'batteryLevel': 0,
      'sosActive': false,
      'status': 'active',
      'safeZone': null,
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==============================
  // DEVICE STREAM
  // ==============================

  Stream<DeviceModel> getDeviceStream(String deviceId) {
    return _firestore.collection('devices').doc(deviceId).snapshots().map((doc) {
      final data = doc.data();

      if (data == null) {
        throw Exception("Device document not found");
      }

      return DeviceModel.fromFirestore(doc.id, data);
    });
  }

  // ==============================
  // SAFE ZONE
  // ==============================

  Future<void> saveSafeZone({
    required String deviceId,
    required String name,
    required double lat,
    required double lng,
    required double radius,
  }) async {
    await _firestore.collection('devices').doc(deviceId).set({
      'safeZone': {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius': radius,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeSafeZone(String deviceId) async {
    await _firestore.collection('devices').doc(deviceId).set({
      'safeZone': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==============================
  // ALERTS
  // ==============================

  Future<void> createSosAlert({
    required String deviceId,
    required String userName,
    required double lat,
    required double lng,
    required int batteryLevel,
  }) async {
    final existing = await _firestore
        .collection('alerts')
        .where('deviceId', isEqualTo: deviceId)
        .where('type', isEqualTo: 'sos')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _firestore.collection('alerts').add({
      'deviceId': deviceId,
      'userName': userName,
      'lat': lat,
      'lng': lng,
      'batteryLevel': batteryLevel,
      'type': 'sos',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'acknowledgedAt': null,
      'resolvedAt': null,
      'acknowledgedBy': null,
      'notes': '',
    });
  }

  Future<void> createLowBatteryAlert({
    required String deviceId,
    required String userName,
    required double lat,
    required double lng,
    required int batteryLevel,
  }) async {
    final existing = await _firestore
        .collection('alerts')
        .where('deviceId', isEqualTo: deviceId)
        .where('type', isEqualTo: 'low_battery')
        .where('status', whereIn: ['active', 'acknowledged'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _firestore.collection('alerts').add({
      'deviceId': deviceId,
      'userName': userName,
      'lat': lat,
      'lng': lng,
      'batteryLevel': batteryLevel,
      'type': 'low_battery',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'acknowledgedAt': null,
      'resolvedAt': null,
      'acknowledgedBy': null,
      'notes': '',
    });
  }

  Future<void> createSafeZoneExitAlert({
    required String deviceId,
    required String userName,
    required double lat,
    required double lng,
    required int batteryLevel,
  }) async {
    final existing = await _firestore
        .collection('alerts')
        .where('deviceId', isEqualTo: deviceId)
        .where('type', isEqualTo: 'safe_zone_exit')
        .where('status', whereIn: ['active', 'acknowledged'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    await _firestore.collection('alerts').add({
      'deviceId': deviceId,
      'userName': userName,
      'lat': lat,
      'lng': lng,
      'batteryLevel': batteryLevel,
      'type': 'safe_zone_exit',
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'acknowledgedAt': null,
      'resolvedAt': null,
      'acknowledgedBy': null,
      'notes': '',
    });
  }

  Future<void> resolveActiveAlertsByType({
    required String deviceId,
    required String type,
  }) async {
    final snapshot = await _firestore
        .collection('alerts')
        .where('deviceId', isEqualTo: deviceId)
        .where('type', isEqualTo: type)
        .where('status', whereIn: ['active', 'acknowledged'])
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.set({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<AlertModel?> getLatestActiveSosAlert(String deviceId) async {
    final snapshot = await _firestore
        .collection('alerts')
        .where('deviceId', isEqualTo: deviceId)
        .where('type', isEqualTo: 'sos')
        .where('status', whereIn: ['active', 'acknowledged'])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return AlertModel.fromFirestore(doc.id, doc.data());
  }

  Future<void> acknowledgeAlert(String alertId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No logged in user");

    await _firestore.collection('alerts').doc(alertId).set({
      'status': 'acknowledged',
      'acknowledgedAt': FieldValue.serverTimestamp(),
      'acknowledgedBy': user.uid,
    }, SetOptions(merge: true));
  }

  Future<void> resolveAlert(String alertId) async {
    await _firestore.collection('alerts').doc(alertId).set({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<AlertModel>> getAlertHistoryStream(String deviceId) {
    return _firestore
        .collection('alerts')
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AlertModel.fromFirestore(doc.id, data);
      }).toList();
    });
  }
}