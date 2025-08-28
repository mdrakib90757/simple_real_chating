import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
      print("❌ Image upload failed: $e");
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
  }) async {
    final receiverDoc =
        await _firestore.collection('users').doc(receiverId).get();
    if (!receiverDoc.exists) return;
    final senderEmail = FirebaseAuth.instance.currentUser?.email;
    if (senderEmail == null) {
      print("❌ Cannot send notification: sender email is null.");
      return;
    }
    final tokens = List<String>.from(receiverDoc.data()?['fcmTokens'] ?? []);

    final chatRoomId = [senderId, receiverId]..sort();
    final chatRoom = chatRoomId.join('_');

    final senderDoc = await _firestore.collection('users').doc(senderId).get();
    final senderName = senderDoc.data()?['name'] ??
        FirebaseAuth.instance.currentUser?.email ??
        "Unknown User";

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
    });

    // Send push notification to all tokens
    final notifier = NotificationHandler(context);
    for (String token in tokens) {
      await notifier.sendPushNotification(
        token,
        message ?? "📷 Image",
        senderName,
        senderId: senderId,
        senderEmail: senderEmail,
      );
    }

    print("✅ Message sent & notification triggered!");
  }
}
