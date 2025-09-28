import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_app/model/message_model/message_model.dart';
import '../notification_handle/notificationHandle.dart';

/// ChatService class handles all chat-related operations
/// such as sending messages, uploading images, and notifications.
class ChatService {
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Firebase Storage instance
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an image file to Firebase Storage and returns the download URL.
  ///
  /// [imageFile] - The File object of the image to upload.
  /// Returns a String URL of the uploaded image or empty string if failed.
  Future<String> uploadImage(File imageFile) async {
    try {
      // Generate a unique filename using current timestamp
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();

      // Reference to Firebase Storage location
      Reference ref = _storage.ref().child('chat_images/$fileName');

      // Upload the image file to Firebase Storage
      UploadTask task = ref.putFile(imageFile);

      // Wait for upload to complete
      TaskSnapshot snapshot = await task;

      // Get the download URL
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print(" Image upload failed: $e");
      return "";
    }
  }

  /// Sends a chat message from [senderId] to [receiverId].
  /// Can also send images, documents, or call notifications.
  ///
  /// [context] - BuildContext for showing notifications.
  /// [senderId] - UID of the sender.
  /// [receiverId] - UID of the receiver.
  /// [message] - Optional text message.
  /// [imageUrl] - Optional image URL.
  /// [type] - Optional type of message: 'text', 'image', 'video', 'document', 'call'.
  /// [repliedMessage] - Optional replied message info.
  /// [fileName] - Optional filename for documents.
  /// [publicId] - Optional public ID for images.
  /// [isAudioCall] - Optional boolean for call type: true = audio, false = video.

  Future<void> sendMessage({
    required BuildContext context,
    required String senderId,
    required String receiverId,
    bool? isAudioCall,
    String? message,
    String? imageUrl,
    String? type,
    RepliedMessageInfo? repliedMessage,
    String? fileName,
    String? publicId,
  }) async {
    final receiverDoc = await _firestore
        .collection('users')
        .doc(receiverId)
        .get();

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

    // Add message to Firestore under chatRoom
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
          "publicId": publicId,
          'isAudioCall': isAudioCall,
        });

    // Update chat room info
    await _firestore.collection('chat_rooms').doc(chatRoom).set({
      'participants': [senderId, receiverId],
      'participant_info': {
        senderId: {
          'email':
              senderDoc.data()?['email'] ??
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
