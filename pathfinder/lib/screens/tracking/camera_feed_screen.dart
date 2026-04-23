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
      appBar: AppBar(
        title: const Text("Live Camera Feed"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reloadStream,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _controller == null
                          ? const Center(child: Text("No stream available"))
                          : WebViewWidget(controller: _controller!),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Camera Information",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text("Device ID: ${widget.deviceId}"),
                              const SizedBox(height: 4),
                              Text("Stream URL: $_cameraStreamUrl"),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}