import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../notification_handle/notificationHandle.dart';
import '../../screen/calling_screen/calling_screen.dart';

class CallHandler {
  static Future<void> startCall({
    required BuildContext context,
    required String receiverID,
    required String receiverEmail,
    required bool isAudio,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final participants = [currentUser.uid, receiverID]..sort();
    final callID = "call_${participants.join('_')}";

    // Firestore call document create
    await FirebaseFirestore.instance.collection('calls').doc(callID).set({
      'callerID': currentUser.uid,
      'calleeID': receiverID,
      'status': 'calling', // calling, accepted, ended
      'timestamp': FieldValue.serverTimestamp(),
      'isAudio': isAudio,
    });

    // get receiver FCM token
    final token = await FirebaseFirestore.instance
        .collection("users")
        .doc(receiverID)
        .get()
        .then((doc) => doc.data()?['fcmToken']);

    if (token != null) {
      await NotificationHandler(context).sendCallNotification(
        fcmToken: token,
        title: "Incoming ${isAudio ? 'Audio' : 'Video'} Call",
        body: "From ${currentUser.email ?? currentUser.uid}",
        senderId: currentUser.uid,
        senderEmail: currentUser.email ?? currentUser.uid,
        channelName: callID,
        callType: isAudio ? "audio" : "video",
      );
    }
    final receiverPhotoUrl = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverID)
        .get()
        .then((doc) => doc.data()?['photoUrl'] ?? '');
    // Show CallingScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          receiverPhotoUrl: receiverPhotoUrl,
          callID: callID,
          receiverID: receiverID,
          receiverEmail: receiverEmail,
          isAudioCall: isAudio,
        ),
      ),
    );
  }

  static Future<void> endCall({required String callID}) async {
    await FirebaseFirestore.instance.collection('calls').doc(callID).set({
      'status': 'ended',
    }, SetOptions(merge: true));
  }
}
