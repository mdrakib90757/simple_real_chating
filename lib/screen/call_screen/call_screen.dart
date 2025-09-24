import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../utils/setting/setting.dart'; // Make sure this path is correct

class CallPage extends StatelessWidget {
  final String callerID;
  final String callerName;
  final String calleeID;
  final bool isAudioCall;
  final String callID; // Add this

  const CallPage({
    super.key,
    required this.callerID,
    required this.callerName,
    required this.calleeID,
    this.isAudioCall = false,
    required this.callID, // Require callID
  });

  @override
  Widget build(BuildContext context) {
    final config = isAudioCall
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    return ZegoUIKitPrebuiltCall(
      appID: ZegoConfig.appID,
      appSign: ZegoConfig.appSign,
      userID: callerID,
      userName: callerName,
      callID: callID,
      config: config,
    );
  }
}
