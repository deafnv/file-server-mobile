import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:rich_clipboard/rich_clipboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../types.dart';
import './image_viewer.dart';
import './video_player.dart';

enum ContextMenuItems { openinbrowser, copy, delete, rename, move }

class MainPage extends StatefulWidget {
  const MainPage({super.key, this.currentDir});

  final ApiListResponse? currentDir;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final apiUrl = dotenv.env['API_URL']!;
  ApiListResponseList? _data;
  bool connectionDone = false;
  bool selectMode = false;
  List<ApiListResponse> selectedFiles = [];

  final ReceivePort _port = ReceivePort();

  _setSelectMode(bool val) {
    if (val) {
      selectMode = true;
    } else {
      selectMode = false;
      selectedFiles = [];
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    //* Get data on init
    _fetchData().then((data) {
      setState(() {
        _data = data; //* Store the initial data in the separate state variable
      });
    });

    BackButtonInterceptor.add(exitSelectModeBack);

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
    BackButtonInterceptor.remove(exitSelectModeBack);
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  bool exitSelectModeBack(bool stopDefaultButtonEvent, RouteInfo info) {
    if (selectMode) {
      _setSelectMode(false);
      return true;
    } else {
      return false;
    }
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

  _loadAppBar() {
    if (selectMode) {
      final selectedFilesCount = selectedFiles.length;
      return AppBar(
        backgroundColor: const Color.fromARGB(255, 71, 71, 71),
        leading: IconButton(
            splashRadius: 24,
            onPressed: () {
              _setSelectMode(false);
            },
            icon: const Icon(Icons.close)),
        title: Text('$selectedFilesCount File(s) selected'),
      );
    } else {
      return AppBar(
        leading: widget.currentDir == null
            ? null
            : IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back)),
        title: Text(widget.currentDir?.name ?? 'File Server'),
      );
    }
  }

  _loadUI() {
    if (connectionDone) {
      if (_data != null) {
        return ListView.builder(
            itemCount: _data!.files.length,
            itemBuilder: (context, index) {
              return ListTile(
                tileColor: selectedFiles.contains(_data!.files[index]) ? Colors.grey : Colors.transparent,
                leading: selectMode && selectedFiles.contains(_data!.files[index])
                    ? const Icon(Icons.done)
                    : Icon(_getIcon(_data!.files[index])),
                trailing: selectMode
                    ? null
                    : Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.white),
                        child: PopupMenuButton<ContextMenuItems>(
                          onSelected: (value) async {
                            final filePath = _data!.files[index].path;
                            final fileUrl =
                                _data!.files[index].isDirectory ? '$apiUrl/list$filePath' : '$apiUrl/retrieve$filePath';
                            switch (value) {
                              case ContextMenuItems.openinbrowser:
                                final uri = Uri.parse(fileUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  throw 'Could not launch $fileUrl';
                                }
                                break;
                              case ContextMenuItems.copy:
                                await RichClipboard.setData(RichClipboardData(
                                  text: fileUrl,
                                  //html: '{"action": "copy", "files": [$fileUrl]}', //TODO: Meant for copying files
                                ));
                                break;
                              default:
                            }
                          },
                          splashRadius: 24,
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem(
                              value: ContextMenuItems.openinbrowser,
                              child: Text("Open in browser"),
                            ),
                            const PopupMenuItem(
                              value: ContextMenuItems.copy,
                              child: Text("Copy"),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: ContextMenuItems.delete,
                              child: Text("Delete"),
                            ),
                          ],
                        ),
                      ),
                title: Text(_data!.files[index].name),
                onTap: () async {
                  if (selectMode) {
                    selectedFiles.contains(_data!.files[index])
                        ? selectedFiles.remove(_data!.files[index])
                        : selectedFiles.add(_data!.files[index]);
                    return setState(() {});
                  }
                  if (_data!.files[index].isDirectory) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MainPage(currentDir: _data!.files[index])),
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
                    final filePath = _data!.files[index].path;
                    _download('$apiUrl/retrieve$filePath');
                  }
                },
                onLongPress: () {
                  selectedFiles.add(_data!.files[index]);
                  _setSelectMode(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _loadAppBar(), body: _loadUI());
  }

  Future<void> _refreshData() async {
    final newData = await _fetchData(); // fetch new data from the API
    setState(() {
      _data = newData; // update the separate state variable with the new data
    });
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
      connectionDone = true;
      return parsedResponse;
    } else {
      connectionDone = true;
      return null;
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
}
