import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_app/widgets/audio_controller/audio_controller.dart';

class AudioCallPage extends StatefulWidget {
  final String channelName;
  const AudioCallPage({Key? key, required this.channelName}) : super(key: key);

  @override
  State<AudioCallPage> createState() => _AudioCallPageState();
}

class _AudioCallPageState extends State<AudioCallPage> {
  late AudioCallController callCon;

  @override
  void initState() {
    super.initState();
    callCon = Get.put(AudioCallController(widget.channelName));
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    await [Permission.microphone].request();
  }

  @override
  void dispose() {
    callCon.leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Audio Call"),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Obx(() {
          if (callCon.remoteUid.value != 0) {
            return const Text(
              "Connected",
              style: TextStyle(color: Colors.white, fontSize: 24),
            );
          } else {
            return const Text(
              "Waiting for remote user...",
              style: TextStyle(color: Colors.white, fontSize: 18),
            );
          }
        }),
      ),
      bottomNavigationBar: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Obx(() => IconButton(
              icon: Icon(
                  callCon.mutedAudio.value ? Icons.mic_off : Icons.mic,
                  color: Colors.white),
              onPressed: callCon.toggleMuteAudio,
            )),
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: () {
                callCon.leaveChannel();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
