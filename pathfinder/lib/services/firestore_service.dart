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

    if (!caretakerDoc.exists) {
      return null;
    }

    final data = caretakerDoc.data();
    if (data == null) {
      return null;
    }

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
    if (user == null) {
      throw Exception("No logged in user");
    }

    final caretakerRef = _firestore.collection('caretakers').doc(user.uid);
    final deviceRef = _firestore.collection('devices').doc(deviceId);

    final deviceDoc = await deviceRef.get();

    // Prevent another user from linking the same device
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
  // SOS ALERT CREATION
  // ==============================

  Future<void> createSosAlert({
    required String deviceId,
    required String userName,
    required double lat,
    required double lng,
    required int batteryLevel,
  }) async {
    await _firestore.collection('alerts').add({
      'deviceId': deviceId,
      'userName': userName,
      'lat': lat,
      'lng': lng,
      'batteryLevel': batteryLevel,
      'type': 'sos',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==============================
  // ALERT HISTORY STREAM
  // ==============================

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