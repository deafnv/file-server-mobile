import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

import 'package:file_server_mobile/types.dart';
import 'package:file_server_mobile/app_data.dart';

class ViewImage extends StatefulWidget {
  ViewImage({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.token,
  }) : pageController = PageController(initialPage: initialIndex);

  final List<ImageGalleryImages> images;
  final int initialIndex;
  final PageController pageController;
  final String? token;

  @override
  State<ViewImage> createState() => ViewImageState();
}

class ViewImageState extends State<ViewImage> {
  bool _hideBackButton = false;
  late int currentIndex = widget.initialIndex;

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = Provider.of<AppData>(context).scaffoldMessengerKey;

    return AnnotatedRegion(
      value: const SystemUiOverlayStyle(statusBarColor: Colors.black),
      child: Scaffold(
        body: SafeArea(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _hideBackButton = !_hideBackButton;
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoViewGallery.builder(
                  itemCount: widget.images.length,
                  scrollPhysics: const BouncingScrollPhysics(),
                  pageController: widget.pageController,
                  onPageChanged: onPageChanged,
                  builder: (context, index) {
                    final token = widget.token;
                    return PhotoViewGalleryPageOptions(
                      imageProvider: NetworkImage(widget.images[index].path, headers: {"cookie": "token=$token;"}),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.contained * 50,
                      heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index].path),
                      errorBuilder: (BuildContext context, Object exception, StackTrace? stackTrace) {
                        if (exception is NetworkImageLoadException && exception.statusCode == 401) {
                          // Handle unauthorized error
                          return const Center(
                            child: Text('Unauthorized. Login to access.'),
                          );
                        } else {
                          // Handle other errors
                          return const Center(
                            child: Text('Error loading image.'),
                          );
                        }
                      },
                    );
                  },
                  loadingBuilder: (context, event) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 64),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LinearProgressIndicator(
                          value:
                              event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1).toInt(),
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(height: 20),
                        const Text('Loading...'),
                      ],
                    ),
                  ),
                ),
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
                          stops: [0.0, 0.15, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _hideBackButton ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          IconButton(
                            splashRadius: 24,
                            onPressed: () => _hideBackButton ? null : Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.images[currentIndex].name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          PopupMenuButton(
                            enabled: !_hideBackButton,
                            onSelected: (value) {
                              switch (value) {
                                case 'copy':
                                  Clipboard.setData(ClipboardData(
                                    text: Uri.parse(widget.images[currentIndex].path).toString(),
                                  )).then((_) => showSnackbar(scaffoldKey, 'Copied link to clipboard'));
                                  break;
                                default:
                              }
                            },
                            splashRadius: 24,
                            itemBuilder: (BuildContext context) => [
                              const PopupMenuItem(
                                value: 'copy',
                                child: Text("Copy link"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
