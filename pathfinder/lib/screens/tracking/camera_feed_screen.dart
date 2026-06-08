import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/firestore_service.dart';

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
  bool _loading = true;
  String? _error;
  WebViewController? _controller;
  String _userName = 'Unknown';
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _loadCameraUrl();
  }

  Future<void> _loadCameraUrl() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deviceData =
          await FirestoreService().getDeviceData(widget.deviceId);

      if (deviceData == null) {
        throw Exception("Device not found");
      }

      final url = deviceData['cameraStreamUrl']?.toString();

      if (url == null || url.isEmpty) {
        throw Exception("No camera stream URL found for this device");
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _error = "Failed to load stream: ${error.description}";
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(url));

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _userName = (deviceData['userName'] ?? 'Unknown').toString();
        _online = deviceData['online'] == true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reloadStream() async {
    if (_controller != null) {
      await _controller!.reload();
    } else {
      await _loadCameraUrl();
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

  Widget _cameraView() {
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
                    child: _controller == null
                        ? const Center(
                            child: Text(
                              'No stream available',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : WebViewWidget(controller: _controller!),
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
                            onPressed: _reloadStream,
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
  Widget build(BuildContext context) {
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
                    onTap: () => Navigator.pop(context),
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorView()
                      : _cameraView(),
            ),
          ],
        ),
      ),
    );
  }
}
