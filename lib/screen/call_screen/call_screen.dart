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
    print("📡 Listening for call status updates: callID=${widget.callID}");
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callID)
        .snapshots()
        .listen((doc) {
          print("⚠️ Call doc not found for callID=${widget.callID}");
          if (!doc.exists) return;
          final newStatus = doc.data()?['status'] ?? 'calling';
          print(
            "📞 Firestore update: callID=${widget.callID}, status=$newStatus",
          );
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

          // If receiver declines or call ends
          if (status == "declined" ||
              status == "ended" ||
              status == "timeout") {
            print("☎️ Call finished with status=$status");
            if (mounted && Navigator.canPop(context)) Navigator.pop(context);
            return;
          }

          // Accepted → Navigate to Zego UI
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
    print(
      "🚀 Joining Zego call: callID=${widget.callID}, user=${currentUser.uid}",
    );

    //final currentUser = FirebaseAuth.instance.currentUser!;
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

  //accept function
  Future<void> _acceptCall() async {
    print("👉 Accepting call: ${widget.callID}");
    await FirebaseFirestore.instance.collection('calls').doc(widget.callID).set(
      {'status': 'accepted'},
      SetOptions(merge: true),
    );
  }

  Future<void> _declineCall() async {
    print("👉 Declining call: ${widget.callID}");
    await FirebaseFirestore.instance.collection('calls').doc(widget.callID).set(
      {'status': 'declined'},
      SetOptions(merge: true),
    );
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _endCall() async {
    try {
      print("👉 Ending call: ${widget.callID}");
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
      print("❌ Error ending call: $e");
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

// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
// import 'package:web_socket_app/utils/setting/setting.dart';
//
// class CallPage extends StatefulWidget {
//   final String callerID;
//   final String callerName;
//   final String calleeID;
//   final bool isCaller;
//   final bool isAudioCall;
//   final String callID;
//   final String? receiverPhotoUrl;
//
//   const CallPage({
//     super.key,
//     required this.callerID,
//     required this.callerName,
//     required this.calleeID,
//     required this.isCaller,
//     required this.callID,
//     this.isAudioCall = false,
//     this.receiverPhotoUrl,
//   });
//
//   @override
//   State<CallPage> createState() => _CallPageState();
// }
//
// class _CallPageState extends State<CallPage> with SingleTickerProviderStateMixin {
//   String status = "calling";
//   bool isAudioCall = true;
//   bool _callAccepted = false;
//   bool _hasNavigatedToZego = false;
//   int _dotCount = 0;
//   Timer? _dotAnimationTimer;
//   Timer? _callTimeoutTimer;
//   late AnimationController _animationController;
//   late Animation<double> _pulseAnimation;
//   late StreamSubscription _callSub;
//
//   @override
//   void initState() {
//     super.initState();
//     isAudioCall = widget.isAudioCall;
//
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     )..repeat(reverse: true);
//
//     _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );
//
//     _startDotAnimation();
//     _startCallTimeout();
//     _listenCallStatus();
//   }
//
//   void _startDotAnimation() {
//     _dotAnimationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
//       if (!mounted) return;
//       setState(() {
//         _dotCount = (_dotCount + 1) % 4;
//       });
//     });
//   }
//
//   String get _callingDots => '.' * _dotCount;
//
//   void _listenCallStatus() {
//     print("📡 Listening for call status updates: callID=${widget.callID}");
//     _callSub = FirebaseFirestore.instance
//         .collection('calls')
//         .doc(widget.callID)
//         .snapshots()
//         .listen((doc) {
//       if (!doc.exists) return;
//
//       final newStatus = doc.data()?['status'] ?? 'calling';
//       print("📞 Firestore update: callID=${widget.callID}, status=$newStatus");
//
//       if (!mounted) return;
//       setState(() {
//         status = newStatus;
//       });
//
//       // Ended, declined, or timeout → close
//       if (status == "declined" || status == "ended" || status == "timeout") {
//         print("☎️ Call finished with status=$status");
//         if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//         return;
//       }
//
//       // Accepted → navigate to Zego
//       if (status == "accepted" && !_hasNavigatedToZego) {
//         _hasNavigatedToZego = true;
//         _joinZegoCall();
//       }
//     });
//   }
//
//   void _startCallTimeout() {
//     _callTimeoutTimer = Timer(const Duration(seconds: 30), () async {
//       final doc = await FirebaseFirestore.instance.collection('calls').doc(widget.callID).get();
//       final currentStatus = doc.data()?['status'] ?? 'calling';
//
//       if (mounted && currentStatus == 'calling') {
//         await FirebaseFirestore.instance
//             .collection('calls')
//             .doc(widget.callID)
//             .set({
//           "status": "timeout",
//           "endTime": FieldValue.serverTimestamp(),
//         }, SetOptions(merge: true));
//
//         if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//         print("⏰ Call timeout triggered");
//       } else {
//         print("⚠️ Timeout skipped, current status=$currentStatus");
//       }
//     });
//   }
//
//   void _joinZegoCall() {
//     final currentUser = FirebaseAuth.instance.currentUser!;
//     print("🚀 Joining Zego call: callID=${widget.callID}, user=${currentUser.uid}");
//
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ZegoUIKitPrebuiltCall(
//           appID: ZegoConfig.appID,
//           appSign: ZegoConfig.appSign,
//           userID: currentUser.uid,
//           userName: currentUser.email ?? currentUser.uid,
//           callID: widget.callID,
//           config: isAudioCall
//               ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
//               : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _acceptCall() async {
//     final doc = await FirebaseFirestore.instance.collection('calls').doc(widget.callID).get();
//     final currentStatus = doc.data()?['status'] ?? 'calling';
//
//     if (currentStatus == 'calling') {
//       await FirebaseFirestore.instance.collection('calls').doc(widget.callID).set(
//         {'status': 'accepted'},
//         SetOptions(merge: true),
//       );
//       _callAccepted = true;
//       print("✅ Call accepted");
//     } else {
//       print("⚠️ Cannot accept call, current status=$currentStatus");
//       if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//     }
//   }
//
//   Future<void> _declineCall() async {
//     await FirebaseFirestore.instance.collection('calls').doc(widget.callID).set(
//       {'status': 'declined'},
//       SetOptions(merge: true),
//     );
//     if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//     print("❌ Call declined");
//   }
//
//   Future<void> _endCall() async {
//     try {
//       await FirebaseFirestore.instance.collection('calls').doc(widget.callID).set({
//         "status": "ended",
//         "endTime": FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
//
//       if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//       print("📴 Call ended");
//     } catch (e) {
//       print("❌ Error ending call: $e");
//     }
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     _dotAnimationTimer?.cancel();
//     _callTimeoutTimer?.cancel();
//     _callSub.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (status == "calling" && widget.isCaller) {
//       return Scaffold(
//         body: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blueAccent, Colors.purpleAccent],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//           child: SafeArea(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 100),
//                   child: Column(
//                     children: [
//                       AnimatedBuilder(
//                         animation: _pulseAnimation,
//                         builder: (context, child) {
//                           return Transform.scale(
//                             scale: _pulseAnimation.value,
//                             child: CircleAvatar(
//                               radius: 25,
//                               backgroundColor: Colors.grey.shade300,
//                               backgroundImage: widget.receiverPhotoUrl != null
//                                   ? NetworkImage(widget.receiverPhotoUrl!)
//                                   : null,
//                               child: widget.receiverPhotoUrl == null
//                                   ? const Icon(
//                                 Icons.person,
//                                 color: Colors.white,
//                               )
//                                   : null,
//                             ),
//                           );
//                         },
//                       ),
//                       const SizedBox(height: 20),
//                       Text(
//                         widget.callerName,
//                         style: const TextStyle(
//                           fontSize: 18,
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         "Calling${_callingDots}",
//                         style: const TextStyle(
//                           fontSize: 18,
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 _buildCallControls(),
//               ],
//             ),
//           ),
//         ),
//       );
//     }
//
//     // Receiver waiting UI
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const CircularProgressIndicator(),
//             const SizedBox(height: 20),
//             Text(
//               widget.isCaller ? "Calling..." : "Incoming Call",
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             if (!widget.isCaller)
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green, shape: const CircleBorder()),
//                     onPressed: _acceptCall,
//                     child: const Icon(Icons.call, size: 30),
//                   ),
//                   const SizedBox(width: 20),
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.red, shape: const CircleBorder()),
//                     onPressed: _declineCall,
//                     child: const Icon(Icons.call_end, size: 30),
//                   ),
//                 ],
//               )
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildCallControls() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(30),
//         color: Colors.grey.shade600,
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           CircleAvatar(
//             radius: 25,
//             backgroundColor: Colors.red,
//             child: IconButton(
//               onPressed: _endCall,
//               icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
// import 'package:web_socket_app/utils/setting/setting.dart';
//
// class CallPage extends StatefulWidget {
//   final String callerID;
//   final String callerName;
//   final String calleeID;
//   final bool isCaller;
//   final bool isAudioCall;
//   final String callID;
//   final String? receiverPhotoUrl;
//
//   const CallPage({
//     super.key,
//        required this.callerID,
//     required this.callerName,
//     required this.calleeID,
//     required this.isCaller,
//     required this.callID,
//     this.isAudioCall = false,
//     this.receiverPhotoUrl,
//   });
//
//   @override
//   State<CallPage> createState() => _CallPageState();
// }
// class _CallPageState extends State<CallPage> {
//   bool _hasNavigatedToZego = false;
//   late StreamSubscription _callSub;
//
//   @override
//   void initState() {
//     super.initState();
//     _listenCallStatus();
//   }
//
//   void _listenCallStatus() {
//     _callSub = FirebaseFirestore.instance
//         .collection('calls')
//         .doc(widget.callID)
//         .snapshots()
//         .listen((doc) {
//       if (!doc.exists) return;
//       final status = doc.data()?['status'] ?? 'calling';
//
//       // Accepted → join Zego UI
//       if (!_hasNavigatedToZego && status == "accepted") {
//         _hasNavigatedToZego = true;
//         _joinZegoCall();
//       }
//
//       // Declined / Ended / Timeout → close CallPage
//       if (status == "declined" || status == "ended" || status == "timeout") {
//         if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//       }
//     });
//   }
//
//   void _joinZegoCall() {
//     final currentUser = FirebaseAuth.instance.currentUser!;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (_) => ZegoUIKitPrebuiltCall(
//           appID: ZegoConfig.appID,
//           appSign: ZegoConfig.appSign,
//           userID: currentUser.uid,
//           userName: currentUser.email ?? currentUser.uid,
//           callID: widget.callID,
//           config: widget.isAudioCall
//               ? ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
//               : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall(),
//         ),
//       ),
//     );
//   }
//
//   // RECEIVER: Accept Call
//   Future<void> _acceptCall() async {
//     print("👉 Accepting call: ${widget.callID}");
//     await FirebaseFirestore.instance
//         .collection('calls')
//         .doc(widget.callID)
//         .set({'status': 'accepted'}, SetOptions(merge: true));
//   }
//
//   // RECEIVER: Decline Call
//   Future<void> _declineCall() async {
//     print("👉 Declining call: ${widget.callID}");
//     await FirebaseFirestore.instance
//         .collection('calls')
//         .doc(widget.callID)
//         .set({'status': 'declined'}, SetOptions(merge: true));
//     if (mounted && Navigator.canPop(context)) Navigator.pop(context);
//   }
//
//   @override
//   void dispose() {
//     _callSub.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     // RECEIVER: Incoming call UI
//     return Scaffold(
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Text("Incoming Call"),
//             const SizedBox(height: 20),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 ElevatedButton(
//                   onPressed: _acceptCall,
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Icon(Icons.call, color: Colors.white),
//                 ),
//                 const SizedBox(width: 40),
//                 ElevatedButton(
//                   onPressed: _declineCall,
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   child: const Icon(Icons.call_end, color: Colors.white),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
