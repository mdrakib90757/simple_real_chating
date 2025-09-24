import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AudioCallController extends GetxController {
  final String channelId;
  AudioCallController(this.channelId);

  late RtcEngine engine;
  RxInt remoteUid = 0.obs;
  RxBool localJoined = false.obs;
  RxBool mutedAudio = false.obs;

  // Replace with your App ID & temporary token
  final String appId = "c0aec9eab38544cf92e70a498c4f2a61";
  final String token = "007eJxTYKgwE6141N2gaSnM0blgcaSz6+OXe7JEDUW/bRRnWeyyeakCQ7JBYmqyZWpikrGFqYlJcpqlUaq5QaKJpUWySZpRopmh+q5LGQ2BjAw5uhmsjAwQCOLzMhSlJubEJ2cklsQnFhQwMAAA09UhHA==";

  @override
  void onInit() {
    super.onInit();
    initialize();
  }

  @override
  void onClose() {
    leaveChannel();
    super.onClose();
  }

  Future<void> initialize() async {
    engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));

    await engine.disableVideo(); // Audio only
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          localJoined.value = true;
        },
        onUserJoined: (connection, uid, elapsed) {
          remoteUid.value = uid;
        },
        onUserOffline: (connection, uid, reason) {
          remoteUid.value = 0;
        },
      ),
    );

    await engine.joinChannel(
      token: token,
      channelId: channelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void toggleMuteAudio() {
    mutedAudio.value = !mutedAudio.value;
    engine.muteLocalAudioStream(mutedAudio.value);
  }

  void leaveChannel() async {
    await engine.leaveChannel();
    await engine.release();
  }
}
