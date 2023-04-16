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
