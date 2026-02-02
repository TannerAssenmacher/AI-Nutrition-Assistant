import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

enum CaptureMode { photo, barcode }

class MealCaptureResult {
  final CaptureMode mode;
  final XFile? photo;
  final String? barcode;
  final String? userContext;

  const MealCaptureResult({required this.photo, this.userContext})
      : mode = CaptureMode.photo,
        barcode = null;

  const MealCaptureResult.barcode({required this.barcode, this.photo})
      : mode = CaptureMode.barcode,
        userContext = null;
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CaptureMode _captureMode = CaptureMode.photo;
  
  // Photo mode
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  
  // Barcode mode - we let MobileScanner widget manage itself
  bool _hasDetectedBarcode = false;
  
  // Shared
  bool _isSwitchingMode = false;
  String? _error;
  
  // Context
  final TextEditingController _contextController = TextEditingController();
  bool _showContext = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_captureMode != CaptureMode.photo) return;
    
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _contextController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    
    setState(() {
      _error = null;
      _isCameraInitialized = false;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera found');
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Camera failed to start');
      }
    }
  }

  Future<void> _switchMode() async {
    if (_isSwitchingMode) return;
    
    setState(() => _isSwitchingMode = true);

    if (_captureMode == CaptureMode.photo) {
      // Switch to barcode
      _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
      
      // Small delay for camera release
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() {
          _captureMode = CaptureMode.barcode;
          _hasDetectedBarcode = false;
          _isSwitchingMode = false;
          _error = null;
        });
      }
    } else {
      // Switch to photo
      setState(() {
        _captureMode = CaptureMode.photo;
        _hasDetectedBarcode = false;
        _error = null;
      });
      
      // Small delay then init camera
      await Future.delayed(const Duration(milliseconds: 300));
      await _initCamera();
      
      if (mounted) {
        setState(() => _isSwitchingMode = false);
      }
    }
  }

  Future<void> _takePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      final userContextText = _contextController.text.trim();
      Navigator.of(context).pop(
        MealCaptureResult(
          photo: file,
          userContext: userContextText.isEmpty ? null : userContextText,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to take photo')),
        );
        setState(() => _isCapturing = false);
      }
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!mounted || _hasDetectedBarcode) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _hasDetectedBarcode = true;
        Navigator.of(context).pop(
          MealCaptureResult.barcode(barcode: value),
        );
        return;
      }
    }
  }

  void _onTapFocus(TapDownDetails details, BoxConstraints constraints) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    try {
      controller.setFocusPoint(Offset(x, y));
      controller.setFocusMode(FocusMode.auto);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera/Scanner view
            if (_captureMode == CaptureMode.photo)
              _buildPhotoView()
            else
              _buildBarcodeView(),

            // Overlay for barcode mode
            if (_captureMode == CaptureMode.barcode)
              const _ScannerOverlay(),

            // Top bar
            _buildTopBar(),

            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoView() {
    if (_error != null) {
      return _buildErrorView(_error!);
    }

    final controller = _cameraController;
    if (!_isCameraInitialized || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (d) => _onTapFocus(d, constraints),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarcodeView() {
    // Let MobileScanner manage its own controller
    return MobileScanner(
      fit: BoxFit.cover,
      onDetect: _onBarcodeDetected,
      errorBuilder: (context, error) {
        return _buildErrorView('Scanner error: ${error.errorCode}');
      },
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                if (_captureMode == CaptureMode.photo) {
                  _initCamera();
                } else {
                  setState(() {}); // Trigger rebuild for MobileScanner
                }
              },
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Context panel
                if (_showContext && _captureMode == CaptureMode.photo) ...[
                  _buildContextPanel(),
                  const SizedBox(height: 20),
                ],

                // Mode indicator
                Text(
                  _captureMode == CaptureMode.photo ? 'Photo' : 'Barcode',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Control buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mode toggle
                    _ControlButton(
                      icon: _captureMode == CaptureMode.photo
                          ? Icons.qr_code_scanner
                          : Icons.camera_alt,
                      onTap: _isSwitchingMode ? null : _switchMode,
                      isLoading: _isSwitchingMode,
                    ),

                    // Capture button
                    _CaptureButton(
                      onTap: _captureMode == CaptureMode.photo && _isCameraInitialized && !_isCapturing
                          ? _takePhoto
                          : null,
                      isCapturing: _isCapturing,
                      isEmpty: _captureMode == CaptureMode.barcode,
                    ),

                    // Context toggle (photo only)
                    if (_captureMode == CaptureMode.photo)
                      _ControlButton(
                        icon: _showContext ? Icons.check : Icons.edit_note,
                        onTap: () => setState(() => _showContext = !_showContext),
                        isActive: _showContext || _contextController.text.isNotEmpty,
                      )
                    else
                      const SizedBox(width: 56),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add context',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contextController,
            maxLines: 2,
            maxLength: 500,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'e.g., 200g chicken breast, grilled',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isCapturing;
  final bool isEmpty;

  const _CaptureButton({
    required this.onTap,
    required this.isCapturing,
    required this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isEmpty
                ? Colors.transparent
                : (isCapturing ? Colors.white60 : Colors.white),
          ),
          child: isCapturing
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Clean scanner overlay with corner brackets
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _OverlayPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final boxW = size.width * 0.8;
    final boxH = boxW * 0.55;
    final left = (size.width - boxW) / 2;
    final top = (size.height - boxH) / 2 - 50;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, boxW, boxH),
      const Radius.circular(20),
    );

    // Dark background with cutout
    final bgPaint = Paint()..color = Colors.black54;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, bgPaint);

    // White corner brackets
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const len = 30.0;
    const r = 20.0;
    final l = rect.left;
    final t = rect.top;
    final ri = rect.right;
    final b = rect.bottom;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + len)
        ..lineTo(l, t + r)
        ..quadraticBezierTo(l, t, l + r, t)
        ..lineTo(l + len, t),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(ri - len, t)
        ..lineTo(ri - r, t)
        ..quadraticBezierTo(ri, t, ri, t + r)
        ..lineTo(ri, t + len),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(l, b - len)
        ..lineTo(l, b - r)
        ..quadraticBezierTo(l, b, l + r, b)
        ..lineTo(l + len, b),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(ri - len, b)
        ..lineTo(ri - r, b)
        ..quadraticBezierTo(ri, b, ri, b - r)
        ..lineTo(ri, b - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
