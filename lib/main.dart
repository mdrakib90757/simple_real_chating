import 'dart:convert';
import 'dart:developer';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_app/firebase_options.dart';
import 'package:web_socket_app/screen/auth_screen/signIn_screen.dart';
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:web_socket_app/screen/splash_screen/splash_screen.dart';
import 'package:web_socket_app/utils/setting/setting.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'call_channel',
  'Incoming Calls',
  description: 'Used for incoming call notifications',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('ringtone'), // custom ringtone
  playSound: true,
  enableVibration: true,
);

// chat channel
const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Chat Notifications',
  description: 'This channel is used for important chat notifications.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

// NEW TOP-LEVEL FUNCTION FOR BACKGROUND NOTIFICATION RESPONSE
@pragma('vm:entry-point')
void notificationTapBackground(
  NotificationResponse notificationResponse,
) async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Re-initialize Firebase
  log(
    'background notification action tapped: ${notificationResponse.notificationResponseType}',
  );
  if (notificationResponse.payload != null) {
    log(
      'Background notification payload (top-level): ${notificationResponse.payload}',
    );
    final data = jsonDecode(notificationResponse.payload!);
    if (data['notificationType'] == 'chat') {
      log(
        'Background chat notification tapped! Sender ID: ${data['senderID']}',
      );
    } else if (data['notificationType'] == 'call') {
      _handleCallNotificationResponse(notificationResponse);
    }
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late List<CameraDescription> cameras;
const String kStoredUserIdKey = 'current_user_id';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request Notification Permissions (for Android 13+)
  final hasNotificationPermission =
      await FlutterCallkitIncoming.requestNotificationPermission({
        "title": "Notification Permission",
        "rationaleMessagePermission":
            "Notification permission is required to show call notifications.",
        "postNotificationMessageRequired":
            "Notification permission is required. Please allow notification permission from settings.",
      });
  log(
    "Notification Permission: $hasNotificationPermission",
    name: "PERMISSION",
  );
  await FlutterCallkitIncoming.requestFullIntentPermission();

  final canUseFullScreenIntent =
      await FlutterCallkitIncoming.canUseFullScreenIntent();
  log(
    "Can use Full Screen Intent: $canUseFullScreenIntent",
    name: "PERMISSION",
  );

  // Setup local notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // chat channel impl
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(chatChannel);

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('ic_stat_notification_bell');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: androidInit,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        log('Notification payload: ${response.payload}');
        final data = jsonDecode(response.payload!);
        if (data['notificationType'] == 'chat') {
          // Add the logic to navigate to the chat screen here
          log('Chat notification tapped! Sender ID: ${data['senderID']}');
          // navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatScreen(receiverId: data['senderID'])));
        } else if (data['notificationType'] == 'call') {
          // Existing logic for tapping call notifications
          _handleCallNotificationResponse(response);
        }
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  setupFirebaseListeners();
  setupCallkitListeners();

  cameras = await availableCameras();

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
  ZegoUIKitPrebuiltCallInvitationService().enterAcceptedOfflineCall();
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

String? currentChatUserId;
String? currentCallChannel;
bool isCallActiveOrIncoming = false;

/// ZegoCloud SDK Initialization
void _onUserLogin(String userID, String userName) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kStoredUserIdKey, userID);
  final invitationService = ZegoUIKitPrebuiltCallInvitationService();
  invitationService.init(
    appID: ZegoConfig.appID,
    appSign: ZegoConfig.appSign,
    userID: userID,
    userName: userName,
    plugins: [ZegoUIKitSignalingPlugin()],

    events: ZegoUIKitPrebuiltCallEvents(
      onHangUpConfirmation: (event, defaultAction) => defaultAction(),
    ),
    invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
      onIncomingCallTimeout: (String callID, ZegoCallUser caller) async {
        log("⏰ Missed call from ${caller.name}");
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caller.id)
            .get();

        final callerEmail = userDoc['email'] ?? 'unknown@email.com';
        final callerName = userDoc['name'] ?? caller.id;

        await FirebaseFirestore.instance
            .collection('calls')
            .doc(callID)
            .update({
              'status': 'missed',
              'callerId': caller.id,
              'callerName': callerName,
              'callerEmail': callerEmail,
              'missedBy': FirebaseAuth.instance.currentUser!.uid,
              'missedAt': FieldValue.serverTimestamp(),
            });
      },
      onIncomingMissedCallClicked:
          (
            String callID,
            ZegoCallUser caller,
            ZegoCallInvitationType callType,
            List<ZegoCallUser> callees,
            String customData,

            /// The default action is to dial back the missed call
            Future<void> Function() defaultAction,
          ) async {
            //await defaultAction.call();
            log('User clicked on missed call notification!');
            log('Call ID: $callID, Caller: ${caller.name} (${caller.id})');

            // Example: Show a confirmation dialog
            bool? confirmDialBack = await showDialog<bool>(
              context: navigatorKey.currentState!.context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Missed Call'),
                  content: Text(
                    'You missed a call from ${caller.name}. Do you want to call back?',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes'),
                    ),
                  ],
                );
              },
            );
            if (confirmDialBack == true) {
              log('Initiating dial back to ${caller.name}');
              await defaultAction
                  .call(); // Perform the default dial-back action
            } else {
              log('User chose not to dial back.');
              // You could navigate to a chat screen, or just dismiss
              // navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => ChatScreen(...)));
            }
          },

      onIncomingMissedCallDialBackFailed: () {
        /// Add your custom logic here.
      },
    ),
    config: ZegoCallInvitationConfig(
      /// Remember to set this to true here.
      canInvitingInCalling: true,
      endCallWhenInitiatorLeave: true,
      offline: ZegoCallInvitationOfflineConfig(
        autoEnterAcceptedOfflineCall: true,
      ),
      missedCall: ZegoCallInvitationMissedCallConfig(
        enabled: true,
        enableDialBack: true,
        notificationMessage: () {
          // No arguments here
          return "You missed a call"; // Or any other static message
        },
      ),
    ),

    // This is where Zego displays its incoming call UI
    requireConfig: (ZegoCallInvitationData data) {
      var config = (data.invitees.length > 1)
          ? ZegoCallType.videoCall == data.type
                ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                : ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
          : ZegoCallType.videoCall == data.type
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

      config.topMenuBar.buttons.insert(0, ZegoCallMenuBarButtonName.pipButton);
      config.pip.enableWhenBackground = true;

      // Modify your custom configurations here.
      config.duration.isVisible = true;
      config.duration.onDurationUpdate = (Duration duration) {
        if (duration.inSeconds == 5 * 60) {
          ZegoUIKitPrebuiltCallController().hangUp(
            navigatorKey.currentState!.context,
          );
        }
      };
      return config;
    },

    notificationConfig: ZegoCallInvitationNotificationConfig(
      androidNotificationConfig: ZegoCallAndroidNotificationConfig(
        showFullScreen: true,
        callChannel: ZegoCallAndroidNotificationChannelConfig(
          channelID: 'ZegoUIKit',
          channelName: 'Call Notifications',
          sound: 'call',
          icon: 'call',
        ),
        messageChannel: ZegoCallAndroidNotificationChannelConfig(
          channelID: 'Message',
          channelName: 'Message',
          sound: 'message',
          icon: 'message',
        ),
      ),
    ),
  );
  invitationService.enterAcceptedOfflineCall();
  _updateFCMToken(userID);

  // Add this listener for token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    if (userID == FirebaseAuth.instance.currentUser?.uid) {
      // Ensure current user
      FirebaseFirestore.instance
          .collection('users')
          .doc(userID)
          .update({
            'fcmToken': newToken,
            'lastLogin': FieldValue.serverTimestamp(),
          })
          .then((_) {
            print(
              'FCM Token refreshed and updated for user: $userID, token: $newToken',
            );
          })
          .catchError((error) {
            print(
              'Error updating refreshed FCM Token for user: $userID, error: $error',
            );
          });
    }
  });
}

// Update FCM token
Future<void> _updateFCMToken(String userID) async {
  String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  if (currentUserId != null) {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'fcmToken': fcmToken,
            'lastLogin': FieldValue.serverTimestamp(),
          });
      print('FCM Token updated: $fcmToken');
    }
  }
}

//
void setupCallkitListeners() {
  FlutterCallkitIncoming.onEvent.listen((event) async {
    if (event == null) return;
    final body = Map<String, dynamic>.from(event.body as Map);
    final extra = Map<String, dynamic>.from(body['extra'] as Map);
    final callID = extra['callID'] as String?;
    final invitees = List<String>.from(extra['invitees'] ?? []);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (callID == null || currentUser == null) return;

    switch (event.event) {
      case Event.actionCallAccept:
        print("Callkit Accept tapped for callID: $callID");

        // Update Firestore status
        await FirebaseFirestore.instance.collection('calls').doc(callID).update(
          {
            'status': 'accepted',
            'joinedBy': FieldValue.arrayUnion([currentUser.uid]),
          },
        );

        // Navigate to Zego call (group or one-on-one)
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ZegoUIKitPrebuiltCall(
              appID: ZegoConfig.appID,
              appSign: ZegoConfig.appSign,
              userID: currentUser.uid,
              userName: currentUser.email ?? currentUser.uid,
              callID: callID,
              config: invitees.length > 1
                  ? (extra['callType'] == 'video'
                        ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                        : ZegoUIKitPrebuiltCallConfig.groupVoiceCall())
                  : (extra['callType'] == 'video'
                        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()),
              events: ZegoUIKitPrebuiltCallEvents(
                onHangUpConfirmation: (event, defaultAction) => defaultAction(),
              ),
            ),
          ),
        );
        break;

      case Event.actionCallDecline:
      case Event.actionCallEnded:
      case Event.actionCallTimeout:
        print("☎️ Call ended/declined for callID: $callID");

        // Update Firestore for missed/ended call
        await FirebaseFirestore.instance.collection('calls').doc(callID).update(
          {
            'status': 'ended',
            'missedBy': FieldValue.arrayUnion([currentUser.uid]),
          },
        );
        await ZegoUIKitPrebuiltCallInvitationService().reject(
          customData: callID,
        );
        await FlutterCallkitIncoming.endCall(callID);
        break;

      default:
        break;
    }
  });
}

///Background message listener setup
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  log(
    "🔥 BG message received: ${message.messageId} | data: ${message.data}",
    name: "FCM_BG_HANDLER",
  );
  final data = message.data;
  log(
    "🔥 BG Handler: Received notificationType: ${data['notificationType']}",
    name: "FCM_BG_HANDLER",
  );

  if (data['notificationType'] == 'chat') {
    log(
      "💬 BG Handler: Handling as chat notification.",
      name: "FCM_BG_HANDLER",
    );
    final senderID = data['senderID'];
    final senderEmail = data['senderEmail'];
    final messageBody = data['body'] ?? 'New Message';
    final notificationTitle = data['title'] ?? "New Message";
    final senderName = data['senderName'] ?? senderEmail;

    // Show a local notification for background chat messages
    await flutterLocalNotificationsPlugin.show(
      senderID.hashCode, // Unique ID for each sender
      notificationTitle, // Use the title from data payload
      messageBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          chatChannel.id, // Use the new chat channel
          chatChannel.name,
          channelDescription: chatChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.message,
          // sound: RawResourceAndroidNotificationSound('message'),
          // playSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  } else if (data['notificationType'] == 'call' ||
      data['notificationType'] == 'group_call') {
    // Add 'group_call' explicitly
    log(
      "📞 BG Handler: Handling as call/group_call notification...",
      name: "FCM_BG_HANDLER",
    );
    _handleCallNotification(data);
  } else {
    log(
      "❓ BG Handler: Unknown notificationType: ${data['notificationType']}",
      name: "FCM_BG_HANDLER",
    );
  }
}

void setupFirebaseListeners() {
  FirebaseMessaging.onMessage.listen((message) {
    log(
      "Foreground message received: ${message.messageId} | data: ${message.data}",
    );
    final data = message.data;
    if (data['notificationType'] == 'chat') {
      log("Calling _handleChatNotification for foreground chat...");
      _handleChatNotification(data);
    }
  });

  // App opened from background by tapping notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    log(
      "App opened from background: ${message.messageId} | data: ${message.data}",
    );
    final data = message.data;

    if (data['notificationType'] == 'call') {
      _handleCallNotification(data);
    } else if (data["notificationType"] == 'chat') {
      _handleChatNotificationResponse(
        NotificationResponse(
          payload: jsonEncode(data),
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
        ),
      );
    }
  });

  // App opened from terminated state
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      log(
        "App opened from terminated state: ${message.messageId} | data: ${message.data}",
      );
      final data = message.data;
      if (data['notificationType'] == 'call') {
        _handleCallNotification(data);
      } else if (['notificationType'] == 'chat') {
        _handleChatNotificationResponse(
          NotificationResponse(
            payload: jsonEncode(data),
            notificationResponseType:
                NotificationResponseType.selectedNotificationAction,
          ),
        );
      }
    }
  });
}

Future<Map<String, dynamic>> _getUserInfo(String userID) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userID)
      .get();
  return doc.data() ?? {};
}

// Handle call notification (overlay / screen)
Future<void> _handleCallNotification(Map<String, dynamic> data) async {
  log(
    "📞 CALL_HANDLER: Inside _handleCallNotification. Data: $data",
    name: "CALL_HANDLER",
  );

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    log(
      "❌ _handleCallNotification: No current user, returning.",
      name: "CALL_HANDLER",
    );
    return;
  }

  if (currentUser.uid == data['senderID']) {
    log(
      "❌ _handleCallNotification: Current user (${currentUser.uid}) is the sender (${data['senderID']}). Ignoring incoming call notification for caller.",
      name: "CALL_HANDLER",
    );

    return;
  }

  // Ensure 'channelName' is present and not null
  if (data['channelName'] == null) {
    log(
      "❌ CALL_HANDLER: 'channelName' is missing in FCM data. Cannot show Callkit.",
      name: "CALL_HANDLER",
    );
    return;
  }

  final userInfo = await _getUserInfo(data['senderID']);
  final callerName =
      userInfo['displayName'] ??
      userInfo['name'] ??
      data['senderEmail'] ??
      'Unknown';
  final callerPhoto = userInfo['photoUrl'] ?? "";

  List<String> inviteesList = [];

  try {
    if (data['invitees'] != null) {
      // inviteesList = (jsonDecode(data['invitees']) as List)
      //     .map((e) => e.toString())
      //     .toList();
      if (data['invitees'] is String) {
        inviteesList = (jsonDecode(data['invitees']) as List)
            .map((e) => e.toString())
            .toList();
      } else if (data['invitees'] is List) {
        inviteesList = (data['invitees'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }
    log(
      "✅ CALL_HANDLER: inviteesList after decoding: $inviteesList",
      name: "CALL_HANDLER",
    );
  } catch (e) {
    log(
      "⚠️ CALL_HANDLER: Error decoding invitees: $e, data['invitees'] (type: ${data['invitees'].runtimeType}): ${data['invitees']}",
      name: "CALL_HANDLER",
    );
  }

  final params = CallKitParams(
    id: data['channelName'],
    nameCaller: callerName,
    appName: 'Chatter',
    avatar: callerPhoto,
    handle: data['senderEmail'] ?? 'caller',
    type: data['callType'] == 'audio' ? 0 : 1,
    textAccept: 'Accept',
    textDecline: 'Decline',
    extra: {
      "callerID": data['senderID'],
      "calleeID": currentUser.uid,
      "callID": data['channelName'],
      "invitees": inviteesList,
      "callType": data['callType'],
    },
    missedCallNotification: NotificationParams(
      showNotification: true,
      isShowCallback: true,
      subtitle: 'Missed call',
      callbackText: 'Call back',
    ),
    callingNotification: NotificationParams(
      showNotification: true,
      isShowCallback: true,
      subtitle: 'Calling...',
      callbackText: 'Hang Up',
    ),
    android: AndroidParams(
      incomingCallNotificationChannelName: channel.name,
      ringtonePath: 'ringtone',
      logoUrl: 'https://i.pravatar.cc/100',
      isCustomNotification: true,
      missedCallNotificationChannelName: "Missed Call",
      isShowCallID: false,
      isShowFullLockedScreen: true,

      //fullScreenIntent: true, // Add this explicitly
      //foregroundService: true, // Add this explicitly
    ),
  );
  log(
    "✅ CallKitParams prepared. Displaying incoming call...",
    name: "CALL_HANDLER",
  );
  // await Future.delayed(const Duration(milliseconds: 500));
  await FlutterCallkitIncoming.showCallkitIncoming(params);
  log("🎉 CallKit incoming call displayed.", name: "CALL_HANDLER");
}

// Handle chat notification
void _handleChatNotification(Map<String, dynamic> data) async {
  final senderID = data['senderID'];
  final senderEmail = data['senderEmail'];
  final messageBody =
      data['body'] ?? 'New Message'; // <-- 'body' from data payload
  final notificationTitle =
      data['title'] ?? "New Message"; // <-- 'title' from data payload
  final senderName = data['senderName'] ?? senderEmail;

  log(
    "Attempting to show local notification for chat. Sender: $senderName, Body: $messageBody",
  );
  await flutterLocalNotificationsPlugin.show(
    senderID.hashCode, // Unique ID for each sender
    notificationTitle, // Use the title from data payload
    messageBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        chatChannel.id,
        chatChannel.name,
        channelDescription: chatChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: false,
        category: AndroidNotificationCategory.message,
        //sound: RawResourceAndroidNotificationSound('message'),
        playSound: true,
      ),
    ),
    payload: jsonEncode(data),
  );
}

// Notification response handler
void _handleChatNotificationResponse(NotificationResponse response) async {
  if (response.payload == null) return;
  final data = jsonDecode(response.payload!);

  log('Notification response payload: ${response.payload}');

  final notificationType = data['notificationType'];
  if (notificationType == 'chat') {
    final senderID = data['senderID'];
    // navigatorKey.currentState?.push(MaterialPageRoute(builder: (context) => ChatScreen(receiverId: senderID)));
    log('Chat notification response handled! Sender ID: $senderID');
  }
}

void _handleCallNotificationResponse(NotificationResponse response) async {
  if (response.payload == null) return;
  final data = jsonDecode(response.payload!);
  final action = data['action'] ?? 'none';
  final callID = data['channelName'];
  final callTypeString = data['callType'] ?? 'voice';
  final isVideo = callTypeString.toLowerCase() == 'video';
  final zegoCallType = isVideo
      ? ZegoCallType.videoCall
      : ZegoCallType.voiceCall;

  if (FirebaseAuth.instance.currentUser == null) return;

  if (action == 'ACCEPT_CALL') {
    log('Call notification ACCEPT_CALL tapped!');
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ZegoUIKitPrebuiltCall(
          appID: ZegoConfig.appID,
          appSign: ZegoConfig.appSign,
          userID: FirebaseAuth.instance.currentUser!.uid,
          userName:
              FirebaseAuth.instance.currentUser!.email ??
              FirebaseAuth.instance.currentUser!.uid,
          callID: callID,
          config: zegoCallType == ZegoCallType.videoCall
              ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
        ),
      ),
    );
  } else if (action == 'DECLINE_CALL') {
    log('Call notification DECLINE_CALL tapped!');
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callID).update({
        'status': 'ended',
        'endedBy': FirebaseAuth.instance.currentUser!.uid,
        'endTime': FieldValue.serverTimestamp(),
      });
      await ZegoUIKitPrebuiltCallInvitationService().reject(customData: callID);
      await FlutterCallkitIncoming.endCall(callID);
    } catch (e) {
      log("❌ Error declining call: $e");
    }
  } else {
    // tapped on notification itself (general tap)
    log('Call notification tapped (general)! Call ID: $callID');
    // If you want to handle a general tap on the call notification differently
    // For now, it will do nothing extra if not accept/decline actions.
  }
}
