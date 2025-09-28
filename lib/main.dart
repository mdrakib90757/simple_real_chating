import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:web_socket_app/screen/splash_screen/splash_screen.dart';
import 'package:web_socket_app/utils/setting/setting.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

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
        _handleCallNotification(data);
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
            // User logged in, initialize ZegoCloud SDK
            final User? currentUser = snapshot.data;
            if (currentUser != null) {
              _onUserLogin(
                currentUser.uid,
                currentUser.email ?? currentUser.uid,
              );
            }
            return SplashScreen();
          }
          return LoginScreen();
        },
      ),
    );
  }
}

bool isCallActiveOrIncoming = false;

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
    final data = message.data;
    final notificationType = data['notificationType'];
    if (notificationType == 'call') {
      _handleCallNotification(data);
      return;
    } else if (notificationType == 'chat') {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title ?? "New Message",
          notification.body ?? "",
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
            ),
          ),
          payload: jsonEncode(data),
        );
        // Auto navigate immediately
        _handleChatNotification(data);
      }
    }
  });

  // App opened from background by tapping notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = message.data;
    final notificationType = data['notificationType'];

    if (notificationType == 'call') {
      _handleCallNotification(data);
    } else if (notificationType == 'chat') {
      _handleChatNotification(data);
    }
  });

  // App opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      final data = message.data;
      final notificationType = data['notificationType'];

      if (notificationType == 'call') {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleCallNotification(data);
        });
      } else if (notificationType == 'chat') {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleChatNotification(data);
        });
      }
    }
  });
}

// get user photo
Future<String> _getUserPhoto(String userID) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userID)
      .get();
  return doc['photoUrl'] ?? "";
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final notificationType = data['notificationType'];

  if (notificationType == 'call') {
    // Show local notification
    await flutterLocalNotificationsPlugin.show(
      0,
      "📞 Incoming Call",
      data['senderEmail'], // message body
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: jsonEncode(data), // handle tap
    );
  }
}

/// Handle call notification (overlay / screen)
Future<void> _handleCallNotification(Map<String, dynamic> data) async {
  if (isCallActiveOrIncoming) return; // Already handling another call
  isCallActiveOrIncoming = true;

  final senderID = data['senderID'];
  final senderEmail = data['senderEmail'];
  final channelName = data['channelName'];
  final callType = data['callType'];

  final currentUser = FirebaseAuth.instance.currentUser!;
  if (currentUser.uid == senderID) return; // Skip if caller is self

  final callerPhotoUrl = await _getUserPhoto(senderID);
  final isAudioCall = callType == 'audio';

  // Show overlay / call screen
  showIncomingCall(
    callerName: senderEmail,
    callerPhotoUrl: callerPhotoUrl,
    callerID: senderID,
    calleeID: currentUser.uid,
    isAudioCall: isAudioCall,
    callID: channelName,
  ).then((_) {
    isCallActiveOrIncoming = false;
  });
}

/// Handle chat notification
void _handleChatNotification(Map<String, dynamic> data) {
  final senderID = data['senderID'];
  final senderEmail = data['senderEmail'];
  final currentUser = FirebaseAuth.instance.currentUser!;
  if (currentUser.uid == senderID || currentChatUserId == senderID) return;

  currentChatUserId = senderID;

  navigatorKey.currentState!
      .push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUserEmail: currentUser.email!,
            receiverEmail: senderEmail,
            receiverID: senderID,
            currentUserId: currentUser.uid,
            receiverUserId: senderID,
          ),
        ),
      )
      .then((_) => currentChatUserId = null);
}
