import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../notification_handle/notificationHandle.dart';
import '../../utils/call_handler/call_handler.dart';
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
    print("🚀 CallPage Started");
    print("callerID(userID in Zego): $callerID");
    print("callerName: $callerName");
    print("calleeID: $calleeID");
    print("callID: $callID");
    print("isAudioCall: $isAudioCall");

    final config = isAudioCall
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();

    // Call end handling
    // config.onHangUp = () {
    //   CallHandler.endCall(context, callID, calleeID);
    // };

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
