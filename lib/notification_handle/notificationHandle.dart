import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:web_socket_app/utils/setting/setting.dart';

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

  // Chat Notification Sender
  Future<void> sendPushNotification(
    String fcmToken,
    String title,
    String body, {
    required String senderId,
    required String senderEmail,
  }) async {
    final Map<String, dynamic> payload = {
      'message': {
        'token': fcmToken,
        'notification': {'title': title, 'body': body},
        'data': {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'senderID': senderId,
          'senderEmail': senderEmail,
          'notificationType': 'chat',
        },
        'android': {
          'priority': 'high',
          'notification': {'channel_id': 'high_importance_channel'},
        },
      },
    };

    final String encodedPayload = jsonEncode(payload);
    print("Sending FCM V1 Payload");
    print(encodedPayload);
    try {
      final accessToken = await _getAccessToken();
      final projectId = "real-time-messaging-9b660";
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: encodedPayload,
      );

      if (response.statusCode == 200) {
        print(" Notification sent successfully!");
      } else {
        print(
          " Failed to send notification. Status code: ${response.statusCode}",
        );
        print("FCM Error Body: ${response.body}");
      }
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  // Call Notification Sender
  Future<void> sendCallNotification({
    required String fcmToken,
    required String title,
    required String body,
    required String senderId,
    required String senderEmail,
    required String channelName,
    required String callType,
    required String notificationType, // "Audio" or "Video"
    required String receiverId,
    List<String> inviteeIDs = const [],
  }) async {
    String? fcmToken = await _getRecipientFCMToken(receiverId);

    if (fcmToken == null) {
      print(
        "Recipient $receiverId has no valid FCM token. Cannot send notification.",
      );
      return; // Exit if no token is found
    }

    final int zegoCallTypeInt = (callType.toLowerCase() == "video") ? 1 : 0;
    final int zegoInvitationType = inviteeIDs.length > 1 ? 2 : 1;

    // Define Zego specific data based on their documentation
    // This is the structure Zego SDK looks for when handling FCM messages.
    final Map<String, dynamic> zegoDataForFCM = {
      "callID": channelName,
      "inviterID": senderId,
      "inviterName": senderEmail,
      "invitees": inviteeIDs
          .map((id) => {"user_id": id, "user_name": ""})
          .toList(), // Zego often expects invitees as a list of maps
      "callType": zegoCallTypeInt,
      "type": zegoInvitationType,
      "customData": {
        "notificationType": notificationType,
        "senderEmail": senderEmail,
        "senderId": senderId,
        "channelName": channelName,
        "callTypeString": callType,
      },
    };

    final Map<String, dynamic> payload = {
      'message': {
        'token': fcmToken,
        'notification': {'title': title, 'body': body},
        'data': {
          // Your custom data for Flutter app to process
          'senderID': senderId,
          'senderEmail': senderEmail,
          'channelName': channelName,
          'callType': callType, // Original string type
          'notificationType': notificationType,
          'zego': jsonEncode(
            zegoDataForFCM,
          ), // Encode Zego's specific data as a JSON string
          'zego_call_id': channelName,
          'zego_inviter_id': senderId,
          'zego_inviter_name': senderEmail,
          'zego_type': zegoCallTypeInt.toString(),
          'zego_invitation_type': zegoInvitationType
              .toString(), // Add invitation type
          'zego_platform': 'android', // or 'ios'
          'invitees': jsonEncode(inviteeIDs),
        },
        'android': {
          'priority': 'high',
          'notification': {
            'channel_id': 'call_channel', // Use your dedicated call channel
            'sound': 'ringtone',
            'tag': 'call_${channelName}',
            'full_screen_intent': true, // Essential for Android 10+
            'category': 'call', // Important for Android to treat it as a call
          },
        },
        'apns': {
          // For iOS notifications - you'd likely need CallKit for full screen
          'headers': {'apns-priority': '10', 'apns-push-type': 'alert'},
          'payload': {
            'aps': {
              'alert': {'title': title, 'body': body},
              'sound': 'incoming_call.wav',
            },
            'senderID': senderId,
            'senderEmail': senderEmail,
            'channelName': channelName,
            'callType': callType,
            'notificationType': notificationType,
            'zego': zegoDataForFCM, // For iOS, send the object directly
            'invitees': inviteeIDs,
          },
        },
      },
    };

    final String encodedPayload = jsonEncode(payload);
    print("Sending FCM V1 Payload (Call)");
    print(encodedPayload);

    try {
      final accessToken = await _getAccessToken();
      final projectId =
          "real-time-messaging-9b660"; // Replace with your project ID
      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: encodedPayload,
      );

      if (response.statusCode == 200) {
        print("$callType Call Notification sent successfully!");
      } else {
        print(
          "Failed to send $callType call notification. Status code: ${response.statusCode}",
        );
        print("FCM Error Body: ${response.body}");
        if (response.body.contains("UNREGISTERED") ||
            response.body.contains("InvalidRegistrationToken")) {
          print("Removing UNREGISTERED token for user: $receiverId");
          await FirebaseFirestore.instance
              .collection('users')
              .doc(receiverId)
              .update({
                'fcmToken': FieldValue.delete(), // Remove the invalid token
              });
        }
      }
    } catch (e) {
      print("Error sending $callType call notification: $e");
    }
  }
}

// Call Cancelled Notification
Future<void> sendCallCancelledNotification(
  String receiverID,
  String callID,
) async {
  await FirebaseFirestore.instance.collection('calls').doc(callID).set({
    'status': 'cancelled',
  }, SetOptions(merge: true));
}

// Helper function to get recipient's FCM token
Future<String?> _getRecipientFCMToken(String recipientId) async {
  try {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientId)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      return userData['fcmToken'] as String?;
    }
  } catch (e) {
    print('Error getting recipient FCM token: $e');
  }
  return null;
}
