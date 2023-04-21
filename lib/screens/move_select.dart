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

class MoveSelect extends StatefulWidget {
  const MoveSelect({super.key, this.currentDir, required this.storage, required this.filesToMove});

  final String? currentDir;
  final FlutterSecureStorage storage;
  final List<String> filesToMove;

  @override
  State<MoveSelect> createState() => _MoveSelectState();
}

class _MoveSelectState extends State<MoveSelect> {
  final apiUrl = dotenv.env['API_URL']!;

  ApiListResponseList? _data;
  bool connectionDone = false;

  @override
  void initState() {
    super.initState();

    //* Get data on init
    _fetchData().then((data) {
      setState(() {
        _data = data; //* Store the initial data in the separate state variable
      });
    });
  }

  _loadUI(GlobalKey<ScaffoldMessengerState> scaffoldKey) {
    if (connectionDone) {
      if (_data != null) {
        if (_data!.files.isNotEmpty) {
          return ListView.builder(
            itemCount: _data!.files.length,
            itemBuilder: (context, index) {
              if (_data!.files[index].isDirectory) {
                return ListTile(
                  leading: Icon(getIcon(_data!.files[index])),
                  title: Text(_data!.files[index].name),
                  onTap: () => Navigator.pushReplacement(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: MoveSelect(
                        storage: widget.storage,
                        filesToMove: widget.filesToMove,
                        currentDir: _data!.files[index].path,
                      ),
                    ),
                  ),
                );
              } else {
                return Opacity(
                  opacity: 0.4,
                  child: ListTile(
                    leading: Icon(getIcon(_data!.files[index])),
                    title: Text(_data!.files[index].name),
                  ),
                );
              }
            },
          );
        } else {
          return const Center(
            child: Text('No files here'),
          );
        }
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
    final scaffoldKey = Provider.of<AppData>(context).scaffoldMessengerKey;

    return WillPopScope(
      onWillPop: () async {
        if (widget.currentDir != null) {
          final prevRoute = widget.currentDir!.split('/')..removeLast();
          Navigator.pushReplacement(
            context,
            PageTransition(
              type: PageTransitionType.leftToRight,
              child: prevRoute.join('/') == ''
                  ? MoveSelect(
                      storage: widget.storage,
                      filesToMove: widget.filesToMove,
                    )
                  : MoveSelect(
                      storage: widget.storage,
                      filesToMove: widget.filesToMove,
                      currentDir: prevRoute.join('/'),
                    ),
            ),
          );
          return false;
        } else {
          Navigator.pushReplacement(
            context,
            PageTransition(
              type: PageTransitionType.leftToRight,
              child: MainPage(
                currentDir: p.dirname(widget.filesToMove[0]) == '/' ? null : p.dirname(widget.filesToMove[0]),
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
                if (widget.currentDir != null) {
                  final prevRoute = widget.currentDir!.split('/')..removeLast();
                  Navigator.pushReplacement(
                    context,
                    PageTransition(
                      type: PageTransitionType.leftToRight,
                      child: prevRoute.join('/') == ''
                          ? MoveSelect(
                              storage: widget.storage,
                              filesToMove: widget.filesToMove,
                            )
                          : MoveSelect(
                              storage: widget.storage,
                              filesToMove: widget.filesToMove,
                              currentDir: prevRoute.join('/'),
                            ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    PageTransition(
                      type: PageTransitionType.leftToRight,
                      child: MainPage(currentDir: p.dirname(widget.filesToMove[0])),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.arrow_back)),
          title: Text(widget.currentDir != null ? p.basename(widget.currentDir!) : 'Root'),
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
                        currentDir: p.dirname(widget.filesToMove[0]) == '/' ? null : p.dirname(widget.filesToMove[0]),
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
                    final currentPath = widget.currentDir != null ? widget.currentDir! : '/';
                    widget.storage.read(key: 'token').then((token) {
                      if (token != null) {
                        http.post(
                          Uri.parse('$apiUrl/move'),
                          body: jsonEncode({"pathToFiles": widget.filesToMove, "newPath": currentPath}),
                          headers: {"cookie": "token=$token;", "content-type": "application/json"},
                        ).then((value) {
                          if (value.statusCode == 200) {
                            _showSnackbar(scaffoldKey, 'Moved file(s)');
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
                          child: MainPage(currentDir: widget.currentDir),
                        ),
                      );
                    });
                  },
                  child: Text(
                    'Move',
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

  Future<ApiListResponseList?> _fetchData() async {
    final pathDir = widget.currentDir != null ? widget.currentDir! : '/';
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
}
