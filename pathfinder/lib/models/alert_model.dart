import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String deviceId;
  final String userName;
  final String type;
  final double lat;
  final double lng;
  final int batteryLevel;
  final String status;
  final Timestamp? timestamp;

  AlertModel({
    required this.id,
    required this.deviceId,
    required this.userName,
    required this.type,
    required this.lat,
    required this.lng,
    required this.batteryLevel,
    required this.status,
    required this.timestamp,
  });

  factory AlertModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AlertModel(
      id: id,
      deviceId: data['deviceId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      type: data['type'] ?? 'unknown',
      lat: (data['lat'] ?? 0).toDouble(),
      lng: (data['lng'] ?? 0).toDouble(),
      batteryLevel: (data['batteryLevel'] ?? 0).toInt(),
      status: data['status'] ?? 'unknown',
      timestamp: data['timestamp'],
    );
  }
}
