import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceModel {
  final String id;
  final String userName;
  final double gpsLat;
  final double gpsLng;
  final bool online;
  final int batteryLevel;
  final bool sosActive;
  final Timestamp? lastUpdated;

  DeviceModel({
    required this.id,
    required this.userName,
    required this.gpsLat,
    required this.gpsLng,
    required this.online,
    required this.batteryLevel,
    required this.sosActive,
    required this.lastUpdated,
  });

  factory DeviceModel.fromFirestore(String id, Map<String, dynamic> data) {
    return DeviceModel(
      id: id,
      userName: data['userName'] ?? 'Unknown',
      gpsLat: (data['gpsLat'] ?? 0).toDouble(),
      gpsLng: (data['gpsLng'] ?? 0).toDouble(),
      online: data['online'] ?? false,
      batteryLevel: (data['batteryLevel'] ?? 0).toInt(),
      sosActive: data['sosActive'] ?? false,
      lastUpdated: data['lastUpdated'],
    );
  }
}