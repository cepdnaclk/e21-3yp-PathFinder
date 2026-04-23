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

  // Safe zone
  final String? safeZoneName;
  final double? safeZoneLat;
  final double? safeZoneLng;
  final double? safeZoneRadius;

  DeviceModel({
    required this.id,
    required this.userName,
    required this.gpsLat,
    required this.gpsLng,
    required this.online,
    required this.batteryLevel,
    required this.sosActive,
    required this.lastUpdated,
    required this.safeZoneName,
    required this.safeZoneLat,
    required this.safeZoneLng,
    required this.safeZoneRadius,
  });

  factory DeviceModel.fromFirestore(String id, Map<String, dynamic> data) {
    final safeZone = data['safeZone'] as Map<String, dynamic>?;

    return DeviceModel(
      id: id,
      userName: data['userName'] ?? 'Unknown',
      gpsLat: (data['gpsLat'] ?? 0).toDouble(),
      gpsLng: (data['gpsLng'] ?? 0).toDouble(),
      online: data['online'] ?? false,
      batteryLevel: (data['batteryLevel'] ?? 0).toInt(),
      sosActive: data['sosActive'] ?? false,
      lastUpdated: data['lastUpdated'],
      safeZoneName: safeZone?['name'],
      safeZoneLat: safeZone?['lat'] != null
          ? (safeZone!['lat'] as num).toDouble()
          : null,
      safeZoneLng: safeZone?['lng'] != null
          ? (safeZone!['lng'] as num).toDouble()
          : null,
      safeZoneRadius: safeZone?['radius'] != null
          ? (safeZone!['radius'] as num).toDouble()
          : null,
    );
  }
}