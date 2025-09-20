import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:web_socket_app/model/message_model/message_model.dart';
import '../notification_handle/notificationHandle.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(File imageFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('chat_images/$fileName');
      UploadTask task = ref.putFile(imageFile);
      TaskSnapshot snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print(" Image upload failed: $e");
      return "";
    }
  }

  Future<void> sendMessage({
    required BuildContext context,
    required String senderId,
    required String receiverId,
    String? message,
    String? imageUrl,
    String? type,
    RepliedMessageInfo? repliedMessage,
    String? fileName,
  }) async {
    final receiverDoc =
        await _firestore.collection('users').doc(receiverId).get();

    if (!receiverDoc.exists) return;
    final senderEmail = FirebaseAuth.instance.currentUser?.email;
    if (senderEmail == null) {
      print(" Cannot send notification: sender email is null.");
      return;
    }
    // final tokens = List<String>.from(receiverDoc.data()?['fcmTokens'] ?? []);
    final List<String> receiverTokens = List<String>.from(
      receiverDoc.data()?['fcmTokens'] ?? [],
    );
    final String? senderToken = await FirebaseMessaging.instance.getToken();

    if (senderToken != null) {
      receiverTokens.remove(senderToken);
    }
    final List<String> ids = [senderId, receiverId];
    ids.sort();
    final String chatRoom = ids.join('_');
    final Timestamp timestamp = Timestamp.now();
    final senderDoc = await _firestore.collection('users').doc(senderId).get();
    final senderName = senderDoc.data()?['name'] ?? senderEmail.split('@')[0];

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoom)
        .collection('messages')
        .add({
      'text': message,
      'imageUrl': imageUrl,
      'type': type ?? (imageUrl != null ? 'image' : 'text'),
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': FieldValue.serverTimestamp(),
      'senderEmail': FirebaseAuth.instance.currentUser?.email ?? "",
      'senderName': senderName,
      'timestamp': timestamp,
      'repliedTo': repliedMessage?.toJson(),
      'isRead': false,
      'readAt': null,
      'fileName': fileName,
    });

    await _firestore.collection('chat_rooms').doc(chatRoom).set({
      'participants': [senderId, receiverId],
      'participant_info': {
        senderId: {
          'email': senderDoc.data()?['email'] ??
              FirebaseAuth.instance.currentUser?.email ??
              "Unknown",
          'photoUrl': senderDoc.data()?['photoUrl'],
        },
        receiverId: {
          'email': receiverDoc.data()?['email'] ?? "Unknown",
          'photoUrl': receiverDoc.data()?['photoUrl'],
        },
      },
      'last_message': message ?? "📷 Image",
      'last_message_sender_id': senderId,
      'last_message_timestamp': timestamp,
    }, SetOptions(merge: true));

    // Send push notification to all tokens
    final notifier = NotificationHandler(context);
    for (String token in receiverTokens) {
      await notifier.sendPushNotification(
        token,
        message ?? "📷 Image",
        senderName,
        senderId: senderId,
        senderEmail: senderEmail,
      );
    }
    print(" Message sent & notification triggered!");
  }
}
