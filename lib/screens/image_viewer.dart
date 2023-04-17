import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter/services.dart';

class ViewImage extends StatefulWidget {
  const ViewImage({super.key, required this.url});

  final String url;

  @override
  State<ViewImage> createState() => ViewImageState();
}

class ViewImageState extends State<ViewImage> {
  bool _hideBackButton = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            _hideBackButton = !_hideBackButton;
          });

          //FIXME: This is really weird
          if (!_hideBackButton) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          } else {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoView(
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 50,
                initialScale: PhotoViewComputedScale.contained,
                imageProvider: NetworkImage(widget.url)),
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                opacity: _hideBackButton ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.transparent, Colors.transparent, Colors.black],
                          stops: [0.0, 0.15, 0.85, 1.0])),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _hideBackButton ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
