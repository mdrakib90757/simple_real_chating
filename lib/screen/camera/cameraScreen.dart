import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:web_socket_app/utils/color.dart';
import 'dart:io';
import '../../main.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isRecording = false;
  bool _isFlashOn = false;
  int _selectedCameraIdx = 0;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      _initializeCamera(_selectedCameraIdx);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No camera available.')));
        Navigator.pop(context);
      });
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    if (cameraIndex < 0 || cameraIndex >= cameras.length) {
      print('Invalid camera index: $cameraIndex');
      _controller = null;
      _initializeControllerFuture = null;
      if (mounted) setState(() {});
      return;
    }

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: true,
    );

    _initializeControllerFuture = _controller!.initialize().then((_) async {
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
      return null;
    }).catchError((error) {
      print(': $error');
      _controller = null;
      _initializeControllerFuture = null;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization error')),
        );
      }
    });

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('don`t ready camera')));
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = join((await getTemporaryDirectory()).path, '$timestamp.png');

      XFile picture = await _controller!.takePicture();
      await picture.saveTo(path);
      //  Navigator.pop(context, path);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Photo taken: $path')));

      // Open DisplayPictureScreen and wait for the user to tap Send
      final sentImagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => DisplayPictureScreen(
            imagePath: path,
            onSend: (imagePath) {
              // Pop DisplayPictureScreen and return imagePath to CameraScreen
              Navigator.pop(context, imagePath);
            },
          ),
        ),
      );

      // If user sent the image, pop CameraScreen and return the path to ChatScreen
      if (sentImagePath != null) {
        Navigator.pop(context, sentImagePath);
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed to photo: $e')));
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('don`t ready camera')));
      return;
    }
    if (_controller!.value.isRecordingVideo) return;

    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('start recoding video')));
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed to recoding video $e')));
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No video is being recorded.')));
      return;
    }

    try {
      XFile videoFile = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = join((await getTemporaryDirectory()).path, '$timestamp.mp4');
      await videoFile.saveTo(path);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('recoding video: $path')));
      Navigator.pop(context, path);
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('failed to recoding  $e')));
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  void _switchCamera() async {
    if (cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Multiple cameras are not available.')),
      );
      return;
    }
    setState(() {
      _selectedCameraIdx = (_selectedCameraIdx + 1) % cameras.length;
    });
    await _initializeCamera(_selectedCameraIdx);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializeControllerFuture == null || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.close, color: Colors.white),
          ),
          centerTitle: true,
          title: Text('camera'),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColor.primaryColor),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.close, color: Colors.white),
        ),
        backgroundColor: AppColor.primaryColor,
        title: Text('camera', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
          if (cameras.length > 1)
            IconButton(
              icon: Icon(Icons.flip_camera_ios),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (_controller == null || !_controller!.value.isInitialized) {
              return Center(child: Text('Failed to initialize camera.'));
            }

            final size = MediaQuery.of(context).size;
            final previewAspectRatio = _controller!.value.aspectRatio;
            final screenAspectRatio = size.width / size.height;

            double scale = screenAspectRatio < previewAspectRatio
                ? previewAspectRatio / screenAspectRatio
                : screenAspectRatio / previewAspectRatio;

            return Stack(
              children: [
                Center(
                  child: Transform.scale(
                    scale: scale,
                    child: CameraPreview(_controller!),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.black54,
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          iconSize: 40,
                          icon: Icon(Icons.photo_camera, color: Colors.white),
                          onPressed: _takePicture,
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: Icon(
                            _isRecording ? Icons.stop : Icons.videocam,
                            color: _isRecording ? Colors.red : Colors.white,
                          ),
                          onPressed: _isRecording
                              ? _stopVideoRecording
                              : _startVideoRecording,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(
              child: CircularProgressIndicator(
                color: AppColor.primaryColor,
                strokeWidth: 2.5,
              ),
            );
          }
        },
      ),
    );
  }
}

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  final Function(String)? onSend;

  const DisplayPictureScreen({Key? key, required this.imagePath, this.onSend})
      : super(key: key);

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.primaryColor,
        centerTitle: true,
        title: Text('photo', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Image.file(File(widget.imagePath)),
          SizedBox(height: 15),
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColor.primaryColor,
            child: IconButton(
              onPressed: () async {
                if (widget.onSend != null) {
                  await widget.onSend!(widget.imagePath);
                }
                //Navigator.pop(context);
              },
              icon: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

///video screen
class DisplayVideoScreen extends StatefulWidget {
  final String videoPath;
  final Function(String)? onSend;
  const DisplayVideoScreen({Key? key, required this.videoPath, this.onSend})
      : super(key: key);

  @override
  _DisplayVideoScreenState createState() => _DisplayVideoScreenState();
}

class _DisplayVideoScreenState extends State<DisplayVideoScreen> {
  late VideoPlayerController _controller;

  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    if (widget.videoPath.startsWith("http")) {
      _controller = VideoPlayerController.network(widget.videoPath);
    } else {
      _controller = VideoPlayerController.file(File(widget.videoPath));
    }

    _initializeVideoPlayerFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      return null;
    });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.primaryColor,
        centerTitle: true,
        title: Text('video', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder(
        future: _initializeVideoPlayerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.blue,
                    bufferedColor: Colors.grey,
                    backgroundColor: Colors.black26,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                ),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColor.primaryColor,
                  child: IconButton(
                    onPressed: () async {
                      if (widget.onSend != null) {
                        await widget.onSend!(widget.videoPath);
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            );
          } else {
            return Center(
              child: CircularProgressIndicator(
                color: AppColor.primaryColor,
                strokeWidth: 2.5,
              ),
            );
          }
        },
      ),
    );
  }
}
