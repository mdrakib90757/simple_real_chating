// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;
// import '../screen/chat_screen.dart';
//
// class NotificationHandler {
//   final BuildContext context;
//   static const String serverKey = "YOUR_FCM_SERVER_KEY_HERE"; // replace with FCM server key
//   NotificationHandler(this.context);
//
//   void initFirebaseMessaging() async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser == null) return;
//
//     FirebaseMessaging messaging = FirebaseMessaging.instance;
//     await messaging.requestPermission();
//
//     // Foreground
//     FirebaseMessaging.onMessage.listen((message) {
//       if (message.data.isNotEmpty) {
//         _saveMessage(message.data);
//         _navigateToChat(message.data);
//       }
//     });
//
//     // Background tapped
//     FirebaseMessaging.onMessageOpenedApp.listen((message) {
//       if (message.data.isNotEmpty) {
//         _saveMessage(message.data);
//         _navigateToChat(message.data);
//       }
//     });
//   }
//
//   void _saveMessage(Map<String, dynamic> data) async {
//     final currentUser = FirebaseAuth.instance.currentUser;
//     if (currentUser == null) return;
//
//     final senderId = data['senderId'];
//     final senderEmail = data['senderEmail'];
//     final message = data['message_body'];
//
//     final chatRoomId = [currentUser.uid, senderId]..sort();
//     final chatRoom = chatRoomId.join('_');
//
//     await FirebaseFirestore.instance
//         .collection('chat_rooms')
//         .doc(chatRoom)
//         .collection('messages')
//         .add({
//       'text': message,
//       'type': 'text',
//       'senderId': senderId,
//       'senderEmail': senderEmail,
//       'receiverId': currentUser.uid,
//       'timestamp': FieldValue.serverTimestamp(),
//     });
//   }
//
//   void _navigateToChat(Map<String, dynamic> data) {
//     final senderId = data['senderId'];
//     final senderEmail = data['senderEmail'];
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ChatScreen(
//           receiverEmail: senderEmail,
//           receiverID: senderId,
//           currentUserId: FirebaseAuth.instance.currentUser!.uid,
//           receiverUserId: senderId,
//         ),
//       ),
//     );
//   }
//
//   Future<void> sendPushNotification(String fcmToken, String message, String senderId) async {
//     final url = Uri.parse("https://fcm.googleapis.com/fcm/send");
//     final notification = {"title": "New Message", "body": message};
//     final data = {"click_action": "FLUTTER_NOTIFICATION_CLICK", "senderId": senderId, "message_body": message};
//
//     final payload = {"to": fcmToken, "notification": notification, "data": data};
//
//     final response = await http.post(
//       url,
//       headers: {"Content-Type": "application/json", "Authorization": "key=$serverKey"},
//       body: jsonEncode(payload),
//     );
//
//     if (response.statusCode == 200) print("✅ Notification sent!");
//     else print("❌ Notification failed: ${response.body}");
//   }
// }

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';

class NotificationHandler {
  final BuildContext context;
  NotificationHandler(this.context);

  // Load JSON from asset
  static const _serviceAccountJson = {
    "type": "service_account",
    "project_id": "real-time-messaging-9b660",
    "private_key_id": "fb1ea1b0a93aa4a81fa686d3c907694b2025e818",
    "private_key":
        "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQClnaRj2TmPNSFh\nAV6E5pOjz5b8XMO9z7aWOjBr/97Q79jmGZvBeWBFhww4leSe0HIYRxwhEeJo2S00\nGdiOdFH5g6ZpgYr1PS2/mXhCSEDvzEECGY6fmhr9ob0YIgmm2h4om3DJvSgfwrq7\n1BLmyx0kxQAnpOvnGI1ZuCcjbSwHbS2OUqaNrwBlHonlJaXaZ5d8ozbuAIZi+99t\nWXHZcp7QckifEQZh3uJQFSQeE7Bxho0EzbV/P4NdHT+0uKGXuyNvOnecjwuy8aj0\nAX0IdEVtSwuIuP2ATgcoGQ3VCUugQwA+ejReWFZADiYiwvP/oukJZ3q17VPTqCJC\nQngQJRCfAgMBAAECggEAGFENnoV6AI9d/8a6MIxEWDR2KEacjOWPGv6fNnRCrG3S\n7HINHvqpynuaLULA5xqW7f6e4DImipt8mh5DYCMvGBIe4HXfR8O8UFoBwMWoFy1n\nzB2hhciUNvJE9+KjhSaYcADmrhBCcGtgjIyGW/GtrUTpkWiTJILD2k0CHh787Hf8\nBzLwvlFcL/5qDh2dwa+0Xj1OvHXcomUVdWZRUx5BzAXfC3strMBfeFh1fEq7713V\nUyJ0CCvtpjY0y/u21WQBdOEkgN2svp6ZY/f6l4gCd22tjBB0qFMABFwDLh9t4cyW\nxPhLd5CXC6Q8vVIE/J1uLyauUa8HqEhemrRLAv5GOQKBgQDjtVIqPmqkA54cgDJy\nexBO5PJhjvwYpgtNYqf78tyan3geV7TQDINCQtAsT9HGx8wu0/+gmFEgHGf6CXeU\n3i39S5gKxUTSGYE9qRwnVH3DEvm6md5X4VYDIzOZ1ryg6WwcKX0wG2cD/Pm6hTqw\nAwGjTE0qptZbXE/VYaoKwjE05wKBgQC6MVsMVqkIDJCPwMUtuWkv005svhk3qG9v\n4dyNtppa6fdAC4VrDT7i+4NOb5tWTI10a130DkRI1LmbwWbiyyruD3PUsNC7xDWw\nmFFfj0JzhcWeF6bXq2byVLws6pUwqS3Kx5ulg5OJx3EnImMoXjQX+iL8jTYkSdnQ\nJ4MO1pkXiQKBgQCSYzsTVVURZBH9mJzV5C+zyJPaDCYdYoHZmhcMbjFMZkC+oPvo\n1GJ98p4KHrZp6IBninrIL6PX1OszX2q1FbDTKgnwwqlfuG3RyioDTtoa0tQhFlJO\nhNra4YKG3/ocKHQMFtAYYUV01ulk88mq5gPji2YAiYk86reYIlVC3Vzs+QKBgQCg\nrW8RGsgL9ivaolSGvPaVGxkWpoZEjcp9FsCqWuahhj6kukyMsYWPg9UwnwfCVZXM\n3crajmVHJKx4SVJsbT/C6PrglSXMo+phV1EB0jNaVhrP70E/5N6WSaGKcXYF5Dls\nQQ2ErCNqRv7S8s33TDRQbMA8ifArKMAa7b4f0/mRYQKBgQCzSqFVVl68twiAbkkr\noGoCxvQiyeFekOtxURSDtYyHQRJOEnifraQ0ipN+arAhWGZjadD1jfiy5wOzzOyV\ndNTYr2iKnCfqljduvUpJW9X2IQsXdGxhcF4czHiDiNgF9nZYhonzi9IuQM87jt1g\nuYI2l4KBRD8Yz1W1HUz30uK/WA==\n-----END PRIVATE KEY-----\n",
    "client_email":
        "firebase-adminsdk-fbsvc@real-time-messaging-9b660.iam.gserviceaccount.com",
    "client_id": "106279839680342371635",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url":
        "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40real-time-messaging-9b660.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com",
  };

  Future<String> _getAccessToken() async {
    final accountCredentials = ServiceAccountCredentials.fromJson(
      _serviceAccountJson,
    );
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = await clientViaServiceAccount(accountCredentials, scopes);
    final token = client.credentials.accessToken.data;
    client.close();
    return token;
  }

  Future<void> sendPushNotification(
    String fcmToken,
    String title,
    String body,
  ) async {
    try {
      final accessToken = await _getAccessToken();
      final projectId = "real-time-messaging-9b660";
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
      );

      final message = {
        "message": {
          "token": fcmToken,
          "notification": {"title": title, "body": body},
          "data": {"click_action": "FLUTTER_NOTIFICATION_CLICK"},
          "android": {
            "priority": "high",
            "notification": {"channel_id": "high_importance_channel"},
          },
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );

      if (response.statusCode == 200) {
        print("✅ Notification sent successfully!");
      } else {
        print("❌ Notification failed: ${response.body}");
      }
    } catch (e) {
      print("❌ Error sending notification: $e");
    }
  }
}
