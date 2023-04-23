import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'package:file_server_mobile/types.dart';
import 'package:file_server_mobile/app_data.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key, required this.audio, required this.folderName});

  final AudioFile audio;
  final String folderName;

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
    final source = AudioSource.uri(
      Uri.parse(widget.audio.url),
      tag: MediaItem(
        id: widget.audio.url,
        album: widget.folderName,
        title: widget.audio.name,
      ),
    );
    player.setAudioSource(source).then((_) {
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
          PopupMenuButton(
            onSelected: (value) {
              switch (value) {
                case 'copy':
                  Clipboard.setData(ClipboardData(
                    text: Uri.parse(widget.audio.url).toString(),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.audio.name,
              style: const TextStyle(fontSize: 16),
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
            IconButton(
              iconSize: 28,
              splashRadius: 28,
              onPressed: !playerReady ? null : () => _playPause(),
              icon: AnimatedIcon(
                progress: _controller,
                icon: AnimatedIcons.play_pause,
              ),
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
