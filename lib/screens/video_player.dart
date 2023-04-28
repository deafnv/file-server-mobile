import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'package:file_server_mobile/types.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.urls,
    required this.initialIndex,
    required this.token,
  });

  final List<VideoFile> urls;
  final int initialIndex;
  final String? token;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController pageViewController;

  @override
  void initState() {
    super.initState();
    pageViewController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: pageViewController,
      children: widget.urls.map((e) {
        return VideoPlayerView(url: e.url, token: widget.token);
      }).toList(),
    );
  }
}

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({super.key, required this.url, required this.token});

  final String url;
  final String? token;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    _controller = VideoPlayerController.network(widget.url, httpHeaders: {"cookie": "token=$token;"})
      ..initialize().then(
        (_) {
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
        },
      );
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
      body: Stack(
        children: [
          Center(
            child: _chewieController != null && _controller.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
          ),
          if (_chewieController != null && _controller.value.isInitialized)
            SafeArea(
              child: Visibility(
                visible: _chewieController!.isFullScreen ? false : true,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        IconButton(
                          splashRadius: 24,
                          onPressed: () => _chewieController!.isFullScreen ? null : Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
