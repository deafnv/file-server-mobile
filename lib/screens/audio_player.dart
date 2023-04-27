import 'package:file_server_mobile/screens/files.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'package:file_server_mobile/types.dart';
import 'package:file_server_mobile/app_data.dart';
import 'package:url_launcher/url_launcher.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({
    super.key,
    required this.audios,
    required this.initialIndex,
    required this.folderName,
    required this.token,
  });

  final List<AudioFile> audios;
  final int initialIndex;
  final String folderName;
  final String? token;

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> with SingleTickerProviderStateMixin {
  late AudioPlayer player;
  late AnimationController _controller;
  bool playerReady = false;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();

    player.currentIndexStream.listen((index) {
      setState(() {});
    });

    final token = widget.token;
    // Define the playlist
    final playlist = ConcatenatingAudioSource(
      // Start loading next item just before reaching it
      useLazyPreparation: true,
      // Customise the shuffle algorithm
      shuffleOrder: DefaultShuffleOrder(),
      // Specify the playlist items
      children: widget.audios
          .map((e) => AudioSource.uri(Uri.parse(e.url),
              tag: MediaItem(
                id: e.url,
                album: widget.folderName,
                title: e.name,
              ),
              headers: {"cookie": "token=$token;"}))
          .toList(),
    );

    player.setAudioSource(playlist, initialIndex: widget.initialIndex).then((_) {
      playerReady = true;
      setState(() {});
    });
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
  }

  @override
  void dispose() {
    player.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldKey = Provider.of<AppData>(context).scaffoldMessengerKey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
        actions: [
          PopupMenuButton<ContextMenuItems>(
            onSelected: (value) {
              switch (value) {
                case ContextMenuItems.copy:
                  if (player.currentIndex != null) {
                    Clipboard.setData(ClipboardData(
                      text: Uri.parse(widget.audios[player.currentIndex!].url).toString(),
                    )).then((_) => showSnackbar(scaffoldKey, 'Copied link to clipboard'));
                  }
                  break;
                case ContextMenuItems.openinbrowser:
                  final uri = Uri.parse(widget.audios[player.currentIndex!].url);
                  canLaunchUrl(uri)
                      .then((_) => launchUrl(uri, mode: LaunchMode.externalApplication))
                      .catchError((_) => throw 'Could not launch $uri');
                  break;
                default:
              }
            },
            splashRadius: 24,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: ContextMenuItems.copy,
                child: Text("Copy link"),
              ),
              const PopupMenuItem(
                value: ContextMenuItems.openinbrowser,
                child: Text("Open in browser"),
              ),
            ],
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                player.currentIndex != null ? widget.audios[player.currentIndex!].name : '',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder(
              stream: player.positionStream,
              builder: (context, AsyncSnapshot<Duration> snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final currentDuration = formattedTime(timeInSecond: position.inSeconds);
                final totalDuration = formattedTime(timeInSecond: player.duration?.inSeconds ?? 0);
                return Column(
                  children: [
                    SliderTheme(
                      data: const SliderThemeData(thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8)),
                      child: Slider(
                        value: position.inSeconds.toDouble(),
                        max: player.duration?.inSeconds.toDouble() ?? 0,
                        activeColor: Theme.of(context).colorScheme.secondary,
                        thumbColor: Theme.of(context).colorScheme.secondary,
                        inactiveColor: Theme.of(context).colorScheme.primary,
                        onChanged: !playerReady
                            ? null
                            : (double value) {
                                player.seek(Duration(seconds: value.toInt()));
                                //setState(() {});
                              },
                      ),
                    ),
                    Text('$currentDuration / $totalDuration')
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                IconButton(
                  iconSize: 28,
                  splashRadius: 28,
                  onPressed: () async => await player.seekToPrevious(),
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  iconSize: 36,
                  splashRadius: 36,
                  onPressed: !playerReady ? null : () => _playPause(),
                  icon: AnimatedIcon(
                    progress: _controller,
                    icon: AnimatedIcons.play_pause,
                  ),
                ),
                IconButton(
                  iconSize: 28,
                  splashRadius: 28,
                  onPressed: () async => await player.seekToNext(),
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String formattedTime({required int timeInSecond}) {
    int sec = timeInSecond % 60;
    int min = (timeInSecond / 60).floor();
    String minute = min.toString().length <= 1 ? "0$min" : "$min";
    String second = sec.toString().length <= 1 ? "0$sec" : "$sec";
    return "$minute:$second";
  }

  _playPause() {
    if (player.playing) {
      player.pause();
      _controller.reverse();
    } else {
      player.play();
      _controller.forward();
    }
  }
}
