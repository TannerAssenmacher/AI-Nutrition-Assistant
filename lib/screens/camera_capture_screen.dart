import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera detected on this device.';
        });
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
    } on CameraException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to initialize the camera.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to initialize the camera.';
      });
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
      } catch (_) {
        // Ignore disposal errors.
      }
    }

    if (updateState && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController(updateState: false);
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

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(picture);
    } on CameraException catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to capture photo. Please try again.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to capture photo. Please try again.')),
      );
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCapturing = false;
      });
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
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Icon(Icons.camera_alt, color: Colors.black),
      ),
    );
  }
}
