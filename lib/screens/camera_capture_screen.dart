import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MealCaptureResult {
  final XFile photo;
  final String? userContext;
  final String? imageUrl; // URL to the uploaded image in Firebase Storage

  const MealCaptureResult({
    required this.photo,
    this.userContext,
    this.imageUrl,
  });
}

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCapturing = false;
  String? _errorMessage;
  final TextEditingController _contextController = TextEditingController();
  bool _isContextVisible = false;
  static const int _maxContextLength = 500;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _disposeController(updateState: false);
        break;
      case AppLifecycleState.resumed:
        _initializeCamera();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() => _errorMessage = null);

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera detected on this device.');
        return;
      }

      await _disposeController(updateState: false);

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      final initFuture = controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializeControllerFuture = initFuture;
      });

      await initFuture;
      
      // Trigger rebuild after initialization completes
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to initialize the camera.');
    }
  }

  Future<void> _disposeController({bool updateState = true}) async {
    final controller = _controller;
    _controller = null;
    _initializeControllerFuture = null;
    _isCapturing = false;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }

    if (updateState && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController(updateState: false);
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    final initFuture = _initializeControllerFuture;

    if (controller == null || initFuture == null || _isCapturing) return;

    try {
      setState(() => _isCapturing = true);

      await initFuture;
      final picture = await controller.takePicture();

      if (!mounted) return;

      final contextNote = _contextController.text.trim();

      Navigator.of(context).pop(
        MealCaptureResult(
          photo: picture,
          userContext: contextNote.isEmpty ? null : contextNote,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to capture photo. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _toggleContextPanel() {
    if (_isContextVisible) {
      // Dismiss keyboard when closing
      FocusScope.of(context).unfocus();
    }
    setState(() => _isContextVisible = !_isContextVisible);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initFuture = _initializeControllerFuture;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _errorMessage != null
            ? _buildErrorState()
            : (controller == null || initFuture == null)
                ? _buildLoadingState()
                : FutureBuilder<void>(
                    future: initFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          controller.value.isInitialized) {
                        return _buildCameraView(controller);
                      }
                      if (snapshot.hasError) {
                        return _buildErrorState(
                          message: 'Camera error: ${snapshot.error}',
                        );
                      }
                      return _buildLoadingState();
                    },
                  ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildErrorState({String? message}) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                color: Colors.white.withOpacity(0.5),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message ?? _errorMessage ?? 'An error occurred.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView(CameraController controller) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fullscreen camera preview
        _FullscreenCameraPreview(controller: controller),

        // Top gradient for status bar readability
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom gradient for controls readability
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Back button
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Colors.white,
              iconSize: 22,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),

        // Bottom controls: Capture button + Context toggle/panel
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Context input panel (above buttons when visible)
                  if (_isContextVisible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ContextInputCard(
                        controller: _contextController,
                        maxLength: _maxContextLength,
                        onClose: _toggleContextPanel,
                      ),
                    ),
                  // Button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Spacer to balance the layout
                      const SizedBox(width: 56),
                      const Spacer(),
                      // Capture button (centered)
                      _CaptureButton(
                        isCapturing: _isCapturing,
                        onCapture: _isCapturing ? null : _capturePhoto,
                      ),
                      const Spacer(),
                      // Context toggle button (right side)
                      _ContextToggleButton(
                        isOpen: _isContextVisible,
                        hasContent: _contextController.text.isNotEmpty,
                        onTap: _toggleContextPanel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen camera preview that fills the entire screen edge-to-edge.
/// Uses SizedBox.expand with FittedBox for reliable "cover" behavior.
class _FullscreenCameraPreview extends StatelessWidget {
  final CameraController controller;

  const _FullscreenCameraPreview({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Check if controller is properly initialized
    if (!controller.value.isInitialized) {
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 1,
          height: controller.value.previewSize?.width ?? 1,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _ContextInputCard extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final VoidCallback onClose;

  const _ContextInputCard({
    required this.controller,
    required this.maxLength,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Add meal context',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5CF0C0).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF5CF0C0),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 2,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            cursorColor: const Color(0xFF5CF0C0),
            decoration: InputDecoration(
              hintText: 'e.g., 90/10 ground beef, grilled without oil',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 15,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF5CF0C0),
                  width: 1.5,
                ),
              ),
              counterStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback? onCapture;

  const _CaptureButton({
    required this.isCapturing,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCapturing ? Colors.white.withOpacity(0.5) : Colors.white,
          ),
          child: isCapturing
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _ContextToggleButton extends StatelessWidget {
  final bool isOpen;
  final bool hasContent;
  final VoidCallback onTap;

  const _ContextToggleButton({
    required this.isOpen,
    required this.hasContent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isOpen || hasContent
              ? const Color(0xFF5CF0C0).withOpacity(0.2)
              : Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: isOpen || hasContent
                ? const Color(0xFF5CF0C0).withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          isOpen ? Icons.close_rounded : Icons.sticky_note_2_outlined,
          color: isOpen || hasContent
              ? const Color(0xFF5CF0C0)
              : Colors.white.withOpacity(0.9),
          size: 24,
        ),
      ),
    );
  }
}