import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'
    show
        StatefulWidget,
        State,
        SingleTickerProviderStateMixin,
        AnimationController,
        Animation,
        BuildContext,
        Widget,
        Icon,
        SizedBox,
        TextStyle,
        EdgeInsets,
        BorderRadius,
        IconData,
        VoidCallback,
        Color,
        Tween,
        Curves,
        CurvedAnimation,
        Navigator,
        MaterialPageRoute,
        Colors,
        Icons,
        IconButton,
        AppBar,
        Alignment,
        LinearGradient,
        BoxDecoration,
        MainAxisAlignment,
        Transform,
        CircleAvatar,
        AnimatedBuilder,
        FontWeight,
        Offset,
        Shadow,
        Text,
        Row,
        Column,
        Center,
        Radius,
        Container,
        Positioned,
        Stack,
        Scaffold,
        UniqueKey,
        CircleBorder,
        FloatingActionButton,
        NetworkImage;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../utils/call_handler/call_handler.dart';
import '../../utils/color.dart';
import '../call_screen/call_screen.dart';

class CallingScreen extends StatefulWidget {
  final String callID;
  final String receiverID;
  final String receiverEmail;
  final bool isAudioCall;
  final String receiverPhotoUrl;

  const CallingScreen({
    super.key,
    required this.callID,
    required this.receiverID,
    required this.receiverEmail,
    this.isAudioCall = false,
    required this.receiverPhotoUrl,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with SingleTickerProviderStateMixin {
  bool _callAccepted = false;
  int _dotCount = 0;
  Timer? _dotAnimationTimer;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Timer? _callTimeoutTimer;
  late StreamSubscription _callSub;
  List<String> _usedCallIDs = [];

  @override
  void initState() {
    super.initState();
    _listenCallStatus();
    _startDotAnimation();
    _startRingtone();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true); // Repeat the animation back and forth

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Optional: Start a call timeout if the recipient doesn't answer
    _startCallTimeout();
  }

  void _startDotAnimation() {
    _dotAnimationTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _dotCount = (_dotCount + 1) % 4; // Cycles from 0 to 3
      });
    });
  }

  String get _callingDots {
    return '.' * _dotCount;
  }
  // void _listenCallStatus() {
  // _callSub =  FirebaseFirestore.instance
  //       .collection('calls')
  //       .doc(widget.callID)
  //       .snapshots()
  //       .listen((doc) {
  //     if (!mounted) return;
  //     final data = doc.data();
  //     if (data == null) return;
  //
  //     final status = data['status'];
  //     if (status == 'accepted' && !_callAccepted) {
  //       _callAccepted = true;
  //       _stopRingtone();
  //       print("callerID from Firestore: ${data['callerID']}");
  //       print("calleeID from Firestore: ${data['calleeID']}");
  //       // Navigate to actual CallPage
  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(
  //           builder: (_) => CallPage(
  //             callerID: (data['callerID'] ?? FirebaseAuth.instance.currentUser?.uid ?? '').toString(),
  //             callerName: FirebaseAuth.instance.currentUser?.email
  //                 ?? FirebaseAuth.instance.currentUser?.uid
  //                 ?? 'Unknown',
  //             calleeID: data['calleeID'] ?? widget.receiverID,
  //             callID: widget.callID,
  //             isAudioCall: widget.isAudioCall,
  //           ),
  //         ),
  //       );
  //     } else if (status == 'ended') {
  //       _stopRingtone();
  //       Navigator.pop(context); // exit CallingScreen
  //     }
  //   });
  // }

  void _listenCallStatus() {
    if (widget.callID.isEmpty) return;

    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callID)
        .snapshots()
        .listen((doc) {
          if (!mounted || doc.data() == null) return;

          final data = doc.data() as Map<String, dynamic>?; // cast to Map
          if (data == null) return;

          final callerID = data['callerID'] ?? FirebaseAuth.instance.currentUser!.uid;
          final calleeID = data['calleeID'] ?? widget.receiverID;
          final callerName = data['callerName'] ?? FirebaseAuth.instance.currentUser?.email ?? 'Unknown';
          final status = doc['status'];

          if (status == 'accepted' && !_callAccepted) {
            _callAccepted = true;
            _stopRingtone();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CallPage(
                  callerID: callerID,
                  callerName: callerName,
                  calleeID: calleeID,
                  callID: widget.callID,
                  isAudioCall: widget.isAudioCall,
                ),
              ),
            );
          } else if (status == 'ended' || status == 'timeout') {
            _stopRingtone();
            Navigator.pop(context);
          }
        });
  }
  // Example
  //   Future<void> startCall(String receiverID) async {
  //     final callDoc = FirebaseFirestore.instance.collection('calls').doc();
  //     await callDoc.set({
  //       "callerID": FirebaseAuth.instance.currentUser!.uid,
  //       "calleeID": receiverID,
  //       "status": "calling",
  //       "callType": "video",
  //       "startTime": FieldValue.serverTimestamp(),
  //     });
  //
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => CallingScreen(
  //           callID: callDoc.id,
  //           receiverID: receiverID,
  //           receiverEmail: "receiver@example.com",
  //           isAudioCall: false,
  //         ),
  //       ),
  //     );
  //   }

  Future<void> startCall(String receiverID) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverID)
        .get();

    final receiverEmail = userDoc['email'] ?? "Unknown";
    final receiverPhotoUrl = userDoc['photoUrl'] ?? "";

    final callDoc = FirebaseFirestore.instance.collection('calls').doc();
    await callDoc.set({
      "callerID": FirebaseAuth.instance.currentUser!.uid,
      "calleeID": receiverID,
      "status": "calling",
      "callType": "video",
      "startTime": FieldValue.serverTimestamp(),
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          callID: callDoc.id,
          receiverID: receiverID,
          receiverEmail: receiverEmail,
          receiverPhotoUrl: receiverPhotoUrl, // Pass photo URL
          isAudioCall: false,
        ),
      ),
    );
  }

  void _startCallTimeout() {
    // You can adjust the duration (e.g., 30 seconds)
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_callAccepted) {
        print("Call timed out for ${widget.callID}");
        FirebaseFirestore.instance
            .collection("calls")
            .doc(widget.callID)
            .set({
              "status": "timeout",
              "endTime": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .then((_) {
              if (mounted) {
                Navigator.pop(context); // Close calling screen
              }
            });
      }
    });
  }

  void _startRingtone() {
    FlutterRingtonePlayer().play(
      android: AndroidSounds.notification,
      ios: IosSounds.glass,
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );
  }

  void _stopRingtone() {
    FlutterRingtonePlayer().stop();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dotAnimationTimer?.cancel();
    _callTimeoutTimer?.cancel();
   _callSub.cancel();
    super.dispose();
  }

  void _endCall() async {
    _stopRingtone();
    await CallHandler.endCall(callID: widget.callID);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = getCallColor(widget.callID, _usedCallIDs);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Handle back button press if needed, though _cancelCall might be preferred.
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: () {
              // Handle add person
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Handle more options
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [baseColor.withOpacity(0.8), baseColor.withOpacity(1.0)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: CircleAvatar(
                          radius: 70,
                          backgroundImage: widget.receiverPhotoUrl.isNotEmpty
                              ? NetworkImage(widget.receiverPhotoUrl)
                              : null,
                          child: widget.receiverPhotoUrl.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  Text(
                    (widget.receiverEmail.isNotEmpty
                        ? widget.receiverEmail.split('@')[0]
                        : "Unknown"),
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2.0,
                          color: Colors.black38,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.isAudioCall ? "Calling" : "Video Calling",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        _callingDots,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallActionButton(
                      Icons.videocam_off,
                      () {},
                      isEnabled: false,
                    ),
                    _buildCallActionButton(
                      Icons.mic_off,
                      () {},
                      isEnabled: false,
                    ),
                    _buildCallActionButton(
                      Icons.flip_camera_ios,
                      () {},
                      isEnabled: false,
                    ),
                    _buildCallActionButton(
                      Icons.volume_up,
                      () {},
                      isEnabled: false,
                    ),
                    _buildCallActionButton(
                      Icons.call_end,
                      _endCall,
                      backgroundColor: Colors.red.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallActionButton(
    IconData icon,
    VoidCallback onPressed, {
    Color backgroundColor = Colors.white24,
    bool isEnabled = true,
  }) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: UniqueKey(),
          shape: CircleBorder(),
          onPressed: isEnabled ? onPressed : null,
          backgroundColor: isEnabled ? backgroundColor : Colors.grey.shade700,
          elevation: 0, // No shadow for this design
          child: Icon(icon, color: Colors.white, size: 15),
        ),
      ],
    );
  }
}
