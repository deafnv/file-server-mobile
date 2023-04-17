import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'screens/files.dart';

class DownloadClass {
  @pragma('vm:entry-point')
  static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }
}

Future main() async {
  await dotenv.load(fileName: ".env");
  await FlutterDownloader.initialize(
    debug: true,
  );
  FlutterDownloader.registerCallback(DownloadClass.downloadCallback);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldKey,
      title: 'File Server',
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.white,
          colorScheme: const ColorScheme.dark(
            primary: Color.fromARGB(252, 37, 37, 37),
            secondary: Colors.lightBlue,
            tertiary: Color.fromARGB(255, 226, 57, 170),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
                return Theme.of(context).colorScheme.secondary;
              }),
            ),
          ),
          /* ColorScheme.fromSwatch().copyWith(
      //TODO: add method for user to change theme in app & more themes
      primary: Color.fromARGB(252, 37, 37, 37),
      secondary: Colors.lightBlue,
    ), */
          //scaffoldBackgroundColor: Color.fromARGB(235, 255, 255, 255),
          textTheme: Theme.of(context).textTheme.apply(
                fontFamily: 'Futura', //FIXME: change this
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Theme.of(context).colorScheme.secondary,
            selectionColor: Theme.of(context).colorScheme.secondary,
            selectionHandleColor: Theme.of(context).colorScheme.tertiary,
          )),
      home: MainPage(
        scaffoldMessengerKey: _scaffoldKey,
      ),
    );
  }
}
