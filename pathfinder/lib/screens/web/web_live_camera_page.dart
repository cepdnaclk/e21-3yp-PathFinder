import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebLiveCameraPage extends StatefulWidget {
  const WebLiveCameraPage({super.key});

  @override
  State<WebLiveCameraPage> createState() => _WebLiveCameraPageState();
}

class _WebLiveCameraPageState extends State<WebLiveCameraPage> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  String? _deviceId;
  String? _streamRoomId;

  bool _loading = true;
  bool _connecting = false;
  String _status = 'Preparing live camera...';

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    await _loadDeviceAndRoom();
  }

  Future<void> _loadDeviceAndRoom() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _loading = false;
          _status = 'No user signed in.';
        });
        return;
      }

      final caretakerDoc = await FirebaseFirestore.instance
          .collection('caretakers')
          .doc(user.uid)
          .get();

      final deviceId = caretakerDoc.data()?['deviceId']?.toString();

      if (deviceId == null || deviceId.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'No linked device found.';
        });
        return;
      }

      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();

      final streamRoomId =
          deviceDoc.data()?['streamRoomId']?.toString() ?? 'test_room';

      setState(() {
        _deviceId = deviceId;
        _streamRoomId = streamRoomId;
        _loading = false;
        _status = 'Ready to request live stream.';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Failed to load stream data: $e';
      });
    }
  }

Future<void> _startStream() async {
  if (_streamRoomId == null || _connecting) return;

  setState(() {
    _connecting = true;
    _status = 'Creating WebRTC offer...';
  });

  try {
    final roomRef = FirebaseFirestore.instance
        .collection('streamRooms')
        .doc(_streamRoomId);

    await roomRef.update({
      'streamRequested': true,
      'streamActive': false,
      'connectionState': 'viewer_creating_offer',
      'offer': {'sdp': '', 'type': ''},
      'answer': {'sdp': '', 'type': ''},
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final config = {
      'iceServers': [
        {
          'urls': 'stun:stun.relay.metered.ca:80',
        },
        {
          'urls': 'turn:global.relay.metered.ca:80',
          'username': '171b155e7e3b7363fdc462a5',
          'credential': 'vYNGMpoS3eprvmEZ',
        },
      ],
    };

    final peerConnection = await createPeerConnection(config);
    _peerConnection = peerConnection;

    peerConnection.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _status = 'Live stream connected.';
          _connecting = false;
        });
      }
    };

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) async {
      await roomRef.collection('callerCandidates').add(candidate.toMap());
    };

    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null || data['candidate'] == null) continue;

          peerConnection.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });

    final offer = await peerConnection.createOffer({
      'offerToReceiveVideo': 1,
      'offerToReceiveAudio': 0,
    });

    await peerConnection.setLocalDescription(offer);

    await roomRef.update({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'connectionState': 'offer_created',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _status = 'Offer sent. Waiting for device answer...';
    });

    roomRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;

      final answer = data['answer'];
      if (answer == null) return;

      final sdp = answer['sdp']?.toString() ?? '';
      final type = answer['type']?.toString() ?? '';

      if (sdp.isEmpty || type.isEmpty) return;

      if (peerConnection.signalingState !=
          RTCSignalingState.RTCSignalingStateStable) {
        await peerConnection.setRemoteDescription(
          RTCSessionDescription(sdp, type),
        );

        setState(() {
          _status = 'Answer received. Waiting for video...';
        });
      }
    });
  } catch (e) {
    setState(() {
      _status = 'Failed to start stream: $e';
      _connecting = false;
    });
  }
}


  Future<void> _stopStream() async {
    if (_streamRoomId != null) {
      await FirebaseFirestore.instance
          .collection('streamRooms')
          .doc(_streamRoomId)
          .update({
        'streamRequested': false,
        'connectionState': 'disabled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await _peerConnection?.close();
    _peerConnection = null;

    setState(() {
      _remoteRenderer.srcObject = null;
      _connecting = false;
      _status = 'Stream stopped.';
    });
  }

  @override
  void dispose() {
    _peerConnection?.close();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFF3F4F6),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Camera',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Device: ${_deviceId ?? "-"} | Stream room: ${_streamRoomId ?? "-"}',
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              height: 520,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _remoteRenderer.srcObject == null
                    ? Center(
                        child: Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _connecting ? null : _startStream,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Request Live Stream'),
                ),
                const SizedBox(width: 14),
                OutlinedButton.icon(
                  onPressed: _stopStream,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Stream'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              _status,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}