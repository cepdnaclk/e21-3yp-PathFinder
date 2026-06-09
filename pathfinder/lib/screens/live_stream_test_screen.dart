import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveStreamTestScreen extends StatelessWidget {
  const LiveStreamTestScreen({super.key});

  final String deviceId = 'pathfinder_001';

  @override
  Widget build(BuildContext context) {
    final deviceRef = FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Stream Test'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: deviceRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;

          if (data == null) {
            return const Center(child: Text('Device document not found'));
          }

          final streamEnabled = data['streamEnabled'] == true;
          final streamStatus = data['streamStatus'] ?? 'unknown';
          final streamRoomId = data['streamRoomId'] ?? '';

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  streamEnabled
                      ? 'LIVE STREAM AVAILABLE'
                      : 'STREAM OFF',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 20),
                Text('Status: $streamStatus'),
                Text('Room ID: $streamRoomId'),
                const SizedBox(height: 20),
                if (streamEnabled && streamRoomId.isNotEmpty)
                  ElevatedButton(
                    onPressed: () async {
                      final roomDoc = await FirebaseFirestore.instance
                          .collection('streamRooms')
                          .doc(streamRoomId)
                          .get();

                      if (!roomDoc.exists) {
                        print('Room not found');
                        return;
                      }

                      final roomData = roomDoc.data();
                      print('Room data: $roomData');

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room found. Check debug console.'),
                        ),
                      );
                    },
                    child: const Text('Open Live Stream'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
