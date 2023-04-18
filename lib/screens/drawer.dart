import 'dart:convert';

import 'package:file_server_mobile/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_server_mobile/app_data.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key, required this.storage, required this.prefs});

  final FlutterSecureStorage storage;
  final SharedPreferences prefs;

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
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 1,
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      ListTile(
                        title: const Text('File tree here'),
                        horizontalTitleGap: 0,
                        visualDensity: const VisualDensity(vertical: 0),
                        onTap: () {},
                      ),
                    ],
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
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
