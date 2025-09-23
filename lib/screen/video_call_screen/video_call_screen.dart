import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:web_socket_app/utils/color.dart';

const String APP_ID = "c0aec9eab38544cf92e70a498c4f2a61";
const String TEMP_TOKEN =
    "007eJxTYLhbEnlr5dFj7HOffLApcNFuPaTHmCd0d676vKCbsl938p9TYEg2SExNtkxNTDK2MDUxSU6zNEo1N0g0sbRINkkzSjQzDMy7mNEQyMgwUUaEkZEBAkF8QYa0nNKSktSi+JTU3Pz4ovz8XAYGAGumJU8=";

class VideoCallPage extends StatefulWidget {
  final String channelName;
  final bool isVideoCall; // Add this parameter
  const VideoCallPage({
    Key? key,
    required this.channelName,
    this.isVideoCall = false,
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
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: APP_ID));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() => _remoteUid = null);
        },
      ),
    );

    // Enable video only if it's a video call
    if (widget.isVideoCall) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.enableAudio();
      await _engine.disableVideo();
    }

    await _engine.joinChannel(
      token: TEMP_TOKEN,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType
            .clientRoleBroadcaster, // Assuming both are broadcasters
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Widget _renderLocalPreview() {
    if (!widget.isVideoCall) return SizedBox.shrink();
    if (!_localUserJoined) {
      return const Center(child: Text('Joining channel, please wait...'));
    }
    if (_isVideoDisabled) {
      return const Center(child: Text('Local video disabled'));
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _renderRemoteVideo() {
    if (!widget.isVideoCall) return SizedBox.shrink();
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return const Center(child: Text('Waiting for remote user to join...'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.isVideoCall ? 'Video' : 'Audio'} Channel: ${widget.channelName.split('_').last}",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColor.primaryColor,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          if (widget.isVideoCall && _remoteUid != null) _renderRemoteVideo(),
          if (widget.isVideoCall && _remoteUid == null && _localUserJoined)
            Center(
              child: Text(
                'Waiting for remote user to join...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (widget.isVideoCall && !_localUserJoined)
            Center(
              child: Text(
                'Joining video call...',
                style: TextStyle(color: Colors.white),
              ),
            ),

          if (widget.isVideoCall)
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 100,
                height: 150,
                child: Center(child: _renderLocalPreview()),
              ),
            ),

          // Controls for both audio and video calls
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute/Unmute audio
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
                  // Toggle video for video calls
                  if (widget.isVideoCall)
                    FloatingActionButton(
                      heroTag: "videoBtn",
                      onPressed: () async {
                        setState(() => _isVideoDisabled = !_isVideoDisabled);
                        await _engine.enableLocalVideo(!_isVideoDisabled);
                        await _engine.muteLocalVideoStream(
                          _isVideoDisabled,
                        ); // Mute video stream as well
                      },
                      backgroundColor: _isVideoDisabled
                          ? Colors.red
                          : Colors.blue,
                      child: Icon(
                        _isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                        color: Colors.white,
                      ),
                    ),
                  // Leave Call
                  FloatingActionButton(
                    heroTag: "leaveBtn",
                    onPressed: () async {
                      await _engine.leaveChannel();
                      Navigator.pop(context);
                    },
                    backgroundColor: Colors.red,
                    child: Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          // Display for audio-only calls (if not a video call)
          if (!widget.isVideoCall)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    _localUserJoined
                        ? "Connected to ${_remoteUid != null ? 'User' : 'waiting for user...'}"
                        : "Connecting to audio call...",
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Channel: ${widget.channelName.split('_').last}",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
