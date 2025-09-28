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
  final uuid = Uuid().v4();

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

  await FlutterCallkitIncoming.showCallkitIncoming(params);
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

  CallKitParams params = CallKitParams(
    id: uuid,
    nameCaller: callerName,
    handle: callerEmail,
    type: isAudio ? 0 : 1,
    android: const AndroidParams(isCustomNotification: true),
  );

  await FlutterCallkitIncoming.startCall(params);

  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;
    final extra = event.body?['extra'] ?? {};

    switch (event.event) {
      case Event.actionCallAccept:
        Navigator.push(
          navigatorKey.currentState!.context,
          MaterialPageRoute(
            builder: (_) => CallPage(
              callerID: callerID,
              callerName: callerName,
              calleeID: calleeID,
              callID: callID,
              isAudioCall: isAudio,
              isCaller: true,
            ),
          ),
        );
        break;

      case Event.actionCallDecline:
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(extra['callID'])
            .set({'status': 'ended'}, SetOptions(merge: true));
        break;

      default:
        break;
    }
  });
}

