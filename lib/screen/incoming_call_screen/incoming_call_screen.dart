import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// Ensure this matches your Agora App ID
const String AGORA_APP_ID = "c0aec9eab38544cf92e70a498c4f2a61";
// Use a secure token generation method in production. For testing, this temp token might work.
const String AGORA_TEMP_TOKEN =
    "007eJxTYLhbEnlr5dFj7HOffLApcNFuPaTHmCd0d676vKCbsl938p9TYEg2SExNtkxNTDK2MDUxSU6zNEo1N0g0sbRINkkzSjQzDMy7mNEQyMgwUUaEkZEBAkF8QYa0nNKSktSi+JTU3Pz4ovz8XAYGAGumJU8=";

class IncomingCallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideoCall;
  final String callerId;
  final String callerEmail;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.channelName,
    required this.isVideoCall,
    required this.callerId,
    required this.callerEmail,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 5,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blueGrey,

                // child: Text(
                //   widget.callerEmail[0].toUpperCase(),
                //   style: const TextStyle(fontSize: 40, color: Colors.white),
                // ),
                // backgroundImage: widget.callerPhotoUrl != null
                //     ? NetworkImage(widget.callerPhotoUrl!)
                //     : null,
              ),
              const SizedBox(height: 20),
              Text(
                widget.callerEmail,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.isVideoCall ? "Video Call" : "Audio Call",
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: "declineBtn", // Unique tag
                    onPressed: () {
                      widget.onDecline();
                    },
                    backgroundColor: Colors.red,
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  FloatingActionButton(
                    heroTag: "acceptBtn", // Unique tag
                    onPressed: () {
                      widget.onAccept();
                    },
                    backgroundColor: Colors.green,
                    child: Icon(
                      widget.isVideoCall ? Icons.video_call : Icons.call,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
