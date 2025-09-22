import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../utils/color.dart';

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
