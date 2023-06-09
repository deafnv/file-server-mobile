import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'package:file_server_mobile/main.dart';

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}

extension SortResponse on List<ApiListResponse> {
  void sortResponse() {
    RegExp alphaNumeric = RegExp(r'^[a-zA-Z0-9]+$');
    sort((a, b) {
      final aIsShortcut = a.isShortcut != null;
      final bIsShortcut = b.isShortcut != null;
      //* Sort shortcut directories
      if (aIsShortcut && a.isDirectory && !bIsShortcut && b.isDirectory) return -1;
      if (!aIsShortcut && a.isDirectory && bIsShortcut && b.isDirectory) return 1;

      //* Sort directories
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      //* Sort shortcut files
      if (aIsShortcut && !a.isDirectory && !bIsShortcut && !b.isDirectory) return -1;
      if (!aIsShortcut && !a.isDirectory && bIsShortcut && !b.isDirectory) return 1;

      if (!alphaNumeric.hasMatch(a.name[0]) && alphaNumeric.hasMatch(b.name[0])) return -1;
      if (alphaNumeric.hasMatch(a.name[0]) && !alphaNumeric.hasMatch(b.name[0])) return 1;

      return a.name.compareTo(b.name);
    });
  }
}

class Metadata {
  final String color;

  const Metadata({
    required this.color,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      color: json['color'],
    );
  }
}

class Shortcut {
  final String shortcutName;
  final String shortcutPath;

  const Shortcut({
    required this.shortcutName,
    required this.shortcutPath,
  });

  factory Shortcut.fromJson(Map<String, dynamic> json) {
    return Shortcut(
      shortcutName: json['shortcutName'],
      shortcutPath: json['shortcutPath'],
    );
  }
}

class ApiListResponse {
  final String name;
  final String path;
  final int size;
  final String created;
  final String modified;
  final bool isDirectory;
  final Shortcut? isShortcut;
  final Metadata? metadata;

  const ApiListResponse({
    required this.name,
    required this.path,
    required this.size,
    required this.created,
    required this.modified,
    required this.isDirectory,
    this.isShortcut,
    this.metadata,
  });

  factory ApiListResponse.fromJson(Map<String, dynamic> json) {
    return ApiListResponse(
      name: json['name'],
      path: json['path'],
      size: json['size'],
      created: json['created'],
      modified: json['modified'],
      isDirectory: json['isDirectory'],
      isShortcut: json['isShortcut'] != null ? Shortcut.fromJson(json['isShortcut']) : null,
      metadata: json['metadata'] != null ? Metadata.fromJson(json['metadata']) : null,
    );
  }
}

class ImageGalleryImages {
  final String path;
  final String name;

  const ImageGalleryImages({
    required this.path,
    required this.name,
  });
}

class VideoFile {
  final String url;
  final String name;

  const VideoFile({
    required this.url,
    required this.name,
  });
}

class AudioFile {
  final String url;
  final String name;

  const AudioFile({
    required this.url,
    required this.name,
  });
}

enum SnackbarStatus { warning }

//* Utility functions
void showSnackbar(GlobalKey<ScaffoldMessengerState> scaffoldKey, String message, [SnackbarStatus? status]) {
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

class MultipartRequest extends http.MultipartRequest {
  /// Creates a new [MultipartRequest].
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

IconData? getIcon(ApiListResponse file) {
  if (file.isDirectory) return Icons.folder;
  final splitName = file.name.split('.');
  final extension = splitName[splitName.length - 1].toLowerCase();
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

Future<void> showProgress(
  String title,
  String body,
  double progress,
) async {
  final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'upload',
    'Uploads',
    'Upload progress notifications',
    importance: Importance.low,
    priority: Priority.high,
    ticker: 'ticker',
    showProgress: true,
    maxProgress: 100,
    enableVibration: false,
    progress: progress.toInt(),
  );

  final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  final progressText = progress.toStringAsFixed(1);

  await flutterLocalNotificationsPlugin.show(
    0,
    '$title $progressText%',
    body,
    platformChannelSpecifics,
  );
}

Future<void> showNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'general', 'General', 'General notifications',
      importance: Importance.max, priority: Priority.high, ticker: 'ticker');

  const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
}
