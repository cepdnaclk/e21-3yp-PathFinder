import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CameraFeedScreen extends StatefulWidget {
  final String deviceId;

  const CameraFeedScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<CameraFeedScreen> createState() => _CameraFeedScreenState();
}

class _CameraFeedScreenState extends State<CameraFeedScreen> {
  String? _error;

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  bool _connected = false;
  bool _joining = false;

  String _userName = 'Unknown';
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  Future<void> _joinWebRtcStream(String roomId) async {
    if (_joining || _connected) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final roomRef =
          FirebaseFirestore.instance.collection('streamRooms').doc(roomId);

      final roomSnapshot = await roomRef.get();
      final roomData = roomSnapshot.data();

      if (roomData == null || roomData['offer'] == null) {
        throw Exception('No WebRTC offer found for this stream room');
      }

      final offer = roomData['offer'];

      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      _peerConnection = await createPeerConnection(config);

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _connected = true;
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        roomRef.collection('viewerCandidates').add(candidate.toMap());
      };

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          offer['sdp'],
          offer['type'],
        ),
      );

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await roomRef.update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        }
      });

      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            _peerConnection?.addCandidate(
              RTCIceCandidate(
                data['candidate'],
                data['sdpMid'],
                data['sdpMLineIndex'],
              ),
            );
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _joining = false;
      });
    }
  }

  Future<void> _closeConnection() async {
    await _peerConnection?.close();
    _peerConnection = null;

    if (mounted) {
      setState(() {
        _connected = false;
        _remoteRenderer.srcObject = null;
      });
    }
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: Colors.black87),
        onPressed: onTap,
      ),
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1EC),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: Colors.white,
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _streamOffView() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFFFE8E8),
                child: Icon(
                  Icons.videocam_off,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Live Stream Is Off',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'The user has not started the live camera stream.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.red.withValues(alpha: 0.10),
                child: const Icon(
                  Icons.videocam_off,
                  size: 48,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Stream Unavailable',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unable to load camera stream.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraView(String roomId) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  Container(
                    color: Colors.black,
                    child: _connected
                        ? RTCVideoView(
                            _remoteRenderer,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitContain,
                          )
                        : Center(
                            child: Text(
                              _joining
                                  ? 'Connecting to stream...'
                                  : 'Tap refresh to open stream',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    right: 18,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.purple.shade50,
                            child: const Icon(
                              Icons.videocam,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Live Camera',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color:
                                          _online ? Colors.green : Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _online
                                          ? 'Device online'
                                          : 'Device offline',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _joinWebRtcStream(roomId),
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(32),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Camera Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statusCard(
                    icon: Icons.person_pin_circle,
                    title: 'Tracked User',
                    value: _userName,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  _statusCard(
                    icon: Icons.sensors,
                    title: 'Device',
                    value: _online ? 'Online' : 'Offline',
                    color: _online ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceRef = FirebaseFirestore.instance
        .collection('devices')
        .doc(widget.deviceId);

    return Scaffold(
      backgroundColor: const Color(0xFFF4D9DD),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                children: [
                  _topButton(
                    icon: Icons.arrow_back,
                    onTap: () {
                      _closeConnection();
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  const Text(
                    'Live Camera',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 52),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: deviceRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    _error = snapshot.error.toString();
                    return _errorView();
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data =
                      snapshot.data!.data() as Map<String, dynamic>?;

                  if (data == null) {
                    _error = 'Device document not found';
                    return _errorView();
                  }

                  _userName = (data['userName'] ?? 'Unknown').toString();
                  _online = data['online'] == true;

                  final streamEnabled = data['streamEnabled'] == true;
                  final streamRoomId =
                      (data['streamRoomId'] ?? '').toString();

                  if (!streamEnabled || streamRoomId.isEmpty) {
                    if (_connected) {
                      _closeConnection();
                    }
                    return _streamOffView();
                  }

                  if (_error != null) {
                    return _errorView();
                  }

                  return _cameraView(streamRoomId);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}