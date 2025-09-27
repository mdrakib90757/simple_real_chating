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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background Message: ${message.messageId}");
  print("--- Background Message Handler ---");
  print("Message ID: ${message.messageId}");
  print("Message data: ${message.data}");
  final data = message.data;
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
      _handleNavigation(data); // This will show the overlay
      // We explicitly DO NOT show a generic local notification for calls
      return; // Stop further processing for this call message

    }

      if (notification != null &&  !isCallActiveOrIncoming) {
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
    print("--- Notification tapped from background ---");
    print("Message data: ${message.data}");
    _handleNavigation(message.data);
  });
  // App opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print("--- App opened from terminated state ---");
      print("Message data: ${message.data}");
      Future.delayed(const Duration(seconds: 1), () {
        _handleNavigation(message.data);
      });
    }
  });
}

Future<String> _getUserPhoto(String userID) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userID)
      .get();
  return doc['photoUrl'] ?? "";
}

/// Handle navigation for messages and calls
void _handleNavigation(Map<String, dynamic> data) async {

  final senderEmail = data['senderEmail'];
  final senderID = data['senderID'];
  final callType = data['callType'];
  final channelName = data['channelName'];
  final notificationType = data['notificationType'];

  print("---- 🔔 _handleNavigation Called ----");
  print("senderEmail: $senderEmail");
  print("senderID: $senderID");
  print("callType: $callType");
  print("channelName: $channelName");
  print("notificationType: $notificationType");
  print("Current FirebaseAuth UID: ${FirebaseAuth.instance.currentUser?.uid}");

  if (senderEmail == null || senderID == null) return;
  final currentUser = FirebaseAuth.instance.currentUser!;

  // ✅ Caller skip
  if (currentUser.uid == senderID) {
    print("⚠️ Caller notification skipped");
    return;
  }

  while (navigatorKey.currentState == null) {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // Call notification
  if (notificationType == 'call' && channelName != null) {

    if (isCallActiveOrIncoming) {
      print("Another call is already active/incoming. Ignoring new call notification.");
      return; // Ignore if another call is already being handled
    }
    isCallActiveOrIncoming = true; //

    final isAudioCall = callType == 'audio';
    final callerPhotoUrl = await _getUserPhoto(senderID);

    showIncomingCallOverlayWithNavigatorKey(
      callerName: senderEmail,
      callerPhotoUrl: callerPhotoUrl,
      callerID: senderID,
      calleeID: currentUser.uid,
      isAudioCall: isAudioCall,
      callID: channelName,
    ).then((_) {
      // Once the overlay is removed (call answered/declined/timed out), reset the flag
      isCallActiveOrIncoming = false;
    });
    return; // Exit as call is handled
  }


  // Chat notification
  if (notificationType == 'chat' && !isCallActiveOrIncoming) {
    if (currentChatUserId == senderID) return;
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
}
