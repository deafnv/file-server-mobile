import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:file_server_mobile/types.dart';
import 'package:file_server_mobile/app_data.dart';
import 'package:file_server_mobile/screens/files.dart';

enum DirectorySelectMethods { move, copy, shortcut }

class DirectorySelectDetails {
  static final Map<DirectorySelectMethods, String> buttonTextMap = {
    DirectorySelectMethods.move: 'Move',
    DirectorySelectMethods.copy: 'Copy',
    DirectorySelectMethods.shortcut: 'Create shortcut',
  };

  static final Map<DirectorySelectMethods, String> snackbarTextMap = {
    DirectorySelectMethods.move: 'Moved file(s)',
    DirectorySelectMethods.copy: 'Copied file(s)',
    DirectorySelectMethods.shortcut: 'Created shortcut',
  };

  static final Map<DirectorySelectMethods, String> apiRouteMap = {
    DirectorySelectMethods.move: 'move',
    DirectorySelectMethods.copy: 'copy',
    DirectorySelectMethods.shortcut: 'shortcut',
  };

  static final Map<DirectorySelectMethods, String> _appBarTitleMap = {
    DirectorySelectMethods.move: 'Move to:',
    DirectorySelectMethods.copy: 'Copy to:',
    DirectorySelectMethods.shortcut: 'Shortcut to:',
  };

  static String getAppBarTitle(DirectorySelectMethods method, String currentPath) {
    return '${_appBarTitleMap[method]!} $currentPath';
  }

  static String getApiBody(DirectorySelectMethods method, List<String> selectedFiles, String path) {
    final Map<DirectorySelectMethods, String> apiBodyMap = {
      DirectorySelectMethods.move: jsonEncode({"pathToFiles": selectedFiles, "newPath": path}),
      DirectorySelectMethods.copy: jsonEncode({"pathToFiles": selectedFiles, "newPath": path}),
      DirectorySelectMethods.shortcut: jsonEncode({"target": selectedFiles[0], "currentPath": path}),
    };

    return apiBodyMap[method]!;
  }
}

class DirectorySelect extends StatefulWidget {
  const DirectorySelect({
    super.key,
    this.currentDir,
    required this.storage,
    required this.selectedFiles,
    required this.method,
  });

  final String? currentDir;
  final FlutterSecureStorage storage;
  final List<String> selectedFiles;
  final DirectorySelectMethods method;

  @override
  State<DirectorySelect> createState() => _DirectorySelectState();
}

class _DirectorySelectState extends State<DirectorySelect> {
  final apiUrl = dotenv.env['API_URL']!;

  String? currentDir;

  List<ApiListResponse>? _data;
  bool connectionDone = false;

  @override
  void initState() {
    super.initState();

    if (widget.currentDir != null) currentDir = widget.currentDir;

    //* Get data on init
    _fetchData().then((data) {
      setState(() {
        _data = data; //* Store the initial data in the separate state variable
      });
    });
  }

  _loadUI(GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    loadFileIcons(int index) {
      final hexColor = _data![index].metadata?.color.replaceAll('#', '');

      if (_data![index].isShortcut != null) {
        return Stack(
          children: [
            Icon(
              getIcon(_data![index]),
              color: _data![index].metadata != null && hexColor != null && hexColor.isNotEmpty
                  ? HexColor.fromHex(hexColor)
                  : null,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 15,
                    width: 15,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const RotatedBox(
                    quarterTurns: 3,
                    child: Icon(
                      Icons.redo,
                      size: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      } else {
        return Icon(
          getIcon(_data![index]),
          color: _data![index].metadata != null && hexColor != null && hexColor.isNotEmpty
              ? HexColor.fromHex(hexColor)
              : null,
        );
      }
    }

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
                  itemCount: _data!.length,
                  itemBuilder: (context, index) {
                    if (_data![index].isDirectory) {
                      return ListTile(
                        leading: loadFileIcons(index),
                        title: Text(_data![index].name),
                        onTap: () {
                          currentDir = _data![index].path;
                          _refreshData();
                        },
                      );
                    } else {
                      return Opacity(
                        opacity: 0.4,
                        child: ListTile(
                          leading: Icon(getIcon(_data![index])),
                          title: Text(_data![index].name),
                        ),
                      );
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
            ),
          ],
        );
      } else {
        return const Center(
          child: Text('No files here'),
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
        if (currentDir != null) {
          final prevRoute = currentDir!.split('/')..removeLast();
          currentDir = prevRoute.join('/') == '' ? null : prevRoute.join('/');
          _refreshData();
          return false;
        } else {
          Navigator.pushReplacement(
            context,
            PageTransition(
              type: PageTransitionType.leftToRight,
              child: MainPage(
                currentDir: p.dirname(widget.selectedFiles[0]) == '/' ? null : p.dirname(widget.selectedFiles[0]),
              ),
            ),
          );
          return false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              onPressed: () {
                if (currentDir != null) {
                  final prevRoute = currentDir!.split('/')..removeLast();
                  currentDir = prevRoute.join('/') == '' ? null : prevRoute.join('/');
                  _refreshData();
                } else {
                  Navigator.pushReplacement(
                    context,
                    PageTransition(
                      type: PageTransitionType.leftToRight,
                      child: MainPage(
                        currentDir:
                            p.dirname(widget.selectedFiles[0]) == '/' ? null : p.dirname(widget.selectedFiles[0]),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.arrow_back)),
          title: Text(currentDir != null
              ? DirectorySelectDetails.getAppBarTitle(widget.method, p.basename(currentDir!))
              : DirectorySelectDetails.getAppBarTitle(widget.method, 'Root')),
        ),
        body: _loadUI(scaffoldKey),
        bottomSheet: Container(
          height: 70,
          width: double.infinity,
          color: Colors.black45,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    PageTransition(
                      type: PageTransitionType.leftToRight,
                      child: MainPage(
                        currentDir:
                            p.dirname(widget.selectedFiles[0]) == '/' ? null : p.dirname(widget.selectedFiles[0]),
                      ),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    //TODO: Prevent moving into same directory
                    final currentPath = currentDir != null ? currentDir! : '/';
                    widget.storage.read(key: 'token').then((token) {
                      if (token != null) {
                        http.post(
                          Uri.parse('$apiUrl/${DirectorySelectDetails.apiRouteMap[widget.method]}'),
                          body: DirectorySelectDetails.getApiBody(widget.method, widget.selectedFiles, currentPath),
                          headers: {"cookie": "token=$token;", "content-type": "application/json"},
                        ).then((value) {
                          if (value.statusCode == 200) {
                            _showSnackbar(scaffoldKey, DirectorySelectDetails.snackbarTextMap[widget.method]!);
                          } else {
                            _showSnackbar(
                                scaffoldKey, 'Something went wrong, try logging in again', SnackbarStatus.warning);
                          }
                        });
                      } else {
                        _showSnackbar(scaffoldKey, 'You need to log in for this action', SnackbarStatus.warning);
                      }
                      Navigator.pushReplacement(
                        context,
                        PageTransition(
                          type: PageTransitionType.leftToRight,
                          child: MainPage(currentDir: currentDir),
                        ),
                      );
                    });
                  },
                  child: Text(
                    DirectorySelectDetails.buttonTextMap[widget.method]!,
                    style: TextStyle(color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackbar(GlobalKey<ScaffoldMessengerState> scaffoldKey, String message, [SnackbarStatus? status]) {
    Color snackbarBackground;
    switch (status) {
      case SnackbarStatus.warning:
        snackbarBackground = Colors.red;
        break;
      default:
        snackbarBackground = Colors.white;
    }

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: snackbarBackground,
    );

    scaffoldKey.currentState!.clearSnackBars();
    scaffoldKey.currentState!.showSnackBar(snackBar);
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
}
