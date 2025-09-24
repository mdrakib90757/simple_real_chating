// import 'package:flutter/material.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// const String APP_ID = "c0aec9eab38544cf92e70a498c4f2a61";
// const String TEMP_TOKEN =
//     "007eJxTYKgwE6141N2gaSnM0blgcaSz6+OXe7JEDUW/bRRnWeyyeakCQ7JBYmqyZWpikrGFqYlJcpqlUaq5QaKJpUWySZpRopmh+q5LGQ2BjAw5uhmsjAwQCOLzMhSlJubEJ2cklsQnFhQwMAAA09UhHA==";
//
// class VideoCallPage extends StatefulWidget {
//   final String channelName;
//   final bool isVideoCall;
//   final String receiverEmail;
//   final String? receiverPhotoUrl;
//
//   const VideoCallPage({
//     Key? key,
//     required this.channelName,
//     this.isVideoCall = false,
//     required this.receiverEmail,
//     this.receiverPhotoUrl,
//   }) : super(key: key);
//
//   @override
//   State<VideoCallPage> createState() => _VideoCallPageState();
// }
//
// class _VideoCallPageState extends State<VideoCallPage> {
//   late RtcEngine _engine;
//   int? _remoteUid;
//   bool _localUserJoined = false;
//   bool _isMuted = false;
//   bool _isVideoDisabled = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initAgora();
//   }
//
//   @override
//   void dispose() {
//     _engine.leaveChannel();
//     _engine.release();
//     super.dispose();
//   }
//
//   Future<void> _initAgora() async {
//     // Request permissions
//     Map<Permission, PermissionStatus> statuses = await [
//       Permission.camera,
//       Permission.microphone,
//     ].request();
//
//     if (statuses[Permission.camera] == PermissionStatus.denied ||
//         statuses[Permission.microphone] == PermissionStatus.denied) {
//       print("Camera or Microphone permission denied. Cannot proceed with call.");
//       // TODO: Show a user-friendly message and potentially navigate back or ask again
//       return;
//     }
//
//     if (statuses[Permission.camera] == PermissionStatus.permanentlyDenied ||
//         statuses[Permission.microphone] == PermissionStatus.permanentlyDenied) {
//       print("Camera or Microphone permission permanently denied. User needs to enable from settings.");
//       // TODO: Show a message and open app settings
//       openAppSettings();
//       return;
//     }
//     // 2️⃣ Create engine
//     _engine = createAgoraRtcEngine();
//     await _engine.initialize(RtcEngineContext(appId: APP_ID));
//
//     // 3️⃣ Enable video/audio
//     if (widget.isVideoCall) {
//       await _engine.enableVideo();
//       await _engine.startPreview();
//     } else {
//       await _engine.disableVideo();
//       _isVideoDisabled = true; // Mark video as intentionally disabled
//       await _engine.enableAudio();
//     }
//
//     // 4️⃣ Event handlers
//     _engine.registerEventHandler(
//       RtcEngineEventHandler(
//         onJoinChannelSuccess: (connection, elapsed) {
//           setState(() => _localUserJoined = true);
//           print("Local user joined channel: ${connection.channelId}");
//         },
//         onUserJoined: (connection, remoteUid, elapsed) {
//           setState(() => _remoteUid = remoteUid);
//           print("Remote user joined: $remoteUid");
//         },
//         onUserOffline: (connection, remoteUid, reason) {
//           setState(() => _remoteUid = null);
//           print("Remote user offline: $remoteUid");
//         },
//         onError: (err, msg) {
//           print("Agora Error: $err, $msg");
//         },
//       ),
//     );
//
//     // 5️⃣ Join channel
//     await _engine.joinChannel(
//       token: TEMP_TOKEN, // In production, generate this token on your backend
//       channelId: widget.channelName,
//       uid: 0, // 0 for Agora to assign a UID
//       options: const ChannelMediaOptions(
//         clientRoleType: ClientRoleType.clientRoleBroadcaster,
//         channelProfile: ChannelProfileType.channelProfileCommunication,
//       ),
//     );
//
//     // 6️⃣ Force front camera & speaker - do this only if it's a video call
//     if (widget.isVideoCall) {
//       await _engine.switchCamera();
//     }
//     await _engine.setEnableSpeakerphone(true);
//   }
//
//   Widget _renderLocalPreview() {
//     if (!widget.isVideoCall)
//       return const SizedBox.shrink(); // Hide for audio calls
//     if (!_localUserJoined) {
//       return const Center(
//         child: Text(
//           'Joining channel...',
//           style: TextStyle(color: Colors.white),
//         ),
//       );
//     }
//     if (_isVideoDisabled) {
//       return Container(
//         color: Colors.black,
//         child: const Center(
//           child: Icon(Icons.videocam_off, color: Colors.white, size: 48),
//         ),
//       );
//     }
//     return AgoraVideoView(
//       controller: VideoViewController(
//         rtcEngine: _engine,
//         canvas: const VideoCanvas(uid: 0),
//       ),
//     );
//   }
//
// // Inside your _VideoCallPageState class
//
//   Widget _renderRemoteVideo() {
//     if (!widget.isVideoCall) {
//       // For audio calls, display caller info in the center
//       return Container(
//         width: double.infinity,
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Colors.deepPurple.shade900, Colors.black87], // A nice gradient
//           ),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircleAvatar(
//               radius: 60,
//               backgroundColor: Colors.blueGrey, // Can be Colors.transparent if you prefer
//               backgroundImage: widget.receiverPhotoUrl != null
//                   ? NetworkImage(widget.receiverPhotoUrl!)
//                   : null,
//               child: widget.receiverPhotoUrl == null && widget.receiverEmail.isNotEmpty
//                   ? Text(
//                 widget.receiverEmail[0].toUpperCase(),
//                 style: const TextStyle(fontSize: 50, color: Colors.white),
//               )
//                   : null, // Only show initial if no photo and email is not empty
//             ),
//             const SizedBox(height: 20),
//             Text(
//               widget.receiverEmail,
//               style: const TextStyle(
//                 fontSize: 26, // Increased font size for better visibility
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               _remoteUid != null ? "Connected" : "Calling...", // Update status
//               style: const TextStyle(fontSize: 20, color: Colors.white70),
//             ),
//             if (_remoteUid == null && !_localUserJoined) // Show "Joining channel..." for local user connecting
//               const Padding(
//                 padding: EdgeInsets.only(top: 10),
//                 child: Text(
//                   'Joining channel...',
//                   style: TextStyle(color: Colors.white54, fontSize: 16),
//                 ),
//               ),
//           ],
//         ),
//       );
//     }
//
//     // For video calls
//     if (_remoteUid != null) {
//       return AgoraVideoView(
//         controller: VideoViewController.remote(
//           rtcEngine: _engine,
//           canvas: VideoCanvas(uid: _remoteUid),
//           connection: RtcConnection(channelId: widget.channelName),
//         ),
//       );
//     } else {
//       // Placeholder for remote video when not joined yet
//       return Container(
//         color: Colors.black, // Keep black for video call waiting screen
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircleAvatar(
//               radius: 60,
//               backgroundColor: Colors.blueGrey,
//               backgroundImage: widget.receiverPhotoUrl != null
//                   ? NetworkImage(widget.receiverPhotoUrl!)
//                   : null,
//               child: widget.receiverPhotoUrl == null && widget.receiverEmail.isNotEmpty
//                   ? Text(
//                 widget.receiverEmail[0].toUpperCase(),
//                 style: const TextStyle(fontSize: 50, color: Colors.white),
//               )
//                   : null,
//             ),
//             const SizedBox(height: 20),
//             Text(
//               widget.receiverEmail,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             const Text(
//               'Waiting for remote user...',
//               style: TextStyle(color: Colors.white, fontSize: 18),
//             ),
//             if (!_localUserJoined) // Also show local user's joining status
//               const Padding(
//                 padding: EdgeInsets.only(top: 10),
//                 child: Text(
//                   'Joining channel...',
//                   style: TextStyle(color: Colors.white54, fontSize: 16),
//                 ),
//               ),
//           ],
//         ),
//       );
//     }
//   }
//
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Align(
//             alignment: Alignment.center,
//             child: _renderRemoteVideo(),
//           ), // This now handles both audio and video remote views
//           // Local preview for video calls only
//           if (widget.isVideoCall)
//             Positioned(
//               bottom: 120, // Adjusted position to avoid overlap with controls
//               right: 20,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: SizedBox(
//                   width: 100,
//                   height: 150,
//                   child: _renderLocalPreview(),
//                 ),
//               ),
//             ),
//
//           Align(
//             alignment: Alignment.bottomCenter,
//             child: Padding(
//               padding: const EdgeInsets.all(20),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   FloatingActionButton(
//                     heroTag: "muteBtn",
//                     onPressed: () async {
//                       setState(() => _isMuted = !_isMuted);
//                       await _engine.muteLocalAudioStream(_isMuted);
//                     },
//                     backgroundColor: _isMuted ? Colors.red : Colors.green,
//                     child: Icon(
//                       _isMuted ? Icons.mic_off : Icons.mic,
//                       color: Colors.white,
//                     ),
//                   ),
//                   if (widget
//                       .isVideoCall) // Show video toggle only for video calls
//                     FloatingActionButton(
//                       heroTag: "videoBtn",
//                       onPressed: () async {
//                         setState(() => _isVideoDisabled = !_isVideoDisabled);
//                         await _engine.enableLocalVideo(!_isVideoDisabled);
//                         await _engine.muteLocalVideoStream(_isVideoDisabled);
//                       },
//                       backgroundColor: _isVideoDisabled
//                           ? Colors.red
//                           : Colors.blue,
//                       child: Icon(
//                         _isVideoDisabled ? Icons.videocam_off : Icons.videocam,
//                         color: Colors.white,
//                       ),
//                     ),
//                   FloatingActionButton(
//                     heroTag: "leaveBtn",
//                     onPressed: () async {
//                       await _engine.leaveChannel();
//                       Navigator.pop(context);
//                     },
//                     backgroundColor: Colors.red,
//                     child: const Icon(Icons.call_end, color: Colors.white),
//                   ),
//                   if (widget.isVideoCall) // Camera switch only for video calls
//                     FloatingActionButton(
//                       heroTag: "switchCamBtn",
//                       onPressed: () async {
//                         await _engine.switchCamera();
//                       },
//                       backgroundColor: Colors.blueGrey,
//                       child: const Icon(
//                         Icons.switch_camera,
//                         color: Colors.white,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


/// Agora Video Call
//
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';
// import 'package:wakelock/wakelock.dart';
//
// import '../../widgets/call_controller/call_controller.dart';
//
//
// class VideoCall extends StatefulWidget {
//
//
//   @override
//   State<VideoCall> createState() => _VideoCallState();
// }
//
// class _VideoCallState extends State<VideoCall> {
//   final callCon = Get.put(CallController());
//
//   @override
//   void initState() {
//     super.initState();
//     Wakelock.enable(); // Turn on wakelock feature till call is running
//   }
//
//   @override
//   void dispose() {
//     // _engine.leaveChannel();
//     // _engine.destroy();
//     Wakelock.disable(); // Turn off wakelock feature after call end
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Scaffold(
//           backgroundColor: Colors.black,
//           body: Obx(() => Padding(
//             padding: EdgeInsets.all(10),
//             child: Stack(
//               children: [
//                 Center(
//                   child: callCon.localUserJoined == true
//                       ? callCon.videoPaused == true
//                       ? Container(
//                       color: Theme.of(context).primaryColor,
//                       child: Center(
//                           child: Text(
//                             "Remote Video Paused",
//                             style: Theme.of(context)
//                                 .textTheme
//                                 .titleSmall!
//                                 .copyWith(color: Colors.white70),
//                           )))
//                       : AgoraVideoView(
//                     controller: VideoViewController.remote(
//                       rtcEngine: callCon.engine,
//                       canvas: VideoCanvas(
//                           uid: callCon.myremoteUid.value),
//                       connection: const RtcConnection(
//                           channelId: channgeId),
//                     ),
//                   )
//                       : const Center(
//                     child: Text(
//                       'No Remote',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ),
//                 Align(
//                   alignment: Alignment.topLeft,
//                   child: SizedBox(
//                     width: 100,
//                     height: 150,
//                     child: Center(
//                         child: callCon.localUserJoined.value
//                             ? AgoraVideoView(
//                           controller: VideoViewController(
//                             rtcEngine: callCon.engine,
//                             canvas: const VideoCanvas(uid: 0),
//                           ),
//                         )
//                             : CircularProgressIndicator()),
//                   ),
//                 ),
//                 Positioned(
//                   bottom: 10,
//                   left: 10,
//                   right: 10,
//                   child: Container(
//                     child: Row(
//                       children: [
//                         Expanded(
//                           flex: 1,
//                           child: InkWell(
//                             onTap: () {
//                               callCon.onToggleMute();
//                             },
//                             child: Icon(
//                               callCon.muted.value
//                                   ? Icons.mic
//                                   : Icons.mic_off,
//                               size: 35,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 1,
//                           child: InkWell(
//                             onTap: () {
//                               callCon.onCallEnd();
//                             },
//                             child: const Icon(
//                               Icons.call,
//                               size: 35,
//                               color: Colors.red,
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 1,
//                           child: InkWell(
//                             onTap: () {
//                               callCon.onVideoOff();
//                             },
//                             child: const CircleAvatar(
//                               backgroundColor: Colors.white,
//                               child: Padding(
//                                 padding: EdgeInsets.all(5),
//                                 child: Center(
//                                   child: Icon(
//                                     Icons.photo_camera_front,
//                                     size: 25,
//                                     color: Colors.black,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           flex: 1,
//                           child: InkWell(
//                             onTap: () {
//                               callCon.onSwitchCamera();
//                             },
//                             child: const Icon(
//                               Icons.switch_camera,
//                               size: 35,
//                               color: Colors.white,
//                             ),
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 )
//               ],
//             ),
//           ))),
//     );
//   }
// }

///
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/call_controller/call_controller.dart';
import 'package:permission_handler/permission_handler.dart';
//
// class VideoCallPage extends StatefulWidget {
//   final String channelName;
//   const VideoCallPage({Key? key, required this.channelName}) : super(key: key);
//
//   @override
//   State<VideoCallPage> createState() => _VideoCallPageState();
// }
//
// class _VideoCallPageState extends State<VideoCallPage> {
//   late CallController callCon;
//
//   @override
//   void initState() {
//     super.initState();
//     callCon = Get.put(CallController(widget.channelName));
//     requestPermissions();
//   }
//
//   Future<void> requestPermissions() async {
//     await [Permission.camera, Permission.microphone].request();
//   }
//
//   @override
//   void dispose() {
//     callCon.leaveChannel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         title: Text("Video Call"),
//         backgroundColor: Colors.blue,
//         automaticallyImplyLeading: false,
//       ),
//       body: Stack(
//         children: [
//
//           // Remote Video
//           Obx(() {
//             print("Remote UID: ${callCon.remoteUid.value}");
//             if (callCon.remoteUid.value != 0) {
//               return AgoraVideoView(
//                 controller: VideoViewController.remote(
//                   rtcEngine: callCon.engine,
//                   canvas: VideoCanvas(uid: callCon.remoteUid.value),
//                   connection: RtcConnection(channelId: widget.channelName),
//                 ),
//               );
//             } else {
//               return const Center(
//                 child: Text(
//                   "Waiting for remote user...",
//                   style: TextStyle(color: Colors.white, fontSize: 18),
//                 ),
//               );
//             }
//           }),
//
//           // Local Video
//           Align(
//             alignment: Alignment.topLeft,
//             child: SizedBox(
//               width: 120,
//               height: 160,
//               child: Obx(() {
//                 print("Local joined: ${callCon.localJoined
//                     .value}"); // <-- Debug print
//                 return callCon.localJoined.value
//                     ? AgoraVideoView(
//                   controller: VideoViewController(
//                     rtcEngine: callCon.engine,
//                     canvas: const VideoCanvas(uid: 0),
//                   ),
//                 )
//                     : const Center(child: CircularProgressIndicator());
//               }),
//             ),
//           ),
//         ],
//       ),
//
//       // Bottom controls
//       bottomNavigationBar: Container(
//         color: Colors.black54,
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             Obx(() => IconButton(
//               icon: Icon(
//                   callCon.mutedAudio.value ? Icons.mic_off : Icons.mic,
//                   color: Colors.white),
//               onPressed: callCon.toggleMuteAudio,
//             )),
//             IconButton(
//               icon: const Icon(Icons.call_end, color: Colors.red),
//               onPressed: () {
//                 callCon.leaveChannel();
//                 Navigator.pop(context);
//               },
//             ),
//             Obx(() => IconButton(
//               icon: Icon(
//                   callCon.mutedVideo.value
//                       ? Icons.videocam_off
//                       : Icons.videocam,
//                   color: Colors.white),
//               onPressed: callCon.toggleMuteVideo,
//             )),
//             IconButton(
//               icon: const Icon(Icons.switch_camera, color: Colors.white),
//               onPressed: callCon.switchCamera,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
//
//
// class VideoCallPage extends StatelessWidget {
//   final String token;
//   final String channelName;
//
//   VideoCallPage({required this.token, required this.channelName});
//
//   @override
//   Widget build(BuildContext context) {
//     final callCon = Get.put(CallController());
//
//     // Initialize Agora
//     callCon.initAgora(token, channelName);
//
//     return Scaffold(
//       body: Obx(() {
//         if (!callCon.localJoined.value) {
//           return Center(child: CircularProgressIndicator());
//         }
//
//         return Stack(
//           children: [
//             // Remote view
//             if (callCon.remoteUid.value != 0)
//               AgoraVideoView(
//                 controller: VideoViewController.remote(
//                   rtcEngine: callCon.engine,
//                   canvas: VideoCanvas(uid: callCon.remoteUid.value),
//                   connection: RtcConnection(channelId: channelName),
//                 ),
//               )
//             else
//               Center(child: Text("Waiting for remote user...")),
//
//             // Local small view
//             Align(
//               alignment: Alignment.topLeft,
//               child: SizedBox(
//                 width: 100,
//                 height: 150,
//                 child: AgoraVideoView(
//                   controller: VideoViewController(
//                     rtcEngine: callCon.engine,
//                     canvas: const VideoCanvas(uid: 0),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       }),
//     );
//   }
// }


///
///
///
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

final String appId = "c0aec9eab38544cf92e70a498c4f2a61";
final String token = "007eJxTYKgwE6141N2gaSnM0blgcaSz6+OXe7JEDUW/bRRnWeyyeakCQ7JBYmqyZWpikrGFqYlJcpqlUaq5QaKJpUWySZpRopmh+q5LGQ2BjAw5uhmsjAwQCOLzMhSlJubEJ2cklsQnFhQwMAAA09UhHA==";

// class VideoCallPage extends StatefulWidget {
//   final String channelName;
//   final String token;
//   final bool isVideoCall;
//
//   const VideoCallPage({
//     Key? key,
//     required this.channelName,
//     required this.token,
//     this.isVideoCall = true, // default to video call
//   }) : super(key: key);
//
//   @override
//   State<VideoCallPage> createState() => _VideoCallPageState();
// }
//
// class _VideoCallPageState extends State<VideoCallPage> {
//   late final RtcEngine _engine;
//   bool _isEngineReady = false; // <--- flag
//   int? _localUid;
//   final List<int> _remoteUids = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _initAgora();
//   }
//
//   Future<void> _initAgora() async {
//     await [Permission.microphone, Permission.camera].request();
//
//     _engine = createAgoraRtcEngine();
//     await _engine.initialize(RtcEngineContext(appId: appId));
//
//     if (widget.isVideoCall) {
//       await _engine.enableVideo();
//     } else {
//       await _engine.disableVideo();
//     }
//
//     _engine.registerEventHandler(RtcEngineEventHandler(
//       onJoinChannelSuccess: (connection, elapsed) {
//         setState(() {
//           _localUid = connection.localUid;
//         });
//       },
//       onUserJoined: (connection, remoteUid, elapsed) {
//         setState(() {
//           _remoteUids.add(remoteUid);
//         });
//       },
//       onUserOffline: (connection, remoteUid, reason) {
//         setState(() {
//           _remoteUids.remove(remoteUid);
//         });
//       },
//     ));
//
//     await _engine.joinChannel(
//       token: widget.token,
//       channelId: widget.channelName,
//       uid: 0,
//       options: const ChannelMediaOptions(),
//     );
//
//     setState(() {
//       _isEngineReady = true; // <-- engine is ready
//     });
//   }
//
//   Widget _renderVideo() {
//     if (!_isEngineReady) {
//       return const Center(child: CircularProgressIndicator());
//     }
//
//     if (!widget.isVideoCall) {
//       return const Center(child: Icon(Icons.call, size: 100));
//     }
//
//     return Stack(
//       children: [
//         if (_remoteUids.isNotEmpty)
//           AgoraVideoView(
//             controller: VideoViewController.remote(
//               rtcEngine: _engine,
//               canvas: VideoCanvas(uid: _remoteUids.first),
//               connection: RtcConnection(channelId: widget.channelName),
//             ),
//           )
//         else
//           const Center(child: Text('Waiting for remote user...')),
//         Positioned(
//           top: 20,
//           right: 20,
//           width: 120,
//           height: 160,
//           child: AgoraVideoView(
//             controller: VideoViewController(
//               rtcEngine: _engine,
//               canvas: VideoCanvas(uid: _localUid ?? 0),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: _renderVideo(),
//     );
//   }
// }


///
///
class VideoCallPage extends StatefulWidget {
  final String channelName;
  final String token;
  final bool isVideoCall;

  VideoCallPage({
    required this.channelName,
    required this.token,
    this.isVideoCall = true,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  late final RtcEngine _engine;
  int? _localUid;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // 1️⃣ Request permissions first
    if (widget.isVideoCall) {
      await [Permission.camera, Permission.microphone].request();
    } else {
      await [Permission.microphone].request();
    }

    // 2️⃣ Create engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));

    // 3️⃣ Enable video/audio
    if (widget.isVideoCall) {
      await _engine.enableVideo();
    } else {
      await _engine.disableVideo();
    }

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // 4️⃣ Event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print('Joined channel: ${connection.channelId}, uid: ${connection.localUid}');
          setState(() {
            _joined = true;
            _localUid = connection.localUid;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          print('Remote user joined: $remoteUid');
        },
        onUserOffline: (connection, remoteUid, reason) {
          print('Remote user left: $remoteUid');
        },
      ),
    );

    // 5️⃣ Join channel
    try {
      await _engine.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: 0, // let Agora assign uid
        options: ChannelMediaOptions(),
      );
    } catch (e) {
      print('Error joining Agora channel: $e');
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Local video
          if (_joined && widget.isVideoCall)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: _localUid),
              ),
            ),
          // Remote video placeholder
          Center(child: Text('Waiting for other user...')),
        ],
      ),
    );
  }
}
