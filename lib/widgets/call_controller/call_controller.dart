import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/screen/incoming_call_screen/incoming_call_screen.dart';

final String appId = "c0aec9eab38544cf92e70a498c4f2a61";
final String token = "007eJxTYKgwE6141N2gaSnM0blgcaSz6+OXe7JEDUW/bRRnWeyyeakCQ7JBYmqyZWpikrGFqYlJcpqlUaq5QaKJpUWySZpRopmh+q5LGQ2BjAw5uhmsjAwQCOLzMhSlJubEJ2cklsQnFhQwMAAA09UhHA==";

// class CallController extends GetxController {
//   late RtcEngine engine;
//
//   RxBool localJoined = false.obs;
//   RxInt remoteUid = 0.obs;
//   RxBool mutedAudio = false.obs;
//   RxBool mutedVideo = false.obs;
//
//   final String channelName;
//
//   CallController(this.channelName);
//
//   @override
//   void onInit() {
//     super.onInit();
//     initAgora();
//   }
//
//   Future<void> initAgora() async {
//     engine = createAgoraRtcEngine();
//     await engine.initialize(RtcEngineContext(appId: AGORA_APP_ID));
//
//     engine.registerEventHandler(RtcEngineEventHandler(
//       onJoinChannelSuccess: (connection, elapsed) {
//         print("Local user joined channel");
//         localJoined.value = true;
//       },
//       onUserJoined: (connection, uid, elapsed) {
//         print("Remote user joined: $uid");
//         remoteUid.value = uid;
//       },
//       onUserOffline: (connection, uid, reason) {
//         print("Remote user left: $uid");
//         if (remoteUid.value == uid) remoteUid.value = 0;
//       },
//     ));
//
//     await engine.enableVideo();
//     await joinChannel();
//   }
//
//   Future<void> joinChannel() async {
//     await engine.joinChannel(
//       token: token,
//       channelId: channelName,
//       uid: 0,
//       options: const ChannelMediaOptions(),
//     );
//   }
//
//   Future<void> leaveChannel() async {
//     await engine.leaveChannel();
//     await engine.release();
//     localJoined.value = false;
//     remoteUid.value = 0;
//   }
//
//   void toggleMuteAudio() {
//     mutedAudio.value = !mutedAudio.value;
//     engine.muteLocalAudioStream(mutedAudio.value);
//   }
//
//   void toggleMuteVideo() {
//     mutedVideo.value = !mutedVideo.value;
//     engine.enableLocalVideo(!mutedVideo.value);
//   }
//
//   void switchCamera() {
//     engine.switchCamera();
//   }
// }
//




class CallController extends GetxController {
  final RxInt remoteUid = 0.obs;   // ✅ observable int
  final RxBool localJoined = false.obs; // ✅ observable bool

  late RtcEngine engine;
  final String appId = "c0aec9eab38544cf92e70a498c4f2a61";

  Future<void> initAgora(String token, String channelName) async {
    engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));

    // disable video if audio call
    await engine.disableVideo();
    engine.registerEventHandler(
      RtcEngineEventHandler(
        // Local user joined channel
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("Local joined channel: ${connection.channelId} with uid: ${connection.localUid}");
          localJoined.value = true;
          print("Local joined: ${localJoined.value}");
          print("Remote UID: ${remoteUid.value}");
        },

        // Remote user joined
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          print("Remote user joined: $uid");
          remoteUid.value = uid;   // use class RxInt
          print("Local joined: ${localJoined.value}");
          print("Remote UID: ${remoteUid.value}");
        },
        // Remote user left
        onUserOffline: (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          print("Remote user left: $uid");
          remoteUid.value = 0;  // reset class RxInt
          print("Local joined: ${localJoined.value}");
          print("Remote UID: ${remoteUid.value}");
        },
      ),
    );


    // Join channel
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: ChannelMediaOptions(),
    );
  }

  @override
  void onClose() {
    engine.leaveChannel();
    engine.release();
    super.onClose();
  }
}























