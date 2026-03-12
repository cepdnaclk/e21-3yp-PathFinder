import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';

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
}