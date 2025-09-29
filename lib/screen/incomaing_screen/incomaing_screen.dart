import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:uuid/uuid.dart';
import '../../main.dart';
import '../call_screen/call_screen.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

Future<void> showIncomingCall({
  required String callerName,
  String? callerPhotoUrl,
  required String callerID,
  required String calleeID,
  required bool isAudioCall,
  required String callID,
}) async {

  print("🔔 showIncomingCall() called");
  print("➡️ Params:");
  print("  callerName: $callerName");
  print("  callerID: $callerID");
  print("  calleeID: $calleeID");
  print("  callID: $callID");
  print("  isAudioCall: $isAudioCall");
  print("  callerPhotoUrl: $callerPhotoUrl");

  CallKitParams params = CallKitParams(
    id: callID, // use actual callID
    nameCaller: callerName,
    handle: "callerEmail",
    type: isAudioCall ? 0 : 1,
    duration: 30000,
    extra: {
      "callerID": callerID,
      "calleeID": calleeID,
      "callerPhotoUrl": callerPhotoUrl,
      "isAudioCall": isAudioCall,
      "callID": callID,
    },
    missedCallNotification: NotificationParams(
      showNotification: true,
      isShowCallback: true,
      subtitle: 'Missed call',
      callbackText: 'Call back',
    ),
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      backgroundColor: '#0955fa',
      actionColor: '#4CAF50',
      textColor: '#ffffff',
    ),
  );

  print("📦 Final CallKitParams.extra => ${params.extra}");
  await FlutterCallkitIncoming.showCallkitIncoming(params);
  print("✅ showCallkitIncoming triggered");

}

void startOutgoingCall({
  required String callerName,
  required String callerEmail,
  required String callerID,
  required String calleeID,
  required String callID,
  required bool isAudio,
}) async {
  final uuid = Uuid().v4();

  print("📞 startOutgoingCall() called");
  print("➡️ callerName: $callerName");
  print("➡️ callerEmail: $callerEmail");
  print("➡️ callerID: $callerID");
  print("➡️ calleeID: $calleeID");
  print("➡️ callID: $callID");
  print("➡️ isAudio: $isAudio");
  print("➡️ generated uuid: $uuid");

  CallKitParams params = CallKitParams(
    id: uuid,
    nameCaller: callerName,
    handle: callerEmail,
    type: isAudio ? 0 : 1,
    android: const AndroidParams(isCustomNotification: true),
  );

  print("📦 Final Outgoing CallKitParams.extra => ${params.extra}");

  await FlutterCallkitIncoming.startCall(params);
  print("✅ startCall triggered");


  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;

    final extra = event.body?['extra'] ?? {};
    final callID = extra['callID'] ?? '';
    final callerID = extra['callerID'] ?? '';
    final calleeID = extra['calleeID'] ?? '';
    final callerName = extra['callerName'] ?? '';
    final isAudio = extra['isAudioCall'] ?? true;

    switch (event.event) {
      case Event.actionCallAccept:
        print("✅ Receiver accepted call: $callID");

        // 1️⃣ Update Firestore status
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callID)
            .set({'status': 'accepted'}, SetOptions(merge: true));

        // 2️⃣ Navigate to CallPage
        Navigator.push(
          navigatorKey.currentState!.context,
          MaterialPageRoute(
            builder: (_) => CallPage(
              callerID: callerID,
              callerName: callerName,
              calleeID: calleeID,
              callID: callID,
              isAudioCall: isAudio,
              isCaller: false,
            ),
          ),
        );
        break;

      case Event.actionCallDecline:
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callID)
            .set({'status': 'ended'}, SetOptions(merge: true));
        break;

      case Event.actionCallIncoming:
      // Show incoming call overlay
        showIncomingCall(
          callerName: callerName,
          callerID: callerID,
          calleeID: calleeID,
          callID: callID,
          isAudioCall: isAudio,

        );
        break;

      default:
        break;
    }
  });

}
