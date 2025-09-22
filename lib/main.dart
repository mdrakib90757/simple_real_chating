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
      home: LoginScreen(),
    );
  }
}

String? currentChatUserId;

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
  print("--- _handleNavigation Called ---");
  print("Sender ID: $senderID, Current Open Chat: $currentChatUserId");

  if (senderEmail != null && senderID != null) {
    // Prevent duplicate navigation if already in this chat
    if (currentChatUserId == senderID) {
      print("Already on chat screen with $senderID. Skipping navigation.");
      return;
    }

    Future.delayed(const Duration(milliseconds: 900), () {
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
