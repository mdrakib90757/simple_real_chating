import 'dart:convert';
import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_app/firebase_options.dart';
import 'package:web_socket_app/screen/auth_screen/signIn_screen.dart';
import 'package:web_socket_app/screen/call_screen/call_screen.dart';
import 'package:web_socket_app/screen/chat_screen.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:web_socket_app/screen/incomaing_screen/incomaing_screen.dart';
import 'package:web_socket_app/screen/splash_screen/splash_screen.dart';
import 'package:web_socket_app/utils/setting/setting.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
// const AndroidNotificationChannel channel = AndroidNotificationChannel(
//   'high_importance_channel',
//   'High Importance Notifications',
//   description: 'This channel is used for important notifications.',
//   importance: Importance.high,
// );

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'call_channel',
  'Incoming Calls',
  description: 'Used for incoming call notifications',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('ringtone'), // custom ringtone
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // // ZPNS token registration
  // ZPNs.getDeviceToken().then((token) {
  //   print("ZPNS Device Token: $token");
  //   // এখানে তুমি তোমার server এ token পাঠাতে পারো
  // });

  // Setup local notification channel
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
        if (response.actionId == 'ACCEPT_CALL') {
          _acceptCall(data);
        } else if (response.actionId == 'DECLINE_CALL') {
          _declineCall(data);
        } else {
          _handleCallNotification(data);
        }
      }
    },
  );

  // Foreground notifications
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
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  if (data['notificationType'] == 'call') {
    await flutterLocalNotificationsPlugin.show(
      1000,
      "📞 Incoming Call",
      "${data['senderEmail']} is calling...",
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // 🔑 full screen
          category: AndroidNotificationCategory.call,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('ringtone'),
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'ACCEPT_CALL',
              'Accept',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              'DECLINE_CALL',
              'Decline',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode(data),
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
  FirebaseMessaging.onMessage.listen((message) {
    final data = message.data;
    if (data['notificationType'] == 'call') {
      _handleCallNotification(data);
    }
  });

  // App opened from background by tapping notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("--- Notification tapped from background ---");
    print("--- Notification tapped from background ---");
    print("Message data: ${message.data}");

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
      print("--- App opened from terminated state ---");
      print("Message data: ${message.data}");
      final data = message.data;
      final notificationType = data['notificationType'];

      if (notificationType == 'call') {
        Future.delayed(const Duration(milliseconds: 500), () {
          showFullScreenIncomingCall(message.data);
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

/// Handle call notification (overlay / screen)
Future<void> _handleCallNotification(Map<String, dynamic> data) async {
  final senderID = data['senderID'];
  final senderEmail = data['senderEmail'];
  final channelName = data['channelName'];
  final callType = data['callType'];
  final notificationType = data['notificationType'];

  print("---- 🔔 _handleNavigation Called ----");
  print("senderEmail: $senderEmail");
  print("senderID: $senderID");
  print("callType: $callType");
  print("channelName: $channelName");
  print("notificationType: $notificationType");
  print("Current FirebaseAuth UID: ${FirebaseAuth.instance.currentUser?.uid}");

  final currentUser = FirebaseAuth.instance.currentUser!;
  if (currentUser.uid == senderID) return; // Skip if caller is self

  final callerPhotoUrl = await _getUserPhoto(senderID);
  final isAudioCall = callType == 'audio';

  // Show overlay / call screen
  showIncomingCallOverlayWithNavigatorKey(
    callerName: senderEmail,
    callerID: senderID,
    calleeID: currentUser.uid,
    isAudioCall: isAudioCall,
    callID: channelName,
    callerPhotoUrl: callerPhotoUrl,
  );
}

/// Handle chat notification
void _handleChatNotification(Map<String, dynamic> data) {
  final senderID = data['senderID'];
  final senderEmail = data['senderEmail'];
  final currentUser = FirebaseAuth.instance.currentUser!;

  log(
    "Handling chat from senderID: $senderID, currentUserID: ${currentUser.uid}",
  );

  if (currentUser.uid == senderID || currentChatUserId == senderID) {
    log("Ignoring chat because it's from self or already open");
    return;
  }

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
  log("ChatScreen closed for senderID: $senderID");
}

// Future<void> initNotifications() async {
//   const AndroidInitializationSettings androidInit =
//   AndroidInitializationSettings('ic_stat_call');
//
//   final InitializationSettings initializationSettings =
//   InitializationSettings(android: androidInit);
//
//   await flutterLocalNotificationsPlugin.initialize(
//     initializationSettings,
//     onDidReceiveNotificationResponse: (NotificationResponse response) async {
//       if (response.payload != null) {
//         final data = jsonDecode(response.payload!);
//
//         if (response.actionId == 'ACCEPT_CALL') {
//           _acceptCall(data);
//         } else if (response.actionId == 'DECLINE_CALL') {
//           _declineCall(data);
//         } else {
//           // Default tap → navigate
//           _handleNotificationTap(data);
//         }
//       }
//     },
//   );
//
//   await flutterLocalNotificationsPlugin
//       .resolvePlatformSpecificImplementation<
//       AndroidFlutterLocalNotificationsPlugin>()
//       ?.createNotificationChannel(channel);
// }

Future<void> showFullScreenIncomingCall(Map<String, dynamic> data) async {
  await flutterLocalNotificationsPlugin.show(
    999, // unique ID
    "📞 Incoming Call",
    "${data['senderEmail'] ?? 'Unknown'} is calling...",
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true, // 🔑 Full screen intent
        ongoing: true,
        autoCancel: false,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'ACCEPT_CALL',
            'Accept',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'DECLINE_CALL',
            'Decline',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    ),
    payload: jsonEncode(data),
  );
}

Future<void> _acceptCall(Map<String, dynamic> data) async {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final callID = data['channelName'];

  await FirebaseFirestore.instance.collection('calls').doc(callID).set({
    "status": "accepted",
  }, SetOptions(merge: true));

  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => CallPage(
        callID: callID,
        callerID: data['senderID'],
        calleeID: currentUser.uid,
        isAudioCall: data['callType'] == 'audio',
        isCaller: false, // ✅ user accepted = callee
        callerName: data["senderEmail"],
      ),
    ),
  );
}

Future<void> _declineCall(Map<String, dynamic> data) async {
  await FirebaseFirestore.instance
      .collection('calls')
      .doc(data['channelName'])
      .set({"status": "declined"}, SetOptions(merge: true));
}
