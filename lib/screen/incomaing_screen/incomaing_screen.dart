// incoming_call_page.dart
import 'package:flutter/material.dart';
import 'package:web_socket_app/screen/call_screen/call_screen.dart'; // Make sure this path is correct

class IncomingCallPage extends StatelessWidget {
  final String callerID;
  final String callerName;
  final String calleeID;
  final bool isAudioCall;
  final String callID; // Add this

  const IncomingCallPage({
    super.key,
    required this.callerID,
    required this.callerName,
    required this.calleeID,
    this.isAudioCall = false,
    required this.callID, // Require callID
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(
              "$callerName is ${isAudioCall ? 'audio' : 'video'} calling...", // More descriptive
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "decline",
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end),
                  onPressed: () {
                    // You might want to send a decline signal here
                    Navigator.pop(context);
                  },
                ),
                FloatingActionButton(
                  heroTag: "accept",
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallPage(
                          callerID: calleeID,
                          callerName: "Me",
                          calleeID: callerID,
                          isAudioCall: isAudioCall,
                          callID: callID,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
