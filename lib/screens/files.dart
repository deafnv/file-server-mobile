import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../types.dart';
import './image_viewer.dart';
import './video_player.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key, this.currentDir});

  final ApiListResponse? currentDir;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final apiUrl = dotenv.env['API_URL']!;

  final ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();

    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    /* _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      setState(() {});
    }); */
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  void _download(String url) async {
    /* final externalDir = await getExternalStorageDirectory(); */

    /* final id =  */ await FlutterDownloader.enqueue(
      url: url,
      savedDir: '/storage/emulated/0/Download', //TODO: change this to platform specific
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: true,
    );
  }

  Future<ApiListResponseList?> _fetchData() async {
    final pathDir = widget.currentDir == null ? '/' : widget.currentDir!.path;
    final response = await http.get(Uri.parse('$apiUrl/list$pathDir'));
    if (response.statusCode == 200) {
      var parsedResponse = ApiListResponseList.fromJson(jsonDecode(response.body));
      parsedResponse.files.sort((a, b) {
        if (a.isDirectory && b.isDirectory) return a.name.compareTo(b.name);
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });
      return parsedResponse;
    } else {
      return null;
    }
  }

  _loadUI(AsyncSnapshot<ApiListResponseList?> snapshot) {
    if (snapshot.connectionState == ConnectionState.done) {
      if (snapshot.data != null) {
        return ListView.builder(
            itemCount: snapshot.data!.files.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Icon(_getIcon(snapshot.data!.files[index])),
                title: Text(snapshot.data!.files[index].name),
                onTap: () async {
                  if (snapshot.data!.files[index].isDirectory) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MainPage(currentDir: snapshot.data!.files[index])),
                    );
                  } /* else if (_getIcon(snapshot.data!.files[index]) == Icons.image) { //TODO: Reenable these after improving them
                    final imagePath = snapshot.data!.files[index].path;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewImage(url: '$apiUrl/retrieve$imagePath'),
                      ),
                    );
                  } else if (_getIcon(snapshot.data!.files[index]) == Icons.movie) {
                    final imagePath = snapshot.data!.files[index].path;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(url: '$apiUrl/retrieve$imagePath'),
                      ),
                    );
                  } */
                  else {
                    final filePath = snapshot.data!.files[index].path;
                    _download('$apiUrl/retrieve$filePath');
                  }
                },
              );
            });
      } else {
        return const Center(child: Text('Something went wrong'));
      }
    } else {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }

  _getIcon(ApiListResponse file) {
    if (file.isDirectory) return Icons.folder;
    final splitName = file.name.split('.');
    final extension = splitName[splitName.length - 1];
    if (splitName.length == 1) return null;
    if (['zip', '7z', 'rar'].contains(extension)) return Icons.folder_zip;
    if (['doc', 'docx', 'txt', 'pdf'].contains(extension)) return Icons.article;
    if (['mkv', 'mp4', 'webm', 'ogg'].contains(extension)) return Icons.movie;
    if (['png', 'jpg', 'jpeg', 'gif'].contains(extension)) return Icons.image;
    if (['wav', 'mp3', 'aac', 'flac', 'm4a'].contains(extension)) return Icons.audio_file;
    if (['json', 'jsonl'].contains(extension)) return Icons.data_object;
    if (['js', 'jsx', 'css', 'ts', 'tsx'].contains(extension)) return Icons.code;
    if (['xlsx', 'xls', 'csv'].contains(extension)) return Icons.list_alt;
    if (['ass', 'srt', 'vtt'].contains(extension)) return Icons.closed_caption;
    if (['exe'].contains(extension)) return Icons.terminal;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _fetchData(),
        builder: (BuildContext context, AsyncSnapshot<ApiListResponseList?> snapshot) {
          return Scaffold(
              appBar: AppBar(
                leading: widget.currentDir == null
                    ? null
                    : IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back)),
                title: Text(widget.currentDir?.name ?? 'File Server'),
              ),
              body: _loadUI(snapshot));
        });
  }
}
