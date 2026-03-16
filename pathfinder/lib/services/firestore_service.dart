import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';
import '../models/alert_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DeviceModel> getDeviceStream(String deviceId) {
    return _firestore.collection('devices').doc(deviceId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) {
        throw Exception('Device not found');
      }
      return DeviceModel.fromFirestore(doc.id, data);
    });
  }

  Stream<List<AlertModel>> getAlertHistoryStream() {
    return _firestore
        .collection('alerts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AlertModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

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
      'type': 'sos',
      'lat': lat,
      'lng': lng,
      'batteryLevel': batteryLevel,
      'status': 'active',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}