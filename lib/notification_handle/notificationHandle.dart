
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../screen/chat_screen.dart';

class NotificationHandler{
  final BuildContext context;
  NotificationHandler(this.context);


  void initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print("--- FOREGROUND MESSAGE RECEIVED ---");
        print("Data payload: ${message.data}");

        final senderEmail = message.data['senderEmail'];
        final senderID = message.data['senderID'];
        final messageBody = message.data['message_body'];

        if (senderEmail != null && senderID != null && messageBody != null) {
          print("Saving message received in foreground...");
          _saveMessageFromNotification(senderID, senderEmail, messageBody);
        }

        print("Navigating to chat with Email: $senderEmail, ID: $senderID");
        Future.delayed(Duration(seconds: 2), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatScreen(receiverEmail: senderEmail, receiverID: senderID),
            ),
          );
        });
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("--- NOTIFICATION TAPPED FROM BACKGROUND ---");
      print("Data payload: ${message.data}");

      String senderEmail = message.data['senderEmail'] ?? 'EMAIL NOT FOUND';
      String senderID = message.data['senderID'] ?? 'ID NOT FOUND';
      String messageBody = message.data['message_body'] ?? '';

      print("Navigating to chat with Email: $senderEmail, ID: $senderID");


      if (senderEmail != null && senderID != null && messageBody != null) {
        print("Data is valid. Saving message to Firestore.");


        _saveMessageFromNotification(senderID, senderEmail, messageBody);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatScreen(receiverEmail: senderEmail, receiverID: senderID),
          ),
        );
      } else {
        print("Incomplete data received from notification. Cannot save message.");
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print("--- APP OPENED FROM TERMINATED STATE ---");
        final senderEmail = message.data['senderEmail'];
        final senderID = message.data['senderID'];
        final messageBody = message.data['message_body'];

        if (senderEmail != null && senderID != null && messageBody != null) {
          _saveMessageFromNotification(senderID, senderEmail, messageBody);
        }
      }
    });
  }

  void _saveMessageFromNotification(String senderID, String senderEmail, String messageBody) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print("Cannot save message, user is not logged in.");
      return;
    }


    List<String> ids = [currentUser.uid, senderID];
    ids.sort();
    String chatRoomId = ids.join('_');

    print("Saving message to chat room: $chatRoomId");


    FirebaseFirestore.instance
        .collection("chat_rooms")
        .doc(chatRoomId)
        .collection("messages")
        .add({
      "text": messageBody,
      "imageUrl": null,
      "type": "text",
      "senderId": senderID,
      "senderEmail": senderEmail,
      "timestamp": FieldValue.serverTimestamp(),
    })
        .then((_) => print("Message saved successfully!"))
        .catchError((error) => print("Failed to save message: $error"));
  }

}