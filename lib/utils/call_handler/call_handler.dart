import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../notification_handle/notificationHandle.dart';
import '../../screen/call_screen/call_screen.dart';

class CallHandler {
  // static Future<void> startCall({
  //   required BuildContext context,
  //   required String receiverID,
  //   required String receiverEmail,
  //   required bool isAudio,
  // }) async {
  //   final currentUser = FirebaseAuth.instance.currentUser;
  //   if (currentUser == null) return;
  //
  //   // 🔹 Create callID based on both users
  //   final participants = [currentUser.uid, receiverID]..sort();
  //   final callID = "call_${participants.join('_')}";
  //
  //   // 🔹 Save call info to Firestore
  //   await FirebaseFirestore.instance.collection('calls').doc(callID).set({
  //     'callerID': currentUser.uid,
  //     'callerName': currentUser.email ?? currentUser.uid,
  //     'calleeID': receiverID,
  //     'status': 'calling', // calling → accepted → ended
  //     'timestamp': FieldValue.serverTimestamp(),
  //     'isAudio': isAudio,
  //   });
  //
  //   // 🔹 Get receiver FCM token
  //   final token = await FirebaseFirestore.instance
  //       .collection("users")
  //       .doc(receiverID)
  //       .get()
  //       .then((doc) => doc.data()?['fcmToken']);
  //
  //   // 🔹 Send push notification if token exists
  //   if (token != null) {
  //     await NotificationHandler(context).sendCallNotification(
  //       fcmToken: token,
  //       title: "Incoming ${isAudio ? 'Audio' : 'Video'} Call",
  //       body: "From ${currentUser.email ?? currentUser.uid}",
  //       senderId: currentUser.uid,
  //       senderEmail: currentUser.email ?? currentUser.uid,
  //       channelName: callID,
  //       callType: isAudio ? "audio" : "video",
  //     );
  //   }
  //
  //   // 🔹 Navigate directly to CallPage (skip CallingScreen)
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => CallPage(
  //         callerID: currentUser.uid,
  //         callerName: currentUser.email ?? currentUser.uid,
  //         calleeID: receiverID,
  //         callID: callID,
  //         isAudioCall: isAudio,
  //       ),
  //     ),
  //   );
  Future<String> getReceiverPhoto(String userID) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userID)
        .get();
    if (doc.exists) {
      return doc.data()?['photoUrl'] ?? '';
    }
    return '';
  }

  ///
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

    await FirebaseFirestore.instance.collection('calls').doc(callID).set({
      'callerID': currentUser.uid,
      'callerName': currentUser.email ?? currentUser.uid,
      'calleeID': receiverID,
      'status': 'calling',
      'timestamp': FieldValue.serverTimestamp(),
      'isAudio': isAudio,
    });

    final token = await FirebaseFirestore.instance
        .collection("users")
        .doc(receiverID)
        .get()
        .then((doc) => doc.data()?['fcmToken']);

    // if (token != null) {
    //   await NotificationHandler(context).sendCallNotification(
    //     fcmToken: token,
    //     title: "Incoming ${isAudio ? 'Audio' : 'Video'} Call",
    //     body: "From ${currentUser.email ?? currentUser.uid}",
    //     senderId: currentUser.uid,
    //     senderEmail: currentUser.email ?? currentUser.uid,
    //     channelName: callID,
    //     callType: isAudio ? "audio" : "video",
    //     notificationType: 'call',
    //   );
    // }

    /// Check if CallPage already exists
    if (ModalRoute.of(context)?.settings.name != "/call") {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: "/call"),
          builder: (_) => CallPage(
            callerID: currentUser.uid,
            callerName: currentUser.email ?? currentUser.uid,
            calleeID: receiverID,
            callID: callID,
            isAudioCall: isAudio,
            isCaller: true,
          ),
        ),
      );
    }
  }

  static Future<void> endCall({required String callID}) async {
    await FirebaseFirestore.instance.collection('calls').doc(callID).set({
      'status': 'ended',
    }, SetOptions(merge: true));
  }
}
