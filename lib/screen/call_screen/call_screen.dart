
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:web_socket_app/utils/setting/setting.dart';

class CallPage extends StatefulWidget {
  final String callerID;
  final String callerName;
  final String calleeID;
  final bool isCaller;
  final bool isAudioCall;
  final String callID;
  final String? receiverPhotoUrl;

  const CallPage({
    super.key,
    required this.callerID,
    required this.callerName,
    required this.calleeID,
    required this.isCaller,
    required this.callID,
    this.isAudioCall = false,
    this.receiverPhotoUrl,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage>
    with SingleTickerProviderStateMixin {
  String status = "calling";
  bool isAudioCall = true;
  bool _callAccepted = false;
  bool _hasNavigatedToZego = false;
  int _dotCount = 0;
  Timer? _dotAnimationTimer;
  Timer? _callTimeoutTimer;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late StreamSubscription _callSub;

  @override
  void initState() {
    super.initState();
    isAudioCall = widget.isAudioCall;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _startDotAnimation();
    _startCallTimeout();
    _listenCallStatus();
  }

  void _startDotAnimation() {
    _dotAnimationTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  String get _callingDots => '.' * _dotCount;

  void _listenCallStatus() {
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callID)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) return;
          final newStatus = doc.data()?['status'] ?? 'calling';
          if (!mounted) return;

          setState(() {
            status = newStatus;
          });

          // center call overall
          if (newStatus == "declined") {
            print("📞 Call declined by receiver");
            if (mounted) Navigator.pop(context);
            return;
          }

          //End or timeout
          if (newStatus == "ended" || newStatus == "timeout") {
            if (mounted) Navigator.pop(context);
          }

          // Accepted → Navigate to Zego UI
          if (newStatus == "accepted" && !_hasNavigatedToZego) {
            _hasNavigatedToZego = true;

            _callAccepted = true;
            _joinZegoCall();
          }
        });
  }

  void _startCallTimeout() {
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () async {
      if (mounted && !_callAccepted) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.callID)
            .set({
              "status": "timeout",
              "endTime": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _joinZegoCall() {
    final currentUser = FirebaseAuth.instance.currentUser!;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ZegoUIKitPrebuiltCall(
          appID: ZegoConfig.appID,
          appSign: ZegoConfig.appSign,
          userID: currentUser.uid,
          userName: currentUser.email ?? currentUser.uid,
          callID: widget.callID,
          config: isAudioCall
              ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
        ),
      ),
    );
  }

  Future<void> _endCall() async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callID)
          .set({
            "status": "ended",
            "endTime": FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // caller side close
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      print("Error ending call: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dotAnimationTimer?.cancel();
    _callTimeoutTimer?.cancel();
    _callSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Waiting UI only for caller
    if (status == "calling" && widget.isCaller) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 100),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: widget.receiverPhotoUrl != null
                                  ? NetworkImage(widget.receiverPhotoUrl!)
                                  : null,
                              child: widget.receiverPhotoUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Calling${_callingDots}",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCallControls(),
              ],
            ),
          ),
        ),
      );
    }

    // Receiver automatically joins call
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildCallControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.grey.shade600,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // End call
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.red,
            child: IconButton(
              onPressed: () async {
                // await FirebaseFirestore.instance
                //     .collection('calls')
                //     .doc(widget.callID)
                //     .update({"status": "ended"});
                // if (mounted) Navigator.pop(context);
                _endCall();
              },
              icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
