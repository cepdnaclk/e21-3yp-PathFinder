import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'web_link_device_page.dart';
import 'widgets/web_auth_layout.dart';
import 'widgets/web_page_route.dart';

class WebQrScannerPage extends StatefulWidget {
  const WebQrScannerPage({super.key});

  @override
  State<WebQrScannerPage> createState() => _WebQrScannerPageState();
}

class _WebQrScannerPageState extends State<WebQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _cameraStarted = false;
  bool _startingCamera = false;
  bool _scanned = false;
  String? _cameraError;

  Future<void> _startCamera() async {
    setState(() {
      _startingCamera = true;
      _cameraError = null;
    });

    try {
      await _controller.start();

      if (!mounted) return;

      setState(() {
        _cameraStarted = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cameraError =
            'Camera permission was denied or the camera could not be opened. Please allow camera access in the browser and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _startingCamera = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;

    if (capture.barcodes.isEmpty) return;

    final value = capture.barcodes.first.rawValue;

    if (value == null || value.trim().isEmpty) return;

    _scanned = true;

    final deviceId = _extractDeviceId(value.trim());

    Navigator.pushReplacement(
      context,
      webFadeRoute(
        WebLinkDevicePage(initialDeviceId: deviceId),
      ),
    );
  }

  String _extractDeviceId(String qrValue) {
    if (qrValue.contains('deviceId')) {
      final match = RegExp(r'"deviceId"\s*:\s*"([^"]+)"').firstMatch(qrValue);
      if (match != null) return match.group(1)!;
    }

    return qrValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebAuthLayout(
      showHeroText: false,
      child: AuthGlassCard(
        maxWidth: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan Device QR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 380,
                width: double.infinity,
                child: !_cameraStarted
                    ? Container(
                        color: Colors.black.withOpacity(0.35),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                  size: 72,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _cameraError ??
                                      'Click the button below to open your camera and scan the PathFinder device QR code.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.78),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed:
                                      _startingCamera ? null : _startCamera,
                                  icon: const Icon(Icons.camera_alt),
                                  label: Text(
                                    _startingCamera
                                        ? 'Opening Camera...'
                                        : 'Start Camera',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C6BFF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                      ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Allow camera permission and scan the QR code on your PathFinder device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}