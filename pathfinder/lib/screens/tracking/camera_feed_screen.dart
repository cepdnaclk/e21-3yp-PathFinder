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
  String? _cameraStreamUrl;
  WebViewController? _controller;
  String _userName = 'Unknown';
  bool _online = false;

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _miniStatusCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Color? backgroundColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
        _cameraStreamUrl = url;
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
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _reloadStream() async {
    if (_controller != null) {
      await _controller!.reload();
    } else {
      await _loadCameraUrl();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Live Camera Feed"),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Live Camera"),
                    Container(
                      width: double.infinity,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _controller == null
                          ? const Center(child: Text("No stream available"))
                          : WebViewWidget(controller: _controller!),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle("Overview"),
                    Row(
                      children: [
                        _miniStatusCard(
                          icon: Icons.sensors,
                          label: "Device",
                          value: _online ? "Online" : "Offline",
                          iconColor: _online ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        _miniStatusCard(
                          icon: Icons.videocam,
                          label: "Stream",
                          value: _cameraStreamUrl == null ? "Missing" : "Ready",
                          iconColor: _cameraStreamUrl == null
                              ? Colors.grey
                              : Colors.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _miniStatusCard(
                          icon: Icons.person_pin_circle,
                          label: "Tracked User",
                          value: _userName,
                          iconColor: Colors.deepPurple,
                        ),
                        const SizedBox(width: 12),
                        _miniStatusCard(
                          icon: Icons.devices,
                          label: "Device ID",
                          value: widget.deviceId,
                          iconColor: Colors.teal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Stream URL",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_cameraStreamUrl ?? "Not available"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _reloadStream,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reload Stream"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}