import 'package:cloud_firestore/cloud_firestore.dart';

class SafeZoneModel {
  final String name;
  final double lat;
  final double lng;
  final double radius;

  SafeZoneModel({
    required this.name,
    required this.lat,
    required this.lng,
    required this.radius,
  });

  factory SafeZoneModel.fromMap(Map<String, dynamic> data) {
    return SafeZoneModel(
      name: data['name'] ?? 'Safe Zone',
      lat: (data['lat'] ?? 0).toDouble(),
      lng: (data['lng'] ?? 0).toDouble(),
      radius: (data['radius'] ?? 100).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'radius': radius,
    };
  }
}

class DeviceModel {
  final String id;
  final String userName;
  final double gpsLat;
  final double gpsLng;
  final bool online;
  final int batteryLevel;
  final bool sosActive;
  final Timestamp? lastUpdated;
  final List<SafeZoneModel> safeZones;

  DeviceModel({
    required this.id,
    required this.userName,
    required this.gpsLat,
    required this.gpsLng,
    required this.online,
    required this.batteryLevel,
    required this.sosActive,
    required this.lastUpdated,
    required this.safeZones,
  });

  factory DeviceModel.fromFirestore(String id, Map<String, dynamic> data) {
    final safeZonesRaw = (data['safeZones'] as List?) ?? [];

    return DeviceModel(
      id: id,
      userName: data['userName'] ?? 'Unknown',
      gpsLat: (data['gpsLat'] ?? 0).toDouble(),
      gpsLng: (data['gpsLng'] ?? 0).toDouble(),
      online: data['online'] ?? false,
      batteryLevel: (data['batteryLevel'] ?? 0).toInt(),
      sosActive: data['sosActive'] ?? false,
      lastUpdated: data['lastUpdated'],
      safeZones: safeZonesRaw
          .map((e) => SafeZoneModel.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}