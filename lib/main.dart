import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_app/firebase_options.dart';
import 'package:web_socket_app/screen/auth_screen/signIn_screen.dart';
import 'package:web_socket_app/screen/chat_screen.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:web_socket_app/screen/home_screen.dart';
import 'package:web_socket_app/screen/video_call_screen/video_call_screen.dart';

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

  cameras = await availableCameras();
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

/// Navigate to chat screen
void _handleNavigation(Map<String, dynamic> data) {
  final senderEmail = data['senderEmail'];
  final senderID = data['senderID'];
  final String? callType = data['callType']; // Added for call handling
  final String? channelName = data['channelName']; // Added for call handling

  print("--- _handleNavigation Called ---");
  print("Sender ID: $senderID, Current Open Chat: $currentChatUserId");
  print("Call Type: $callType, Channel Name: $channelName");

  if (senderEmail != null && senderID != null) {
    // Prevent duplicate navigation if already in this chat
    if (currentChatUserId == senderID) {
      print("Already on chat screen with $senderID. Skipping navigation.");
      return;
    }

    if (senderID == null || FirebaseAuth.instance.currentUser == null) {
      print("Cannot navigate: Sender ID or current user is null.");
      return;
    }

    // --- Handle Call Notifications ---
    if (callType != null && channelName != null) {
      // If already in a call on this channel, don't navigate again
      if (currentCallChannel == channelName) {
        print("Already on call channel $channelName. Skipping navigation.");
        return;
      }

      // Set currentCallChannel to prevent duplicate navigation
      currentCallChannel = channelName;

      // calling Push notification to call screen
      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentState != null) {
          print("Navigator state is valid. Pushing VideoCallPage...");
          navigatorKey.currentState!
              .push(
                MaterialPageRoute(
                  builder: (_) => VideoCallPage(
                    channelName: channelName,
                    isVideoCall: callType == "Video",
                  ),
                ),
              )
              .then((_) {
                // Reset currentCallChannel when the call page is popped
                currentCallChannel = null;
              });
        } else {
          print("Navigator not ready for call, scheduling again...");
          SchedulerBinding.instance.addPostFrameCallback((_) {
            // Use SchedulerBinding to wait for next frame
            _handleNavigation(data);
          });
        }
      });
      return;
    }

    // auto navigate push notification
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        if (navigatorKey.currentState != null) {
          print("Navigator state is valid. Pushing ChatScreen...");
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                receiverEmail: senderEmail,
                receiverID: senderID,
                currentUserId: FirebaseAuth.instance.currentUser!.uid,
                receiverUserId: senderID,
              ),
            ),
          );
        } else {
          print("Navigator not ready yet, scheduling again...");
          _handleNavigation(data);
        }
      } catch (e) {
        print("Navigation error Error ${e}");
      }
    });
  }
}
