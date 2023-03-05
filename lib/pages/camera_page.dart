import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_labelling/pages/preview_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../constant/constants.dart';
import 'gallery_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  CameraImage? _cameraImage;
  bool _isCameraInitialized = false;
  BarcodeScanner? barcodeScanner;
  List<DetectedObject> detectedObjects = [];
  String labelle = '';
  String output = '';
  bool _isRearCameraSelected = true;
  double _currentZoomLevel = 1.0;
  double _maxAvailableZoom = 1.0;
  final double aspectRatio = 4 / 3;
  String _currentResolutionPreset = 'High';
  ResolutionPreset currentResolutionPreset = ResolutionPreset.high;
  FlashMode? _currentFlashMode;
  List<DetectedObject>? objects;
  VideoPlayerController? videoController;
  File? _imageFile;
  bool startStream = false;
  bool autoFocus = false;
  int currPosIcon = -1;
  int currPosRes = -1;
  Rect currentZoomRect = Rect.zero;
  bool isDetectingObjects = false;
  Size previewSize = Size.zero;
  bool isZooming = false;
  int frame = 0;
  int times = 1;
  List<File> allFileList = [];
  double ratio = 1.1;
  Icon exposeIcon = const Icon(Icons.exposure_zero);
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<String> _imagePaths = [];

  @override
  void initState() {
    initCamera(cameras[0]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor:
            Colors.transparent, // Set status bar color to transparent
        statusBarIconBrightness:
            Brightness.dark, // Set status bar icons' color to dark
      ),
    );
    refreshCapturedImages();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    super.initState();
  }

  @override
  void dispose() {
    _cameraController!.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      initCamera(_cameraController!.description);
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (_cameraController == null) {
      return;
    }
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    _cameraController!.setExposurePoint(offset);
    _cameraController!.setFocusPoint(offset);
  }

  initCamera(CameraDescription cameraDescription) async {
    final previousCameraController = _cameraController;

    final CameraController _controller = CameraController(
      cameraDescription,
      currentResolutionPreset,
    );

    await previousCameraController?.dispose();

    if (mounted) {
      setState(() {
        _cameraController = _controller;
      });
    }

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      _cameraController!
          .getMaxZoomLevel()
          .then((value) => _maxAvailableZoom = value);

      setState(() {
        _isCameraInitialized = _controller.value.isInitialized;
        _currentFlashMode = _controller.value.flashMode;
      });

      _controller.setExposureOffset(0);
    });
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  void startImageStream() {
    if (startStream) {
      _cameraController!.startImageStream((imageFromStream) {
        frame++;
        if (frame % 30 == 0 && startStream) {
          frame = 0;
          if (!isDetectingObjects) {
            isDetectingObjects = true;
            _cameraImage = imageFromStream;
            detectObjectOnCamera();
            if (objects!.isNotEmpty) {
              startStream = false;
            }
            isDetectingObjects = false;
          }
        } else if (!startStream) {
          _cameraController!.stopImageStream();
        }
      });
    } else {
      _cameraController!.stopImageStream();
    }
  }

  void detectObjectOnCamera() async {
    final inputImage = InputImage.fromBytes(
      bytes: _concatenatePlanes(_cameraImage!.planes),
      inputImageData: InputImageData(
        planeData: _cameraImage!.planes.map(
          (Plane plane) {
            return InputImagePlaneMetadata(
              bytesPerRow: plane.bytesPerRow,
              height: plane.height,
              width: plane.width,
            );
          },
        ).toList(),
        inputImageFormat: InputImageFormat.yuv420,
        size: Size(
            _cameraImage!.width.toDouble(), _cameraImage!.height.toDouble()),
        imageRotation: InputImageRotation.rotation90deg,
      ),
    );
    final objectDetector = GoogleMlKit.vision.objectDetector(
        options: ObjectDetectorOptions(
            mode: DetectionMode.single,
            classifyObjects: true,
            multipleObjects: true));

    objects = await objectDetector.processImage(inputImage);

    if (objects!.isNotEmpty) {
      setState(() {
        output = "Object detected";
        detectedObjects = objects!;
        isDetectingObjects = false;
        final boundingBox = objects!.first.boundingBox;
        zoomToDetectedObject(boundingBox);
        startStream = false;
      });
    } else {
      await _cameraController!.setZoomLevel(1.0);
      setState(() {
        output = "No Object detected";
        isDetectingObjects = false;
        _currentZoomLevel = 1.0;
        startStream = true;
      });
    }
  }

  void zoomToDetectedObject(Rect boundingBox) async {
    double objectHeight = boundingBox.height;
    double objectWidth = boundingBox.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    double scaleY = objectHeight / screenHeight * screenHeight;
    double scaleX = objectWidth / screenWidth * screenWidth;

    double scale = max(scaleY, scaleX);
    scale = min(scale * 0.7, 2.0);

    double minZoom = await _cameraController!.getMinZoomLevel();
    double maxZoom = await _cameraController!.getMaxZoomLevel();
    double currentZoom = _currentZoomLevel;
    double newZoom = scale * currentZoom;

    if (currentZoom != newZoom) {
      final _animationController = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      final _zoomTween = Tween<double>(
          begin: currentZoom, end: min(max(newZoom, minZoom), maxZoom));
      _animationController.forward();
      _animationController.addListener(() async {
        double newZoom = _zoomTween.evaluate(_animationController);
        await _cameraController!.setZoomLevel(newZoom);
        setState(() {
          _currentZoomLevel = newZoom;
        });
      });
    }
  }

  Future takePicture() async {
    if (!_cameraController!.value.isInitialized) {
      return null;
    }
    if (_cameraController!.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController!.setFlashMode(FlashMode.off);
      final rawImage = await _cameraController!.takePicture();
      File imageFile = File(rawImage.path);

      try {
        // final String timestamp =
        //     DateTime.now().millisecondsSinceEpoch.toString();
        final Directory? directory = await getExternalStorageDirectory();
        String fileFormat = imageFile.path.split('.').last;
        int currentUnix = DateTime.now().millisecondsSinceEpoch;

        final path = '${directory!.path}/$currentUnix.$fileFormat';

        print(path);

        await rawImage.saveTo(path);

        refreshCapturedImages();
        _cameraController!.setZoomLevel(1.0);
        print('Picture is saved');
      } catch (e) {
        print("Image not saved");
      }

      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PreviewPage(
                    picture: rawImage,
                  )));
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  refreshCapturedImages() async {
    final directory = await getExternalStorageDirectory();
    List<FileSystemEntity> fileList = await directory!.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];

    for (var file in fileList) {
      if (file.path.contains('.jpg')) {
        _imagePaths.add(file.path);
      }

      if (file.path.contains('.jpg') || file.path.contains('.mp4')) {
        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    }

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      _imageFile = File('${directory.path}/$recentFileName');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
            child: _isCameraInitialized
                ? Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                                top: 10, left: 10, right: 10),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20)),
                            height: MediaQuery.of(context).size.height * 0.77,
                            width: double.infinity,
                            child: CameraPreview(
                              _cameraController!,
                              child: LayoutBuilder(builder:
                                  (BuildContext context,
                                      BoxConstraints constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (details) =>
                                      onViewFinderTap(details, constraints),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isCameraInitialized = false;
                                  });
                                  initCamera(
                                    cameras[_isRearCameraSelected ? 1 : 0],
                                  );
                                  setState(() {
                                    _isRearCameraSelected =
                                        !_isRearCameraSelected;
                                  });
                                },
                                icon: const Icon(Icons.switch_camera_outlined)),
                            IconButton(
                                onPressed: () async {
                                  setState(() {
                                    if (_currentFlashMode == FlashMode.off ||
                                        _currentFlashMode == FlashMode.auto) {
                                      _currentFlashMode = FlashMode.torch;
                                    } else if (_currentFlashMode ==
                                        FlashMode.torch) {
                                      _currentFlashMode = FlashMode.off;
                                    }
                                  });

                                  await _cameraController!
                                      .setFlashMode(_currentFlashMode!);
                                },
                                icon: const Icon(Icons.flash_off)),
                            IconButton(
                                onPressed: () {
                                  var ele =
                                      icons[(currPosIcon + 1) % icons.length];
                                  setState(() {
                                    exposeIcon = ele[1];
                                    currPosIcon = currPosIcon + 1;
                                  });
                                  _cameraController!.setExposureOffset(ele[0]);
                                },
                                icon: exposeIcon),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  autoFocus = !autoFocus;
                                  startStream = true;
                                  startImageStream();
                                });
                              },
                              icon: Icon(
                                autoFocus && startStream
                                    ? Icons.center_focus_strong_rounded
                                    : Icons.center_focus_strong_outlined,
                                color: autoFocus && startStream
                                    ? Colors.green
                                    : Colors.black,
                              ),
                            ),
                            TextButton(
                                onPressed: () {
                                  var ele = resolutions[
                                      (currPosRes + 1) % resolutions.length];
                                  setState(() {
                                    currentResolutionPreset = ele[0];
                                    _currentResolutionPreset = ele[1];
                                    currPosRes = currPosRes + 1;
                                    _isCameraInitialized = false;
                                  });
                                  initCamera(_cameraController!.description);
                                },
                                child: Text(
                                  _currentResolutionPreset,
                                  style: const TextStyle(
                                      fontSize: 17, color: Colors.blue),
                                )),
                          ],
                        ),
                      ),
                      SizedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() {
                                  _currentZoomLevel = _currentZoomLevel - 1;
                                  if (_currentZoomLevel < 1) {
                                    _currentZoomLevel = 1;
                                  }
                                  _cameraController!
                                      .setZoomLevel(_currentZoomLevel);
                                });
                                _animationController.reset();
                                _animationController.forward();
                              },
                              onDoubleTap: () {
                                setState(() {
                                  _currentZoomLevel = _currentZoomLevel + 1;
                                  if (_currentZoomLevel > _maxAvailableZoom) {
                                    _currentZoomLevel = 1;
                                  }
                                  _cameraController!
                                      .setZoomLevel(_currentZoomLevel);
                                });
                                _animationController.reset();
                                _animationController.forward();
                              },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                height: 60,
                                width: 60,
                                child: AnimatedBuilder(
                                  animation: _animation,
                                  builder:
                                      (BuildContext context, Widget? child) {
                                    return Transform.scale(
                                      scale: _animation.value * 0.2 + 1,
                                      child: Text(
                                        _currentZoomLevel.toInt().toString() +
                                            "x",
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                takePicture();
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: const [
                                  Icon(
                                    Icons.circle,
                                    color: Color.fromARGB(65, 0, 0, 0),
                                    size: 90,
                                  ),
                                  Icon(
                                    Icons.circle,
                                    color: Colors.black,
                                    size: 75,
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => GalleryPage(
                                            imagePaths: _imagePaths)));
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10.0),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  image: _imageFile != null
                                      ? DecorationImage(
                                          image: FileImage(_imageFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: Container(),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator())),
      ),
    );
  }
}