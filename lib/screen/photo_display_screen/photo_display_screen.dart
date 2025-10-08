import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_app/utils/color.dart';

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  final Function(String)? onSend;
  const DisplayPictureScreen({Key? key, required this.imagePath, this.onSend})
    : super(key: key);

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  bool _isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    bool isNetwork = _isNetworkImage(widget.imagePath);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.primaryColor,
        centerTitle: true,
        title: Text(
          isNetwork ? 'View Photo' : 'Preview Photo',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: isNetwork
                  ? Image.network(
                      widget.imagePath,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 50,
                        );
                      },
                    )
                  : Image.file(File(widget.imagePath), fit: BoxFit.contain),
            ),
          ),
          if (widget.onSend != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 20.0,
              ), // Add some padding
              child: CircleAvatar(
                radius: 25,
                backgroundColor: AppColor.primaryColor,
                child: IconButton(
                  onPressed: () async {
                    if (widget.onSend != null) {
                      await widget.onSend!(widget.imagePath);
                    }
                  },
                  icon: Icon(Icons.send, color: Colors.white),
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }
}
