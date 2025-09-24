import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_app/firebase_options.dart';
import 'package:web_socket_app/screen/auth_screen/signIn_screen.dart';
import 'package:web_socket_app/screen/call_screen/call_screen.dart';
import 'package:web_socket_app/screen/chat_screen.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:web_socket_app/screen/home_screen.dart';
import 'package:web_socket_app/screen/incomaing_screen/incomaing_screen.dart';
import 'package:web_socket_app/utils/setting/setting.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background Message: ${message.messageId}");
}

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Initialize local notifications
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('ic_stat_notification_bell');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: androidInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        _handleNavigation(data);
      }
    },
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  setupFirebaseListeners();

  WidgetsFlutterBinding.ensureInitialized();

  // cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            // User logged in, initialize ZegoCloud SDK
            final User? currentUser = snapshot.data;
            if (currentUser != null) {
              _onUserLogin(
                currentUser.uid,
                currentUser.email ?? currentUser.uid,
              );
            }
            return HomeScreen();
          }
          return LoginScreen();
        },
      ),
    );
  }
}

String? currentChatUserId;
String? currentCallChannel;

/// ZegoCloud SDK Initialization
void _onUserLogin(String userID, String userName) {
  final invitationService = ZegoUIKitPrebuiltCallInvitationService();
  invitationService.init(
    appID: ZegoConfig.appID,
    appSign: ZegoConfig.appSign,
    userID: userID,
    userName: userName,
    plugins: [ZegoUIKitSignalingPlugin()],
  );
}

///  Foreground message listener setup (call this from HomeScreen initState)
void setupFirebaseListeners() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("--- Foreground Message ---");
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      // Show heads-up local notification
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            icon: 'ic_stat_notification_bell',
          ),
        ),
        payload: jsonEncode(message.data),
      );

      // Auto navigate immediately
      _handleNavigation(message.data);
    }
  });

  // App opened from background by tapping notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("--- Notification tapped from background ---");
    _handleNavigation(message.data);
  });
  // App opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print("--- App opened from terminated state ---");
      Future.delayed(const Duration(seconds: 1), () {
        _handleNavigation(message.data);
      });
    }
  });
}

/// Handle navigation for messages and calls
void _handleNavigation(Map<String, dynamic> data) async {
  final senderEmail = data['senderEmail'];
  final senderID = data['senderID'];
  final callType = data['callType'];
  final channelName = data['channelName'];
  final notificationType = data['notificationType'];

  if (senderEmail == null || senderID == null) return;

  while (navigatorKey.currentState == null) {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  if (notificationType == 'call' && channelName != null) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final isAudioCall = callType == 'audio';

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => IncomingCallPage(
          callerID: senderID,
          callerName: senderEmail,
          calleeID: currentUser.uid,
          isAudioCall: isAudioCall,
          callID: channelName,
        ),
      ),
    );
  }
  currentChatUserId = senderID;
  navigatorKey.currentState!
      .push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUserEmail: FirebaseAuth.instance.currentUser!.email!,
            receiverEmail: senderEmail,
            receiverID: senderID,
            currentUserId: FirebaseAuth.instance.currentUser!.uid,
            receiverUserId: senderID,
          ),
        ),
      )
      .then((_) => currentChatUserId = null);
}

/// Navigate to chat screen
// void _handleNavigation(Map<String, dynamic> data) {
//   final senderEmail = data['senderEmail'];
//   final senderID = data['senderID'];
//   final String? callType = data['callType']; // Added for call handling
//   final String? channelName = data['channelName'];
//   final String? notificationType = data['notificationType']; // Added for call handling
//   print("--- _handleNavigation Called ---");
//   print("Sender ID: $senderID, Current Open Chat: $currentChatUserId");
//   print("Call Type: $callType, Channel Name: $channelName");
//
//   if (senderEmail != null && senderID != null) {
//     // Prevent duplicate navigation if already in this chat
//     if (currentChatUserId == senderID) {
//       print("Already on chat screen with $senderID. Skipping navigation.");
//       return;
//     }
//
//     if (senderID == null || FirebaseAuth.instance.currentUser == null) {
//       print("Cannot navigate: Sender ID or current user is null.");
//       return;
//     }
//
//
//
//     // Handle Call Notifications
//     if (notificationType == 'call' && channelName != null && senderEmail != null) {
//       final currentUser = FirebaseAuth.instance.currentUser!;
//       final bool isAudioCall = callType == 'audio';
//
//       Future.delayed(const Duration(milliseconds: 500), () {
//         if (navigatorKey.currentState != null) {
//           print("Navigator state is valid. Pushing IncomingCallPage...");
//           navigatorKey.currentState!.push(
//             MaterialPageRoute(
//               builder: (_) => IncomingCallPage(
//                 callerID: senderID,
//                 callerName: senderEmail, // Assuming senderEmail is the caller's display name
//                 calleeID: currentUser.uid,
//                 isAudioCall: isAudioCall,
//                 callID: channelName, // Pass the Zego callID to IncomingCallPage
//               ),
//             ),
//           );
//         } else {
//           print("Navigator not ready yet, scheduling call navigation again...");
//           _handleNavigation(data);
//         }
//       });
//       return; // Important: Don't fall through to chat navigation
//     }
//
//
//
//
//
//
// // Handle message Notifications
//     if (notificationType != 'call' && senderEmail != null) {
//
//       if (currentChatUserId == senderID) {
//         print("Already on chat screen with $senderID. Skipping navigation.");
//         return;
//       }
//
//       Future.delayed(const Duration(milliseconds: 500), () {
//         try {
//           if (navigatorKey.currentState != null) {
//             print("Navigator state is valid. Pushing ChatScreen...");
//             navigatorKey.currentState!.push(
//               MaterialPageRoute(
//                 builder: (_) => ChatScreen(
//                   currentUserEmail: FirebaseAuth.instance.currentUser!.email!,
//                   receiverEmail: senderEmail,
//                   receiverID: senderID,
//                   currentUserId: FirebaseAuth.instance.currentUser!.uid,
//                   receiverUserId: senderID,
//                 ),
//               ),
//             );
//           } else {
//             print("Navigator not ready yet, scheduling again...");
//             _handleNavigation(data);
//           }
//         } catch (e) {
//           print("Navigation error Error ${e}");
//         }
//       });
//     }
//
//
//   }
// }
