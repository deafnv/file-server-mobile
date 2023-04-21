import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:page_transition/page_transition.dart';

import 'package:file_server_mobile/screens/files.dart';
import 'package:file_server_mobile/app_data.dart';
import 'package:file_server_mobile/screens/login.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key, required this.storage, required this.prefs, required this.fileTreeData});
  //TODO: Haven't passed in connectionstate for fileTreeData

  final FlutterSecureStorage storage;
  final SharedPreferences prefs;
  final Map<String, dynamic>? fileTreeData;

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  @override
  Widget build(BuildContext context) {
    final navigatorKey = Provider.of<AppData>(context).navigatorKey;
    final String? userDataString = widget.prefs.getString('userdata');

    return SafeArea(
      child: Drawer(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height / 3.7,
              width: MediaQuery.of(context).size.width,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColorDark,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _getUserDrawerDetails(userDataString, navigatorKey),
                ),
              ),
            ),
            Expanded(
              child: _loadFileTreeWidget(),
            )
          ],
        ),
      ),
    );
  }

  _loadFileTreeWidget() {
    //TODO: Show error if failed to load
    if (widget.fileTreeData != null) {
      return FileTreeWidget(fileTreeData: widget.fileTreeData!);
    } else {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }

  _getUserDrawerDetails(String? userDataString, GlobalKey<NavigatorState> navigatorKey) {
    if (userDataString != null) {
      return [
        const Text(
          'Welcome,',
          style: TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          jsonDecode(userDataString)?["user"],
          style: const TextStyle(fontSize: 20),
        ),
        ElevatedButton(
          onPressed: () async {
            await widget.prefs.remove('userdata');
            await widget.storage.delete(key: 'token');
            navigatorKey.currentState!.pop();
          },
          child: const Text('Logout'),
        ),
      ];
    } else {
      return [
        const Text(
          'Not signed in',
          style: TextStyle(fontSize: 24),
        ),
        const SizedBox(
          height: 12,
        ),
        const Text(
          'You won\'t be able to make changes to any files',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(
          height: 36,
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginPage(),
              ),
            );
          },
          child: const Text('Login'),
        ),
      ];
    }
  }
}

class FileTreeWidget extends StatefulWidget {
  const FileTreeWidget({super.key, required this.fileTreeData, this.level = 0, this.prevDir = '/', this.expand1});

  final Map<String, dynamic> fileTreeData;
  final int level;
  final String prevDir;
  final List<String>? expand1;

  @override
  State<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends State<FileTreeWidget> with TickerProviderStateMixin {
  List<AnimationController> _controllers = [];
  List<String> expand = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < widget.fileTreeData.length; i++) {
      _controllers.add(AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        upperBound: 0.5,
      ));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = widget.fileTreeData.keys.toList()..sort();
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: ClipRect(
        child: SizedBox(
          height: (widget.expand1?.contains(widget.prevDir) ?? false) || widget.level == 0 ? null : 0,
          child: ListView.builder(
            primary: widget.level == 0,
            shrinkWrap: true,
            itemCount: widget.fileTreeData.length,
            itemBuilder: (context, index) {
              final subtree = widget.fileTreeData[keys[index]];
              final subtreeHasFolders = subtree.keys.isNotEmpty;
              final filePath = p.join(widget.prevDir, keys[index]);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      subtreeHasFolders
                          ? RotationTransition(
                              turns: Tween(begin: 0.0, end: 1.0).animate(_controllers[index]),
                              child: IconButton(
                                splashRadius: 24,
                                onPressed: () {
                                  expand.contains(filePath) ? expand.remove(filePath) : expand.add(filePath);
                                  setState(() {
                                    if (!expand.contains(filePath)) {
                                      _controllers[index].reverse(from: 0.5);
                                    } else {
                                      _controllers[index].forward(from: 0.0);
                                    }
                                  });
                                },
                                icon: const Icon(Icons.expand_less),
                              ),
                            )
                          : Container(width: 48),
                      Expanded(
                        child: ListTile(
                          title: Text(keys[index], style: const TextStyle(fontSize: 16)),
                          horizontalTitleGap: 0,
                          dense: true,
                          visualDensity: const VisualDensity(vertical: 0),
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              PageTransition(
                                type: PageTransitionType.leftToRight,
                                child: MainPage(currentDir: filePath),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                  if (subtreeHasFolders)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: FileTreeWidget(
                        fileTreeData: widget.fileTreeData[keys[index]],
                        level: widget.level + 1,
                        prevDir: filePath,
                        expand1: expand,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
