import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:file_server_mobile/screens/move_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rich_clipboard/rich_clipboard.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';

import '../types.dart';
import 'drawer.dart';
import './image_viewer.dart';
import './video_player.dart';
import 'package:file_server_mobile/app_data.dart';

enum ContextMenuItems { openinbrowser, copy, rename, download }

class MainPage extends StatefulWidget {
  const MainPage({super.key, this.currentDir});

  final String? currentDir;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final apiUrl = dotenv.env['API_URL']!;

  String? currentDir;
  List<ApiListResponse>? _data;
  Map<String, dynamic>? _fileTreeData;
  bool connectionDone = false;
  bool connectionDoneFileTree = false;

  StateSetter? _setUploadProgress;
  double uploadProgress = 0;

  bool selectMode = false;
  List<ApiListResponse> selectedFiles = [];

  late FlutterSecureStorage storage;
  SharedPreferences? prefs;

  final ReceivePort _port = ReceivePort();

  late io.Socket socket;

  _setSelectMode(bool val) {
    if (val) {
      selectMode = true;
    } else {
      selectMode = false;
      selectedFiles = [];
    }
    setState(() {});
  }

  _handleSocketEvent(dynamic data) => _refreshData();
  _handleFileTreeEvent(dynamic data) => _refreshFileTree();

  @override
  void initState() {
    super.initState();

    if (widget.currentDir != null) currentDir = widget.currentDir;

    socket = io.io(apiUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.on(currentDir != null ? currentDir! : '/', _handleSocketEvent);
    socket.on('filetree', _handleFileTreeEvent);

    AndroidOptions getAndroidOptions() => const AndroidOptions(
          encryptedSharedPreferences: true,
        );
    storage = FlutterSecureStorage(aOptions: getAndroidOptions());

    //FIXME: Fix this. no drawer until prefs is initialized (not null)
    SharedPreferences.getInstance().then((value) => prefs = value);

    //* Get data on init
    _fetchData().then((data) {
      setState(() {
        _data = data; //* Store the initial data in the separate state variable
      });
    });

    _fetchFileTree().then((data) {
      setState(() {
        _fileTreeData = data;
      });
    });

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

    //TODO: Investigate if this is sufficient to prevent unnecessary refreshes, might need RouteObserver
    socket.off(currentDir != null ? currentDir! : '/', _handleSocketEvent);
    socket.off('filetree', _handleFileTreeEvent);
    super.dispose();
  }

  //! Remove later
  void _download(String url) async {
    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = await getExternalStorageDirectory();
      }
    } catch (err) {
      throw ("Cannot get download folder path");
    }

    if (directory != null) {
      await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory.path,
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true,
      );
    }
  }

  _loadAppBar(GlobalKey<ScaffoldMessengerState> scaffoldKey) {
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
        actions: [
          IconButton(
            tooltip: 'Move',
            splashRadius: 24,
            onPressed: () => prefs?.getString('userdata') != null
                ? Navigator.pushReplacement(
                    context,
                    PageTransition(
                      type: PageTransitionType.leftToRight,
                      child: MoveSelect(
                        currentDir: currentDir,
                        storage: storage,
                        filesToMove: selectedFiles.map((e) => e.path).toList(),
                      ),
                    ),
                  )
                : showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning),
            icon: const Icon(Icons.drive_file_move_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            splashRadius: 24,
            onPressed: () => _deleteFiles(selectedFiles.map((e) => e.path).toList(), scaffoldKey),
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Select All',
            splashRadius: 24,
            onPressed: () {
              selectedFiles = [..._data!];
              setState(() {});
              showSnackbar(scaffoldKey, 'All items selected');
            },
            icon: const Icon(Icons.select_all),
          ),
        ],
      );
    } else {
      return AppBar(
        leading: currentDir == null
            ? null
            : IconButton(
                onPressed: () {
                  final prevRoute = currentDir!.split('/')..removeLast();
                  _transitionDirectory(prevRoute.join('/') == '' ? null : prevRoute.join('/'));
                },
                icon: const Icon(Icons.arrow_back)),
        title: Text(currentDir != null ? p.basename(currentDir!) : 'File Server'),
      );
    }
  }

  _loadUI(GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    if (_data != null) {
      if (_data!.isNotEmpty) {
        return Stack(
          children: [
            AnimatedOpacity(
              opacity: connectionDone ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: AnimatedScale(
                scale: connectionDone ? 1 : 0.9,
                duration: const Duration(milliseconds: 150),
                child: ListView.builder(
                  itemCount: _data!.length + 1,
                  itemBuilder: (context, index) {
                    if (index != _data!.length) {
                      return ListTile(
                        tileColor: selectedFiles.contains(_data![index]) ? Colors.grey : Colors.transparent,
                        leading: selectMode && selectedFiles.contains(_data![index])
                            ? const Icon(Icons.done)
                            : Icon(getIcon(_data![index])),
                        trailing: selectMode
                            ? null
                            : Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.white),
                                child: PopupMenuButton<ContextMenuItems>(
                                  onSelected: (value) => _contextMenuSelect(value, index, scaffoldKey),
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
                                      value: ContextMenuItems.rename,
                                      child: Text("Rename"),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: ContextMenuItems.download,
                                      child: Text("Download"),
                                    )
                                  ],
                                ),
                              ),
                        title: Text(_data![index].name),
                        onTap: () async {
                          if (selectMode) {
                            selectedFiles.contains(_data![index])
                                ? selectedFiles.remove(_data![index])
                                : selectedFiles.add(_data![index]);
                            if (selectedFiles.isEmpty) {
                              return _setSelectMode(false);
                            }
                            return setState(() {});
                          }
                          if (_data![index].isDirectory) {
                            _transitionDirectory(_data![index].path);
                          } else if (getIcon(_data![index]) == Icons.image) {
                            //TODO: Improve these
                            int counter = -1;
                            int selectedImageIndex = 0;
                            final imagePaths = _data!
                                .map((e) {
                                  if (getIcon(e) == Icons.image) {
                                    final imagePath = e.path;
                                    counter++;
                                    if (imagePath == _data![index].path) selectedImageIndex = counter;
                                    return ImageGalleryImages(path: '$apiUrl/retrieve$imagePath', name: e.name);
                                  }
                                })
                                .whereType<ImageGalleryImages>()
                                .toList();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewImage(
                                  images: imagePaths,
                                  initialIndex: selectedImageIndex,
                                ),
                              ),
                            );
                          } else if (getIcon(_data![index]) == Icons.movie) {
                            final imagePath = _data![index].path;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(url: '$apiUrl/retrieve$imagePath'),
                              ),
                            );
                          } else {
                            //* On tap if file is neither image or video
                            showNotification('Notification Title', 'Notification Body');
                          }
                        },
                        onLongPress: () {
                          selectedFiles.contains(_data![index])
                              ? selectedFiles.remove(_data![index])
                              : selectedFiles.add(_data![index]);
                          if (selectedFiles.isEmpty) {
                            _setSelectMode(false);
                          } else {
                            _setSelectMode(true);
                          }
                        },
                      );
                    } else {
                      return const SizedBox(height: 80);
                    }
                  },
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: connectionDone ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: FutureBuilder(
                future: Future.delayed(const Duration(milliseconds: 100)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  } else {
                    return Container();
                  }
                },
              ),
            )
          ],
        );
      } else {
        return const Center(
          child: Text(
            'No files here',
            style: TextStyle(fontSize: 18),
          ),
        );
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
    final scaffoldKey = Provider.of<AppData>(context).scaffoldMessengerKey;

    return WillPopScope(
      onWillPop: () async {
        //* Exiting out of select mode
        if (selectMode) {
          _setSelectMode(false);
          return false;
        } else if (currentDir != null) {
          final prevRoute = currentDir!.split('/')..removeLast();
          _transitionDirectory(currentDir = prevRoute.join('/') == '' ? null : prevRoute.join('/'));
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
        appBar: _loadAppBar(scaffoldKey),
        drawer: prefs != null ? CustomDrawer(storage: storage, prefs: prefs!, fileTreeData: _fileTreeData) : null,
        body: _loadUI(scaffoldKey),
        floatingActionButton: selectMode
            ? null
            : FloatingActionButton(
                onPressed: () {
                  if (prefs!.getString('userdata') != null && _data != null && connectionDone) {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.all(40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60.0,
                                    height: 60.0,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: IconButton(
                                      splashRadius: 30,
                                      onPressed: () => _uploadFile(scaffoldKey),
                                      icon: const Icon(Icons.upload),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text('Upload'),
                                ],
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 60.0,
                                    height: 60.0,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: IconButton(
                                      splashRadius: 30,
                                      onPressed: () => _newFolder(context, scaffoldKey),
                                      icon: const Icon(Icons.create_new_folder),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text('New folder'),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  } else {
                    showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning);
                  }
                },
                child: const Icon(Icons.add),
              ),
      ),
    );
  }

  //* Init functions to fetch and refresh data
  Future<void> _transitionDirectory(String? newDir) async {
    socket.off(currentDir != null ? currentDir! : '/', _handleSocketEvent);
    currentDir = newDir;
    await _refreshData();
    socket.on(currentDir != null ? currentDir! : '/', _handleSocketEvent);
  }

  Future<void> _refreshData() async {
    setState(() {
      connectionDone = false;
    });
    final newData = await _fetchData(); // fetch new data from the API
    setState(() {
      _data = newData; // update the separate state variable with the new data
    });
  }

  Future<List<ApiListResponse>?> _fetchData() async {
    final pathDir = currentDir != null ? currentDir! : '/';
    final response = await http.get(Uri.parse('$apiUrl/list$pathDir'));
    if (response.statusCode == 200) {
      List<ApiListResponse> parsedResponse =
          jsonDecode(response.body).map((e) => ApiListResponse.fromJson(e)).toList().cast<ApiListResponse>();
      parsedResponse.sort((a, b) {
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

  Future<void> _refreshFileTree() async {
    final newData = await _fetchFileTree(); // fetch new data from the API
    setState(() {
      _fileTreeData = newData; // update the separate state variable with the new data
    });
  }

  Future<Map<String, dynamic>?> _fetchFileTree() async {
    final response = await http.get(Uri.parse('$apiUrl/filetree'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> fileTree = jsonDecode(response.body);
      connectionDoneFileTree = true;
      return fileTree;
    } else {
      connectionDoneFileTree = true;
      return null;
    }
  }

  //* onSelect function for file context menu
  void _contextMenuSelect(ContextMenuItems value, int index, GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    final filePath = _data![index].path;
    final fileUrl = _data![index].isDirectory ? '$apiUrl/list$filePath' : '$apiUrl/retrieve$filePath';
    switch (value) {
      case ContextMenuItems.openinbrowser:
        final uri = Uri.parse(fileUrl);
        canLaunchUrl(uri)
            .then((_) => launchUrl(uri, mode: LaunchMode.externalApplication))
            .catchError((_) => throw 'Could not launch $fileUrl');
        break;
      case ContextMenuItems.copy:
        RichClipboard.setData(RichClipboardData(
          text: Uri.parse(fileUrl).toString(),
          //html: '{"action": "copy", "files": [$fileUrl]}', //TODO: Meant for copying files in app, rn copy parsed link
        )).then((_) => showSnackbar(scaffoldKey, 'Copied link to clipboard'));
        break;
      case ContextMenuItems.rename:
        _renameFile(filePath, scaffoldKey);
        break;
      case ContextMenuItems.download:
        final uri = Uri.parse('$fileUrl?download=true');
        canLaunchUrl(uri)
            .then((_) => launchUrl(uri, mode: LaunchMode.externalApplication))
            .catchError((_) => throw 'Could not launch $fileUrl');
        break;
      default:
    }
  }

  //* State changing interactions
  void _renameFile(String filePath, GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    final newFileNameController = TextEditingController(text: p.basename(filePath));
    final textFieldBorderStyle = OutlineInputBorder(
      borderSide: BorderSide(width: 2, color: Theme.of(context).colorScheme.secondary),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename file'),
          content: TextField(
            controller: newFileNameController,
            cursorColor: Theme.of(context).colorScheme.secondary,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: "New file name",
              labelStyle: const TextStyle(color: Colors.grey),
              enabledBorder: textFieldBorderStyle,
              focusedBorder: textFieldBorderStyle,
              errorBorder: textFieldBorderStyle,
              focusedErrorBorder: textFieldBorderStyle,
            ),
          ),
          actions: <Widget>[
            SizedBox(
              height: 45,
              width: 70,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(
              height: 45,
              width: 70,
              child: TextButton(
                onPressed: () {
                  storage.read(key: 'token').then((token) {
                    if (token != null) {
                      http.patch(
                        Uri.parse('$apiUrl/rename'),
                        body: jsonEncode({"newName": newFileNameController.text.trim(), "pathToFile": filePath}),
                        headers: {"cookie": "token=$token;", "content-type": "application/json"},
                      ).then((value) {
                        if (value.statusCode == 200) {
                          showSnackbar(scaffoldKey, 'Renamed file');
                        } else {
                          showSnackbar(
                              scaffoldKey, 'Something went wrong, try logging in again', SnackbarStatus.warning);
                        }
                      });
                    } else {
                      showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning);
                    }
                    Navigator.pop(context);
                  });
                },
                child: const Text(
                  'Rename',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteFiles(List<String> filePaths, GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm delete?'),
          actions: <Widget>[
            SizedBox(
              height: 45,
              width: 70,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(
              height: 45,
              width: 70,
              child: TextButton(
                onPressed: () {
                  storage.read(key: 'token').then((token) {
                    if (token != null) {
                      http.delete(
                        Uri.parse('$apiUrl/delete'),
                        body: jsonEncode({"pathToFiles": filePaths}),
                        headers: {"cookie": "token=$token;", "content-type": "application/json"},
                      ).then((response) {
                        if (response.statusCode == 200) {
                          showSnackbar(scaffoldKey, 'File(s) deleted');
                        } else {
                          showSnackbar(
                              scaffoldKey, 'Something went wrong, try logging in again', SnackbarStatus.warning);
                        }
                      });
                    } else {
                      showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning);
                    }
                  });
                  setState(() {
                    selectMode = false;
                    selectedFiles = [];
                  });
                  Navigator.pop(context);
                },
                child: const Text(
                  'Yes',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _uploadFile(GlobalKey<ScaffoldMessengerState> scaffoldKey) async {
    var permStorage = await Permission.storage.request();
    if (!permStorage.isGranted) {
      Fluttertoast.showToast(msg: 'Please allow storage permissions to upload');
      if (permStorage.isPermanentlyDenied) {
        await Future.delayed(const Duration(seconds: 1));
        await openAppSettings();
      }
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        final token = await storage.read(key: 'token');
        if (token != null) {
          List<File> files = result.paths.map((path) => File(path!)).toList();
          final pathDir = currentDir != null ? currentDir! : '/';
          final url = Uri.parse('$apiUrl/upload$pathDir');

          final String fileName =
              files.length > 1 ? files.length.toString() : File(files[0].path).uri.pathSegments.last;
          final request = MultipartRequest(
            'POST',
            url,
            onProgress: (int bytes, int total) async {
              uploadProgress = bytes / total * 100;
              await showProgress(
                'Upload',
                files.length > 1 ? 'Uploading $fileName files...' : 'Uploading $fileName...',
                uploadProgress,
              );
            },
          );
          for (int i = 0; i < files.length; i++) {
            request.files.add(await http.MultipartFile.fromPath('upload-file', files[i].path));
          }
          request.headers["cookie"] = "token=$token;";
          if (context.mounted) Navigator.pop(context);
          showSnackbar(scaffoldKey, 'Upload started');
          final response = await request.send();
          if (response.statusCode == 200) {
            showSnackbar(scaffoldKey, 'File(s) uploaded');
          } else {
            showSnackbar(scaffoldKey, 'Something went wrong, try logging in again', SnackbarStatus.warning);
          }
        } else {
          showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning);
        }
      }
    }
  }

  void _newFolder(BuildContext context, GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    final newFolderNameController = TextEditingController();
    final textFieldBorderStyle = OutlineInputBorder(
      borderSide: BorderSide(width: 2, color: Theme.of(context).colorScheme.secondary),
    );
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New folder'),
          content: TextField(
            controller: newFolderNameController,
            cursorColor: Theme.of(context).colorScheme.secondary,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: "Folder name",
              labelStyle: const TextStyle(color: Colors.grey),
              enabledBorder: textFieldBorderStyle,
              focusedBorder: textFieldBorderStyle,
              errorBorder: textFieldBorderStyle,
              focusedErrorBorder: textFieldBorderStyle,
            ),
          ),
          actions: <Widget>[
            SizedBox(
              height: 45,
              width: 70,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            SizedBox(
              height: 45,
              width: 70,
              child: TextButton(
                onPressed: () {
                  final currentPath = currentDir != null ? currentDir! : '/';
                  storage.read(key: 'token').then((token) {
                    if (token != null) {
                      http.post(
                        Uri.parse('$apiUrl/makedir'),
                        body:
                            jsonEncode({"newDirName": newFolderNameController.text.trim(), "currentPath": currentPath}),
                        headers: {"cookie": "token=$token;", "content-type": "application/json"},
                      ).then((value) {
                        if (value.statusCode == 201) {
                          showSnackbar(scaffoldKey, 'Created new folder');
                        } else {
                          showSnackbar(
                              scaffoldKey, 'Something went wrong, try logging in again', SnackbarStatus.warning);
                        }
                      });
                    } else {
                      showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning);
                    }
                    Navigator.pop(context);
                  });
                },
                child: const Text(
                  'Create',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MultipartRequest extends http.MultipartRequest {
  MultipartRequest(
    String method,
    Uri url, {
    this.onProgress,
  }) : super(method, url);

  final void Function(int bytes, int totalBytes)? onProgress;

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    if (onProgress == null) return byteStream;

    final total = contentLength;
    int bytes = 0;

    final t = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytes += data.length;
        onProgress!(bytes, total);
        if (total >= bytes) {
          sink.add(data);
        }
      },
    );
    final stream = byteStream.transform(t);
    return http.ByteStream(stream);
  }
}
