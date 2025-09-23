import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

const String APP_ID = "c0aec9eab38544cf92e70a498c4f2a61";
const String TEMP_TOKEN =
    "007eJxTYLhbEnlr5dFj7HOffLApcNFuPaTHmCd0d676vKCbsl938p9TYEg2SExNtkxNTDK2MDUxSU6zNEo1N0g0sbRINkkzSjQzDMy7mNEQyMgwUUaEkZEBAkF8QYa0nNKSktSi+JTU3Pz4ovz8XAYGAGumJU8=";

class VideoCallPage extends StatefulWidget {
  final String channelName;
  final bool isVideoCall;
  final String receiverEmail;
  final String? receiverPhotoUrl;

  const VideoCallPage({
    Key? key,
    required this.channelName,
    this.isVideoCall = false,
    required this.receiverEmail,
    this.receiverPhotoUrl,
  }) : super(key: key);

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoDisabled = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Future<void> _initAgora() async {
    await [Permission.camera, Permission.microphone].request();
    if (await Permission.camera.isDenied ||
        await Permission.microphone.isDenied) {
      print("Camera or Microphone permission denied.");
      return;
    }

    // 2️⃣ Create engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: APP_ID));

    // 3️⃣ Enable video/audio
    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
      _isVideoDisabled = true; // Mark video as intentionally disabled
      await _engine.enableAudio();
    }

    // 4️⃣ Event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _localUserJoined = true);
          print("Local user joined channel: ${connection.channelId}");
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() => _remoteUid = remoteUid);
          print("Remote user joined: $remoteUid");
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() => _remoteUid = null);
          print("Remote user offline: $remoteUid");
        },
        onError: (err, msg) {
          print("Agora Error: $err, $msg");
        },
      ),
    );

    // 5️⃣ Join channel
    await _engine.joinChannel(
      token: TEMP_TOKEN, // In production, generate this token on your backend
      channelId: widget.channelName,
      uid: 0, // 0 for Agora to assign a UID
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // 6️⃣ Force front camera & speaker - do this only if it's a video call
    if (widget.isVideoCall) {
      await _engine.switchCamera();
    }
    await _engine.setEnableSpeakerphone(true);
  }

  Widget _renderLocalPreview() {
    if (!widget.isVideoCall)
      return const SizedBox.shrink(); // Hide for audio calls
    if (!_localUserJoined) {
      return const Center(
        child: Text(
          'Joining channel...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    if (_isVideoDisabled) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white, size: 48),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _renderRemoteVideo() {
    if (!widget.isVideoCall) {
      // For audio calls, display caller info in the center
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blueGrey,
            // child: Text(
            //   widget.receiverEmail[0].toUpperCase(),
            //   style: const TextStyle(fontSize: 50, color: Colors.white),
            // ),
            backgroundImage: widget.receiverPhotoUrl != null
                ? NetworkImage(widget.receiverPhotoUrl!)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            widget.receiverEmail,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _remoteUid != null ? "Connected" : "Calling...",
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ],
      );
    }

    // For video calls
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blueGrey,
              // child: Text(
              //   widget.receiverEmail[0].toUpperCase(),
              //   style: const TextStyle(fontSize: 50, color: Colors.white),
              // ),
              backgroundImage: widget.receiverPhotoUrl != null
                  ? NetworkImage(widget.receiverPhotoUrl!)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              widget.receiverEmail,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Waiting for remote user...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: _renderRemoteVideo(),
          ), // This now handles both audio and video remote views
          // Local preview for video calls only
          if (widget.isVideoCall)
            Positioned(
              bottom: 120, // Adjusted position to avoid overlap with controls
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 100,
                  height: 150,
                  child: _renderLocalPreview(),
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    heroTag: "muteBtn",
                    onPressed: () async {
                      setState(() => _isMuted = !_isMuted);
                      await _engine.muteLocalAudioStream(_isMuted);
                    },
                    backgroundColor: _isMuted ? Colors.red : Colors.green,
                    child: Icon(
                      _isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                  if (widget
                      .isVideoCall) // Show video toggle only for video calls
                    FloatingActionButton(
                      heroTag: "videoBtn",
                      onPressed: () async {
                        setState(() => _isVideoDisabled = !_isVideoDisabled);
                        await _engine.enableLocalVideo(!_isVideoDisabled);
                        await _engine.muteLocalVideoStream(_isVideoDisabled);
                      },
                      backgroundColor: _isVideoDisabled
                          ? Colors.red
                          : Colors.blue,
                      child: Icon(
                        _isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                        color: Colors.white,
                      ),
                    ),
                  FloatingActionButton(
                    heroTag: "leaveBtn",
                    onPressed: () async {
                      await _engine.leaveChannel();
                      Navigator.pop(context);
                    },
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  if (widget.isVideoCall) // Camera switch only for video calls
                    FloatingActionButton(
                      heroTag: "switchCamBtn",
                      onPressed: () async {
                        await _engine.switchCamera();
                      },
                      backgroundColor: Colors.blueGrey,
                      child: const Icon(
                        Icons.switch_camera,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
