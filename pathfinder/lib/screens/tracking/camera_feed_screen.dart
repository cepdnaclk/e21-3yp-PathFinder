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

  final String _userName = 'Unknown';
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer.initialize();
  }

  String _preferVp8Only(String sdp) {
    final lines = sdp.split('\r\n');

    final vp8Payloads = <String>{};
    final allowedPayloads = <String>{};

    for (final line in lines) {
      if (line.startsWith('a=rtpmap:') && line.contains('VP8/90000')) {
        final payload = line.split(':')[1].split(' ')[0];
        vp8Payloads.add(payload);
        allowedPayloads.add(payload);
      }
    }

    for (final line in lines) {
      if (line.startsWith('a=fmtp:') && line.contains('apt=')) {
        final payload = line.split(':')[1].split(' ')[0];
        final apt = line.split('apt=')[1].split(';')[0];

        if (vp8Payloads.contains(apt)) {
          allowedPayloads.add(payload);
        }
      }
    }

    final filteredLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('m=video')) {
        final parts = line.split(' ');
        filteredLines.add([...parts.take(3), ...allowedPayloads].join(' '));
        continue;
      }

      if (line.startsWith('a=rtpmap:') ||
          line.startsWith('a=rtcp-fb:') ||
          line.startsWith('a=fmtp:')) {
        final payload = line.split(':')[1].split(' ')[0];

        if (!allowedPayloads.contains(payload)) {
          continue;
        }
      }

      filteredLines.add(line);
    }

    return filteredLines.join('\r\n');
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

      await roomRef.set({
        'streamRequested': true,
        'streamActive': false,
        'streamAvailable': true,
        'connectionState': 'viewer_joining',
        'lastError': '',
        'offer': {'sdp': '', 'type': ''},
        'answer': {'sdp': '', 'type': ''},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[APP STREAM] streamRequested set to true for room: $roomId');

      final callerDocs = await roomRef.collection('callerCandidates').get();
      for (final doc in callerDocs.docs) {
        await doc.reference.delete();
      }

      final calleeDocs = await roomRef.collection('calleeCandidates').get();
      for (final doc in calleeDocs.docs) {
        await doc.reference.delete();
      }

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

      _peerConnection = await createPeerConnection(config);

      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _connected = true;
          });
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        roomRef.collection('callerCandidates').add(candidate.toMap());
      };

      final offer = await _peerConnection!.createOffer({
        'mandatory': {
          'OfferToReceiveVideo': true,
          'OfferToReceiveAudio': false,
        },
        'optional': [],
      });

      final filteredSdp = _preferVp8Only(offer.sdp ?? '');

      final filteredOffer = RTCSessionDescription(
        filteredSdp,
        offer.type,
      );

      await _peerConnection!.setLocalDescription(filteredOffer);

      await roomRef.set({
        'streamRequested': true,
        'offer': {
          'type': filteredOffer.type,
          'sdp': filteredOffer.sdp,
        },
        'connectionState': 'offer_created',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      roomRef.snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data == null) return;

        final answer = data['answer'];
        if (answer == null) return;

        final answerSdp = answer['sdp'];
        final answerType = answer['type'];

        if (answerSdp == null || answerSdp.toString().isEmpty) return;
        if (answerType == null || answerType.toString().isEmpty) return;

        if (_peerConnection?.signalingState !=
            RTCSignalingState.RTCSignalingStateStable) {
          await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(answerSdp, answerType),
          );
        }
      });

      roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;
            if (data['candidate'] == null) continue;

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
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
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
    final roomRef = FirebaseFirestore.instance
        .collection('streamRooms')
        .doc('test_room');

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
                stream: roomRef.snapshots(),
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
                    _error = 'Stream room not found';
                    return _errorView();
                  }

                  _online = true;

                  final streamAvailable = data['streamAvailable'] == true;

                  const streamRoomId = 'test_room';

                  if (!streamAvailable) {
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
