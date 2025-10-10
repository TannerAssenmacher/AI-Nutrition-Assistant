import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Camera capture flow that returns the snapped photo to the caller.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera detected on this device.';
        });
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      final initFuture = controller.initialize();

      setState(() {
        _controller = controller;
        _initializeControllerFuture = initFuture;
      });

      await initFuture;
    } catch (_) {
      setState(() {
        _errorMessage = 'Failed to initialize the camera.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    final initFuture = _initializeControllerFuture;
    if (controller == null || initFuture == null || _isCapturing) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
      });

      await initFuture;
      final picture = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(picture);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to capture photo. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initFuture = _initializeControllerFuture;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Meal Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          : (controller == null || initFuture == null)
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<void>(
                  future: initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return CameraPreview(controller);
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Camera error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _capturePhoto,
        backgroundColor: Colors.white,
        child: _isCapturing
            ? const CircularProgressIndicator()
            : const Icon(Icons.camera_alt, color: Colors.black),
      ),
    );
  }
}
