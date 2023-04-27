import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url, required this.token});

  final String url;
  final String? token;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    _controller = VideoPlayerController.network(widget.url, httpHeaders: {"cookie": "token=$token;"})
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: true,
          hideControlsTimer: const Duration(seconds: 5),
          customControls: const MaterialControls(),
          /* customControls: const CupertinoControls(
            backgroundColor: Colors.black,
            iconColor: Colors.white,
          ), */
        );

        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _chewieController != null && _controller.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
      ),
    );
  }
}
