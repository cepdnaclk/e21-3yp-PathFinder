import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../alerts/alert_history_screen.dart';
import '../home/home_screen.dart';
import '../home/settings_screen.dart';
import 'live_tracking_screen.dart';

class _FeedColors {
  static const background = Color(0xFF2B3749);
  static const blue = Color(0xFF2563EB);
  static const lightBlue = Color(0xFF60A5FA);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFF43F5E);
  static const purple = Color(0xFF7C3AED);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
}

class _FeedStatusDot extends StatelessWidget {
  const _FeedStatusDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

class _FeedGlassCard extends StatelessWidget {
  const _FeedGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.tintColor,
    this.dark = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tintColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      const Color(0xFF1E293B).withValues(alpha: .94),
                      const Color(0xFF111C2B).withValues(alpha: .96),
                      const Color(0xFF08111E).withValues(alpha: .98),
                    ]
                  : [
                      (tintColor ?? const Color(0xFFD7E0EB)).withValues(
                        alpha: tintColor == null ? .18 : .34,
                      ),
                      (tintColor ?? const Color(0xFF7088AD)).withValues(
                        alpha: tintColor == null ? .15 : .2,
                      ),
                      const Color(0xFF16243A).withValues(alpha: .76),
                    ],
              stops: const [0, .42, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FeedSquareIcon extends StatelessWidget {
  const _FeedSquareIcon({
    required this.icon,
    required this.color,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
  }
}

class _FeedSquareButton extends StatelessWidget {
  const _FeedSquareButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * .5),
        ),
      ),
    );
  }
}

class _FeedBottomBar extends StatelessWidget {
  const _FeedBottomBar({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.location_on_outlined, 'Tracking'),
    (Icons.videocam_outlined, 'Live Feed'),
    (Icons.notifications_none_rounded, 'Alerts'),
    (Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            8,
            9,
            8,
            max(10, MediaQuery.paddingOf(context).bottom),
          ),
          decoration: BoxDecoration(
            color: const Color(0xED0A111C),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: .09)),
            ),
          ),
          child: Row(
            children: List.generate(_items.length, (index) {
              final selected = index == currentIndex;
              final item = _items[index];
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      height: 56,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            top: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.transparent
                                    : const Color(0xFF050A12),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: selected
                                    ? null
                                    : const [
                                        BoxShadow(
                                          color: Colors.black,
                                          blurRadius: 7,
                                          offset: Offset(0, -2),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            left: selected ? 2 : 5,
                            right: selected ? 2 : 5,
                            top: selected ? -3 : 8,
                            bottom: selected ? 8 : 3,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF60A5FA),
                                          Color(0xFF2563EB),
                                        ],
                                      )
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF101A29),
                                          Color(0xFF080F1A),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.$1,
                                    size: 20,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF66758A),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : const Color(0xFF66758A),
                                      fontSize: 8,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
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
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _FeedBackground extends StatelessWidget {
  const _FeedBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 24, 28, 33),
                  Color.fromARGB(255, 46, 56, 69),
                  Color(0xFF172131),
                ],
                stops: [0, .52, 1],
              ),
            ),
          ),
          ClipPath(
            clipper: _FeedBlueClipper(),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromARGB(255, 24, 28, 33),
                    Color.fromARGB(255, 48, 54, 65),
                    Color.fromARGB(255, 123, 131, 143),
                  ],
                  stops: [0, .5, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedBlueClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * .62, 0)
      ..lineTo(size.width * .36, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class CameraFeedScreen extends StatefulWidget {
  final String deviceId;

  const CameraFeedScreen({super.key, required this.deviceId});

  @override
  State<CameraFeedScreen> createState() => _CameraFeedScreenState();
}

class _CameraFeedScreenState extends State<CameraFeedScreen> {
  String? _error;

  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  bool _connected = false;
  bool _joining = false;

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
      final roomRef = FirebaseFirestore.instance
          .collection('streamRooms')
          .doc(roomId);

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
          {'urls': 'stun:stun.relay.metered.ca:80'},
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
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
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

      final filteredOffer = RTCSessionDescription(filteredSdp, offer.type);

      await _peerConnection!.setLocalDescription(filteredOffer);

      await roomRef.set({
        'streamRequested': true,
        'offer': {'type': filteredOffer.type, 'sdp': filteredOffer.sdp},
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

  Widget _streamOffView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _FeedGlassCard(
          tintColor: _FeedColors.red,
          padding: const EdgeInsets.all(26),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FeedSquareIcon(
                icon: Icons.videocam_off_rounded,
                color: _FeedColors.red,
                size: 58,
              ),
              SizedBox(height: 16),
              Text(
                'Live Stream Is Off',
                style: TextStyle(
                  color: _FeedColors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'The user has not started the live camera stream.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _FeedColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _FeedGlassCard(
          tintColor: _FeedColors.red,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FeedSquareIcon(
                icon: Icons.error_outline_rounded,
                color: _FeedColors.red,
                size: 58,
              ),
              const SizedBox(height: 16),
              const Text(
                'Stream Unavailable',
                style: TextStyle(
                  color: _FeedColors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unable to load camera stream.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _FeedColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraView(String roomId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black,
                child: _connected
                    ? RTCVideoView(
                        _remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_joining)
                              const CircularProgressIndicator(
                                color: _FeedColors.lightBlue,
                              )
                            else
                              const _FeedSquareIcon(
                                icon: Icons.videocam_outlined,
                                color: _FeedColors.purple,
                                size: 56,
                              ),
                            const SizedBox(height: 14),
                            Text(
                              _joining
                                  ? 'Connecting to stream...'
                                  : 'Tap refresh to open stream',
                              style: const TextStyle(
                                color: _FeedColors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: _FeedGlassCard(
                dark: true,
                borderRadius: 18,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const _FeedSquareIcon(
                      icon: Icons.videocam_rounded,
                      color: _FeedColors.purple,
                      size: 42,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Camera',
                            style: TextStyle(
                              color: _FeedColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _online
                                      ? _FeedColors.green
                                      : _FeedColors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _online ? 'Device online' : 'Device offline',
                                style: const TextStyle(
                                  color: _FeedColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _FeedSquareButton(
                      icon: Icons.refresh_rounded,
                      color: _FeedColors.blue,
                      onTap: () => _joinWebRtcStream(roomId),
                      size: 40,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: _FeedGlassCard(
                dark: true,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    _FeedStatusDot(
                      label: _connected ? 'LIVE' : 'WAITING',
                      color: _connected ? _FeedColors.red : _FeedColors.muted,
                    ),
                    const Spacer(),
                    Text(
                      _connected ? 'Stream connected' : 'Camera standby',
                      style: const TextStyle(
                        color: _FeedColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openScreen(Widget screen) async {
    await _closeConnection();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _selectBottomTab(int index) {
    switch (index) {
      case 0:
        _openScreen(HomeScreen(deviceId: widget.deviceId));
      case 1:
        _openScreen(LiveTrackingScreen(deviceId: widget.deviceId));
      case 3:
        _openScreen(AlertHistoryScreen(deviceId: widget.deviceId));
      case 4:
        _openScreen(SettingsScreen(deviceId: widget.deviceId));
    }
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
      backgroundColor: _FeedColors.background,
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _FeedBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: roomRef.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        _error = snapshot.error.toString();
                        return _errorView();
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: _FeedColors.lightBlue,
                          ),
                        );
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
                        if (_connected) _closeConnection();
                        return _streamOffView();
                      }
                      if (_error != null) return _errorView();
                      return _cameraView(streamRoomId);
                    },
                  ),
                ),
                const SizedBox(height: 102),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FeedBottomBar(
        currentIndex: 2,
        onSelected: _selectBottomTab,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _FeedSquareButton(
            icon: Icons.arrow_back_rounded,
            color: const Color(0xFF475569),
            onTap: () async {
              await _closeConnection();
              if (mounted) Navigator.pop(context);
            },
          ),
          const Expanded(
            child: Column(
              children: [
                Text(
                  'PATHFINDER',
                  style: TextStyle(
                    color: _FeedColors.lightBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Live Feed',
                  style: TextStyle(
                    color: _FeedColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
