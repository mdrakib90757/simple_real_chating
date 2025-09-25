import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_app/screen/call_screen/call_screen.dart';

import '../../utils/color.dart'; // Import your CallPage

class IncomingCallPage extends StatefulWidget {
  final String callerID;
  final String callerName;
  final String calleeID;
  final bool isAudioCall;
  final String callID;
  final String callerPhotoUrl;

  const IncomingCallPage({
    super.key,
    required this.callerID,
    required this.callerName,
    required this.calleeID,
    required this.isAudioCall,
    required this.callID,
    required this.callerPhotoUrl,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  List<String> _usedCallIDs = [];

  @override
  Widget build(BuildContext context) {
    print("📞 IncomingCallPage opened");
    print("callerID: ${widget.callerID}");
    print("callerName: ${widget.callerName}");
    print("calleeID: ${widget.calleeID}");
    print("callID: ${widget.callID}");
    print("isAudioCall: ${widget.isAudioCall}");
    final baseColor = getCallColor(widget.callID, _usedCallIDs);
    return Scaffold(
      backgroundColor: baseColor.withOpacity(0.5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.callerPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.callerPhotoUrl)
                  : null,
              child: widget.callerPhotoUrl.isEmpty
                  ? Icon(Icons.person, size: 80, color: Colors.white)
                  : null,
            ),
            SizedBox(height: 20),
            Text(
              widget.callerName,
              style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.isAudioCall
                  ? "Incoming Audio Call"
                  : "Incoming Video Call",
              style: TextStyle(fontSize: 20, color: Colors.white70),
            ),
            SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Accept button
                FloatingActionButton(
                  heroTag: 'acceptCall',
                  onPressed: () async {
                    // Update Firestore to notify caller
                    await FirebaseFirestore.instance
                        .collection('calls')
                        .doc(widget.callID)
                        .set({'status': 'accepted'}, SetOptions(merge: true));

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallPage(
                          callerID: widget.calleeID,
                          callerName:
                              FirebaseAuth.instance.currentUser?.email ??
                              widget.calleeID,
                          calleeID: widget.callerID,
                          isAudioCall: widget.isAudioCall,
                          callID: widget.callID,
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.green,
                  child: Icon(Icons.call, color: Colors.white, size: 30),
                ),

                // Decline button
                FloatingActionButton(
                  heroTag: 'rejectCall',
                  onPressed: () async {
                    // Notify caller
                    await FirebaseFirestore.instance
                        .collection('calls')
                        .doc(widget.callID)
                        .set({'status': 'declined'}, SetOptions(merge: true));

                    Navigator.pop(context);
                  },
                  backgroundColor: Colors.red,
                  child: Icon(Icons.call_end, color: Colors.white, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
