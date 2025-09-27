//
//
//
// <<<<<<< Updated upstream
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:web_socket_app/screen/call_screen/call_screen.dart';
// =======
//
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
//
// import '../call_screen/call_screen.dart';
// >>>>>>> Stashed changes
//
// import '../../utils/color.dart'; // Import your CallPage
//
// class IncomingCallPage extends StatefulWidget {
// final String callerID;
// final String callerName;
// final String calleeID;
// final bool isAudioCall;
// final String callID;
// <<<<<<< Updated upstream
// final String callerPhotoUrl;
// =======
// >>>>>>> Stashed changes
//
// const IncomingCallPage({
// super.key,
// required this.callerID,
// required this.callerName,
// required this.calleeID,
// required this.isAudioCall,
// required this.callID,
// <<<<<<< Updated upstream
// required this.callerPhotoUrl,
// =======
// >>>>>>> Stashed changes
// });
//
// @override
// State<IncomingCallPage> createState() => _IncomingCallPageState();
// }
//
// class _IncomingCallPageState extends State<IncomingCallPage> {
// List<String> _usedCallIDs = [];
//
// @override
// Widget build(BuildContext context) {
// print("📞 IncomingCallPage opened");
// print("callerID: ${widget.callerID}");
// print("callerName: ${widget.callerName}");
// print("calleeID: ${widget.calleeID}");
// print("callID: ${widget.callID}");
// print("isAudioCall: ${widget.isAudioCall}");
// final baseColor = getCallColor(widget.callID, _usedCallIDs);
// return Scaffold(
// <<<<<<< Updated upstream
// backgroundColor: baseColor.withOpacity(0.5),
// =======
// backgroundColor: Colors.black,
// >>>>>>> Stashed changes
// body: Center(
// child: Column(
// mainAxisAlignment: MainAxisAlignment.center,
// children: [
// CircleAvatar(
// radius: 60,
// <<<<<<< Updated upstream
// backgroundImage: widget.callerPhotoUrl.isNotEmpty
// ? NetworkImage(widget.callerPhotoUrl)
//     : null,
// child: widget.callerPhotoUrl.isEmpty
// ? Icon(Icons.person, size: 80, color: Colors.white)
//     : null,
// ),
// SizedBox(height: 20),
// Text(
// widget.callerName,
// style: TextStyle(
// fontSize: 28,
// color: Colors.white,
// fontWeight: FontWeight.bold,
// ),
// ),
// Text(
// widget.isAudioCall
// ? "Incoming Audio Call"
//     : "Incoming Video Call",
// =======
// backgroundColor: Colors.blueGrey,
// child: Icon(Icons.person, size: 80, color: Colors.white),
// ),
// SizedBox(height: 20),
// Text(
// callerName,
// style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
// ),
// Text(
// isAudioCall ? "Incoming Audio Call" : "Incoming Video Call",
// >>>>>>> Stashed changes
// style: TextStyle(fontSize: 20, color: Colors.white70),
// ),
// SizedBox(height: 50),
// Row(
// mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// children: [
// <<<<<<< Updated upstream
// // Accept button
// FloatingActionButton(
// heroTag: 'acceptCall',
// onPressed: () async {
// // Update Firestore to notify caller
// await FirebaseFirestore.instance
//     .collection('calls')
//     .doc(widget.callID)
//     .set({'status': 'accepted'}, SetOptions(merge: true));
//
// Navigator.pushReplacement(
// context,
// MaterialPageRoute(
// builder: (_) => CallPage(
// callerID: widget.calleeID,
// callerName:
// FirebaseAuth.instance.currentUser?.email ??
// widget.calleeID,
// calleeID: widget.callerID,
// isAudioCall: widget.isAudioCall,
// callID: widget.callID,
// =======
// // Reject Call Button
// FloatingActionButton(
// heroTag: 'rejectCall', // Unique tag
// onPressed: () {
// // TODO: Implement logic to decline the call and potentially send a notification back
// Navigator.pop(context); // Go back from this screen
// },
// backgroundColor: Colors.red,
// child: Icon(Icons.call_end, color: Colors.white, size: 30),
// ),
// // Accept Call Button
// FloatingActionButton(
// heroTag: 'acceptCall', // Unique tag
// onPressed: () {
// // Navigate to the CallPage to join the Zego call
// Navigator.pushReplacement( // Use pushReplacement to replace this screen
// context,
// MaterialPageRoute(
// builder: (context) =>  CallPage(
// // For the callee, their own ID is the callerID for Zego,
// // as they are now "calling" into the Zego session.
// callerID: calleeID,
// callerName: FirebaseAuth.instance.currentUser?.email ?? calleeID,
// calleeID: callerID, // The original caller
// isAudioCall: isAudioCall,
// callID: callID, // Use the received callID
// >>>>>>> Stashed changes
// ),
// ),
// );
// },
// backgroundColor: Colors.green,
// child: Icon(Icons.call, color: Colors.white, size: 30),
// <<<<<<< Updated upstream
// ),
//
// // Decline button
// FloatingActionButton(
// heroTag: 'rejectCall',
// onPressed: () async {
// // Notify caller
// await FirebaseFirestore.instance
//     .collection('calls')
//     .doc(widget.callID)
//     .set({'status': 'declined'}, SetOptions(merge: true));
//
// Navigator.pop(context);
// },
// backgroundColor: Colors.red,
// child: Icon(Icons.call_end, color: Colors.white, size: 30),
// =======
// >>>>>>> Stashed changes
// ),
// ],
// ),
// ],
// ),
// ),
// );
// }
// }
//
//
//

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../call_screen/call_screen.dart';

Future<void> showIncomingCallOverlayWithNavigatorKey({
  required String callerName,
  String? callerPhotoUrl,
  required String callerID,
  required String calleeID,
  required bool isAudioCall,
  required String callID,
}) async {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) {
    print("Overlay not ready yet");
    return;
  }

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: _buildIncomingCallCard(
          callerName: callerName,
          callerPhotoUrl: callerPhotoUrl,
          overlayEntry: overlayEntry,
          callerID: callerID, // pass actual callerID
          calleeID: calleeID, // pass actual calleeID
          isAudioCall: isAudioCall, // pass actual isAudioCall
          callID: callID, // pass actual callID
          onCallEnded: () { // Pass the callback here
            isCallActiveOrIncoming = false; // Reset the flag
          },
        ),
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(Duration(seconds: 30), () {
    if (overlayEntry.mounted) overlayEntry.remove();
    isCallActiveOrIncoming = false;
  });
}

Future<String> getReceiverPhoto(String userID) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userID)
      .get();
  if (doc.exists) {
    return doc.data()?['photoUrl'] ?? '';
  }
  return '';
}


typedef CallInteractionCallback = void Function();

Widget _buildIncomingCallCard({
  required String callerName,
  String? callerPhotoUrl,
  required OverlayEntry overlayEntry,
  required String callerID,
  required String calleeID,
  required bool isAudioCall,
  required String callID,
  CallInteractionCallback? onCallEnded
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: callerPhotoUrl != null
                  ? NetworkImage(callerPhotoUrl)
                  : null,
              child: callerPhotoUrl == null
                  ? Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                callerName,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('calls')
                    .doc(callID)
                    .update({"status": "declined"});

                print("Call rejected by receiver");

                overlayEntry.remove();
                onCallEnded?.call();
              },
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.white),
                  SizedBox(width: 8),
                  Text("DECLINE", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                //  Update Firestore to accepted
                await FirebaseFirestore.instance
                    .collection('calls')
                    .doc(callID)
                    .update({"status": "accepted"});
                print("Call accepted");
                overlayEntry.remove();
                onCallEnded?.call();
                Navigator.push(
                  navigatorKey.currentState!.context,
                  MaterialPageRoute(
                    builder: (_) => CallPage(
                      callerID: FirebaseAuth.instance.currentUser!.uid,
                      callerName:
                          FirebaseAuth.instance.currentUser!.email ?? 'Unknown',
                      calleeID: calleeID, // optional
                      callID: callID,
                      isAudioCall: isAudioCall,
                      isCaller: false,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.white),
                  SizedBox(width: 8),
                  Text("ANSWER", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),

            // FloatingActionButton(
            //
            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            //   heroTag: 'acceptCall_$callerName',
            //   mini: true,
            //   backgroundColor: Colors.green,
            //   onPressed: () async {
            //     //  Update Firestore to accepted
            //     await FirebaseFirestore.instance
            //         .collection('calls')
            //         .doc(callID)
            //         .update({"status": "accepted"});
            //     print("Call accepted");
            //     overlayEntry.remove();
            //
            //     Navigator.push(
            //       navigatorKey.currentState!.context,
            //       MaterialPageRoute(
            //         builder: (_) => CallPage(
            //           callerID: FirebaseAuth.instance.currentUser!.uid,
            //           callerName: FirebaseAuth.instance.currentUser!.email ?? 'Unknown',
            //           calleeID: calleeID, // optional
            //           callID: callID,
            //           isAudioCall: isAudioCall,
            //           isCaller: false,
            //
            //         ),
            //       ),
            //     );
            //
            //   },
            //   child: Icon(Icons.call, color: Colors.white),
            // ),
            // SizedBox(width: 8),
            // FloatingActionButton(
            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            //   heroTag: 'rejectCall_$callerName',
            //   mini: true,
            //   backgroundColor: Colors.red,
            //   onPressed: ()async {
            //     await FirebaseFirestore.instance
            //         .collection('calls')
            //         .doc(callID)
            //         .update({"status": "ended"});
            //     print("Call rejected");
            //     overlayEntry.remove();
            //   },
            //   child: Icon(Icons.call_end, color: Colors.white),
            // ),
          ],
        ),
      ],
    ),
  );
}

