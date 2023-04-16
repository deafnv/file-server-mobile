import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../types.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key, this.currentDir});

  final ApiListResponse? currentDir;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Future<ApiListResponseList?> _fetchData() async {
    final apiUrl = dotenv.env['API_URL']!;
    final pathDir = widget.currentDir == null ? '/' : widget.currentDir!.path;
    final response = await http.get(Uri.parse('$apiUrl/list$pathDir'));
    if (response.statusCode == 200) {
      var parsedResponse =
          ApiListResponseList.fromJson(jsonDecode(response.body));
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
                title: Text(snapshot.data!.files[index].name),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MainPage(currentDir: snapshot.data!.files[index])),
                  );
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
    return FutureBuilder(
        future: _fetchData(),
        builder: (BuildContext context,
            AsyncSnapshot<ApiListResponseList?> snapshot) {
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
