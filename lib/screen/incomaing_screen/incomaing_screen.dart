// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_callkit_incoming/entities/android_params.dart';
// import 'package:flutter_callkit_incoming/entities/call_event.dart';
// import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
// import 'package:flutter_callkit_incoming/entities/notification_params.dart';
// import 'package:uuid/uuid.dart';
// import '../../main.dart';
// import '../call_screen/call_screen.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
//
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// import 'package:flutter/material.dart';
// import 'package:uuid/uuid.dart';
// //
// // Future<void> showIncomingCall({
// //   required String callerName,
// //   String? callerPhotoUrl,
// //   required String callerID,
// //   required String calleeID,
// //   required bool isAudioCall,
// //   required String callID,
// // }) async {
// //
// //   print("🔔 showIncomingCall() called");
// //   print("➡️ Params:");
// //   print("  callerName: $callerName");
// //   print("  callerID: $callerID");
// //   print("  calleeID: $calleeID");
// //   print("  callID: $callID");
// //   print("  isAudioCall: $isAudioCall");
// //   print("  callerPhotoUrl: $callerPhotoUrl");
// //
// //   CallKitParams params = CallKitParams(
// //     id: callID, // use actual callID
// //     nameCaller: callerName,
// //     handle: "callerEmail",
// //     type: isAudioCall ? 0 : 1,
// //     duration: 30000,
// //     extra: {
// //       "callerID": callerID,
// //       "calleeID": calleeID,
// //       "callerPhotoUrl": callerPhotoUrl,
// //       "isAudioCall": isAudioCall,
// //       "callID": callID,
// //     },
// //     missedCallNotification: NotificationParams(
// //       showNotification: true,
// //       isShowCallback: true,
// //       subtitle: 'Missed call',
// //       callbackText: 'Call back',
// //     ),
// //     android: const AndroidParams(
// //       isCustomNotification: true,
// //       isShowLogo: false,
// //       backgroundColor: '#0955fa',
// //       actionColor: '#4CAF50',
// //       textColor: '#ffffff',
// //     ),
// //   );
// //
// //   print("📦 Final CallKitParams.extra => ${params.extra}");
// //   await FlutterCallkitIncoming.showCallkitIncoming(params);
// //   print("✅ showCallkitIncoming triggered");
// //
// // }
// //
// // void startOutgoingCall({
// //   required String callerName,
// //   required String callerEmail,
// //   required String callerID,
// //   required String calleeID,
// //   required String callID,
// //   required bool isAudio,
// // }) async {
// //   final uuid = Uuid().v4();
// //
// //   print("📞 startOutgoingCall() called");
// //   print("➡️ callerName: $callerName");
// //   print("➡️ callerEmail: $callerEmail");
// //   print("➡️ callerID: $callerID");
// //   print("➡️ calleeID: $calleeID");
// //   print("➡️ callID: $callID");
// //   print("➡️ isAudio: $isAudio");
// //   print("➡️ generated uuid: $uuid");
// //
// //   CallKitParams params = CallKitParams(
// //     id: uuid,
// //     nameCaller: callerName,
// //     handle: callerEmail,
// //     type: isAudio ? 0 : 1,
// //     android: const AndroidParams(isCustomNotification: true),
// //   );
// //
// //   print("📦 Final Outgoing CallKitParams.extra => ${params.extra}");
// //
// //   await FlutterCallkitIncoming.startCall(params);
// //   print("✅ startCall triggered");
// //
// //
// //   FlutterCallkitIncoming.onEvent.listen((event) async {
// //     if (event == null) return;
// //
// //     final extra = event.body?['extra'] ?? {};
// //     final callID = extra['callID'] ?? '';
// //     final callerID = extra['callerID'] ?? '';
// //     final calleeID = extra['calleeID'] ?? '';
// //     final callerName = extra['callerName'] ?? '';
// //     final isAudio = extra['isAudioCall'] ?? true;
// //
// //     switch (event.event) {
// //       case Event.actionCallAccept:
// //         print("✅ Receiver accepted call: $callID");
// //
// //         // 1️⃣ Update Firestore status
// //         await FirebaseFirestore.instance
// //             .collection('calls')
// //             .doc(callID)
// //             .set({'status': 'accepted'}, SetOptions(merge: true));
// //
// //         // 2️⃣ Navigate to CallPage
// //         Navigator.push(
// //           navigatorKey.currentState!.context,
// //           MaterialPageRoute(
// //             builder: (_) => CallPage(
// //               callerID: callerID,
// //               callerName: callerName,
// //               calleeID: calleeID,
// //               callID: callID,
// //               isAudioCall: isAudio,
// //               isCaller: false,
// //             ),
// //           ),
// //         );
// //         break;
// //
// //       case Event.actionCallDecline:
// //       case Event.actionCallEnded:
// //       case Event.actionCallTimeout:
// //         await FirebaseFirestore.instance
// //             .collection('calls')
// //             .doc(callID)
// //             .set({'status': 'ended'}, SetOptions(merge: true));
// //         break;
// //
// //       case Event.actionCallIncoming:
// //       // Show incoming call overlay
// //         showIncomingCall(
// //           callerName: callerName,
// //           callerID: callerID,
// //           calleeID: calleeID,
// //           callID: callID,
// //           isAudioCall: isAudio,
// //
// //         );
// //         break;
// //
// //       default:
// //         break;
// //     }
// //   });
// //
// // }
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
// //
//
// // void showIncomingCallOverlayWithNavigatorKey({
// //   required String callerName,
// //   String? callerPhotoUrl,
// //   required String callerID,
// //   required String calleeID,
// //   required bool isAudioCall,
// //   required String callID,
// // }) {
// //   final overlay = navigatorKey.currentState?.overlay;
// //   if (overlay == null) return;
// //
// //   late OverlayEntry overlayEntry;
// //   overlayEntry = OverlayEntry(
// //     builder: (context) => Positioned(
// //       top: 50,
// //       left: 16,
// //       right: 16,
// //       child: Material(
// //         color: Colors.transparent,
// //         child: _buildIncomingCallCard(
// //           callerName: callerName,
// //           callerPhotoUrl: callerPhotoUrl,
// //           overlayEntry: overlayEntry,
// //           callerID: callerID,
// //           calleeID: calleeID,
// //           isAudioCall: isAudioCall,
// //           callID: callID,
// //         ),
// //       ),
// //     ),
// //   );
// //
// //   overlay.insert(overlayEntry);
// //   Future.delayed(const Duration(seconds: 30), () {
// //     if (overlayEntry.mounted) overlayEntry.remove();
// //   });
// // }
// //
// // Widget _buildIncomingCallCard({
// //   required String callerName,
// //   String? callerPhotoUrl,
// //   required OverlayEntry overlayEntry,
// //   required String callerID,
// //   required String calleeID,
// //   required bool isAudioCall,
// //   required String callID,
// // }) {
// //   return Container(
// //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //     decoration: BoxDecoration(
// //       color: Colors.white.withOpacity(0.9),
// //       borderRadius: BorderRadius.circular(16),
// //     ),
// //     child: Column(
// //       children: [
// //         Row(
// //           children: [
// //             CircleAvatar(
// //               radius: 25,
// //               backgroundColor: Colors.grey.shade300,
// //               backgroundImage:
// //               callerPhotoUrl != null ? NetworkImage(callerPhotoUrl) : null,
// //               child: callerPhotoUrl == null ? const Icon(Icons.person) : null,
// //             ),
// //             const SizedBox(width: 12),
// //             Expanded(
// //               child: Text(
// //                 callerName,
// //                 style: const TextStyle(
// //                     color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500),
// //                 overflow: TextOverflow.ellipsis,
// //               ),
// //             ),
// //           ],
// //         ),
// //         const SizedBox(height: 12),
// //         Row(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             TextButton(
// //               style: TextButton.styleFrom(backgroundColor: Colors.red),
// //               onPressed: () async {
// //                 await FirebaseFirestore.instance
// //                     .collection('calls')
// //                     .doc(callID)
// //                     .update({"status": "declined"});
// //                 overlayEntry.remove();
// //               },
// //               child: Row(
// //                 children: const [
// //                   Icon(Icons.call_end, color: Colors.white),
// //                   SizedBox(width: 8),
// //                   Text("DECLINE", style: TextStyle(color: Colors.white)),
// //                 ],
// //               ),
// //             ),
// //             const SizedBox(width: 8),
// //             TextButton(
// //               style: TextButton.styleFrom(backgroundColor: Colors.green),
// //               onPressed: () async {
// //                 await FirebaseFirestore.instance
// //                     .collection('calls')
// //                     .doc(callID)
// //                     .update({"status": "accepted"});
// //                 overlayEntry.remove();
// //
// //                 Navigator.push(
// //                   navigatorKey.currentState!.context,
// //                   MaterialPageRoute(
// //                     builder: (_) => CallPage(
// //                       callerID: FirebaseAuth.instance.currentUser!.uid,
// //                       callerName: FirebaseAuth.instance.currentUser!.email ?? '',
// //                       calleeID: calleeID,
// //                       callID: callID,
// //                       isAudioCall: isAudioCall,
// //                       isCaller: false,
// //                     ),
// //                   ),
// //                 );
// //               },
// //               child: Row(
// //                 children: const [
// //                   Icon(Icons.call, color: Colors.white),
// //                   SizedBox(width: 8),
// //                   Text("ANSWER", style: TextStyle(color: Colors.white)),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ],
// //     ),
// //   );
// // }
//
// ///
// ///
//
// void showIncomingCallOverlayWithNavigatorKey({
//   required String callerName,
//   String? callerPhotoUrl,
//   required String callerID,
//   required String calleeID,
//   required bool isAudioCall,
//   required String callID,
// }) {
//   final overlay = navigatorKey.currentState?.overlay;
//   if (overlay == null) {
//     print("Overlay not ready yet");
//     return;
//   }
//
//   late OverlayEntry overlayEntry;
//   overlayEntry = OverlayEntry(
//     builder: (context) => Positioned(
//       top: 50,
//       left: 16,
//       right: 16,
//       child: Material(
//         color: Colors.transparent,
//         child: _buildIncomingCallCard(
//           callerName: callerName,
//           callerPhotoUrl: callerPhotoUrl,
//           overlayEntry: overlayEntry,
//           callerID: callerID, // pass actual callerID
//           calleeID: calleeID, // pass actual calleeID
//           isAudioCall: isAudioCall, // pass actual isAudioCall
//           callID: callID, // pass actual callID
//           onCallEnded: () {
//             // Pass the callback here
//             isCallActiveOrIncoming = false; // Reset the flag
//           },
//         ),
//       ),
//     ),
//   );
//
//   overlay.insert(overlayEntry);
//
//   Future.delayed(Duration(seconds: 30), () {
//     if (overlayEntry.mounted) overlayEntry.remove();
//     isCallActiveOrIncoming = false;
//   });
// }
//
// Future<String> getReceiverPhoto(String userID) async {
//   final doc = await FirebaseFirestore.instance
//       .collection('users')
//       .doc(userID)
//       .get();
//   if (doc.exists) {
//     return doc.data()?['photoUrl'] ?? '';
//   }
//   return '';
// }
//
// typedef CallInteractionCallback = void Function();
//
// Widget _buildIncomingCallCard({
//   required String callerName,
//   String? callerPhotoUrl,
//   required OverlayEntry overlayEntry,
//   required String callerID,
//   required String calleeID,
//   required bool isAudioCall,
//   required String callID,
//   CallInteractionCallback? onCallEnded,
// }) {
//   return Container(
//     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     decoration: BoxDecoration(
//       color: Colors.white.withOpacity(0.9),
//       borderRadius: BorderRadius.circular(16),
//     ),
//     child: Column(
//       children: [
//         Row(
//           children: [
//             CircleAvatar(
//               radius: 25,
//               backgroundColor: Colors.grey.shade300,
//               backgroundImage: callerPhotoUrl != null
//                   ? NetworkImage(callerPhotoUrl)
//                   : null,
//               child: callerPhotoUrl == null
//                   ? Icon(Icons.person, color: Colors.white)
//                   : null,
//             ),
//             SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 callerName,
//                 style: TextStyle(
//                   color: Colors.black,
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//           ],
//         ),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             TextButton(
//               style: TextButton.styleFrom(backgroundColor: Colors.red),
//               onPressed: () async {
//                 await FirebaseFirestore.instance
//                     .collection('calls')
//                     .doc(callID)
//                     .update({"status": "declined"});
//
//                 print("Call rejected by receiver");
//
//                 overlayEntry.remove();
//                 onCallEnded?.call();
//               },
//               child: Row(
//                 children: [
//                   Icon(Icons.phone, color: Colors.white),
//                   SizedBox(width: 8),
//                   Text("DECLINE", style: TextStyle(color: Colors.white)),
//                 ],
//               ),
//             ),
//             SizedBox(width: 8),
//             TextButton(
//               style: TextButton.styleFrom(backgroundColor: Colors.green),
//               onPressed: () async {
//                 //  Update Firestore to accepted
//                 await FirebaseFirestore.instance
//                     .collection('calls')
//                     .doc(callID)
//                     .update({"status": "accepted"});
//                 print("Call accepted");
//                 overlayEntry.remove();
//                 onCallEnded?.call();
//                 Navigator.push(
//                   navigatorKey.currentState!.context,
//                   MaterialPageRoute(
//                     builder: (_) => CallPage(
//                       callerID: FirebaseAuth.instance.currentUser!.uid,
//                       callerName:
//                           FirebaseAuth.instance.currentUser!.email ?? 'Unknown',
//                       calleeID: calleeID, // optional
//                       callID: callID,
//                       isAudioCall: isAudioCall,
//                       isCaller: false,
//                     ),
//                   ),
//                 );
//               },
//               child: Row(
//                 children: [
//                   Icon(Icons.phone, color: Colors.white),
//                   SizedBox(width: 8),
//                   Text("ANSWER", style: TextStyle(color: Colors.white)),
//                 ],
//               ),
//             ),
//
//             // FloatingActionButton(
//             //
//             //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
//             //   heroTag: 'acceptCall_$callerName',
//             //   mini: true,
//             //   backgroundColor: Colors.green,
//             //   onPressed: () async {
//             //     //  Update Firestore to accepted
//             //     await FirebaseFirestore.instance
//             //         .collection('calls')
//             //         .doc(callID)
//             //         .update({"status": "accepted"});
//             //     print("Call accepted");
//             //     overlayEntry.remove();
//             //
//             //     Navigator.push(
//             //       navigatorKey.currentState!.context,
//             //       MaterialPageRoute(
//             //         builder: (_) => CallPage(
//             //           callerID: FirebaseAuth.instance.currentUser!.uid,
//             //           callerName: FirebaseAuth.instance.currentUser!.email ?? 'Unknown',
//             //           calleeID: calleeID, // optional
//             //           callID: callID,
//             //           isAudioCall: isAudioCall,
//             //           isCaller: false,
//             //
//             //         ),
//             //       ),
//             //     );
//             //
//             //   },
//             //   child: Icon(Icons.call, color: Colors.white),
//             // ),
//             // SizedBox(width: 8),
//             // FloatingActionButton(
//             //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             //   heroTag: 'rejectCall_$callerName',
//             //   mini: true,
//             //   backgroundColor: Colors.red,
//             //   onPressed: ()async {
//             //     await FirebaseFirestore.instance
//             //         .collection('calls')
//             //         .doc(callID)
//             //         .update({"status": "ended"});
//             //     print("Call rejected");
//             //     overlayEntry.remove();
//             //   },
//             //   child: Icon(Icons.call_end, color: Colors.white),
//             // ),
//           ],
//         ),
//       ],
//     ),
//   );
// }
