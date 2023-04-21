import 'package:flutter/material.dart';

class ApiListResponse {
  final String name;
  final String path;
  final int size;
  final String created;
  final String modified;
  final bool isDirectory;

  const ApiListResponse({
    required this.name,
    required this.path,
    required this.size,
    required this.created,
    required this.modified,
    required this.isDirectory,
  });

  factory ApiListResponse.fromJson(Map<String, dynamic> json) {
    return ApiListResponse(
        name: json['name'],
        path: json['path'],
        size: json['size'],
        created: json['created'],
        modified: json['modified'],
        isDirectory: json['isDirectory']);
  }
}

class ApiListResponseList {
  final List<ApiListResponse> files;

  const ApiListResponseList({
    required this.files,
  });

  factory ApiListResponseList.fromJson(List<dynamic> json) {
    final List<ApiListResponse> files = [];
    for (final file in json) {
      files.add(ApiListResponse.fromJson(file));
    }
    return ApiListResponseList(files: files);
  }
}

enum SnackbarStatus { warning }

IconData? getIcon(ApiListResponse file) {
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
