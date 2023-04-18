import 'dart:convert';

import 'package:file_server_mobile/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:file_server_mobile/app_data.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        child: Column(
          children: [
            const UserDetails(),
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
}

class UserDetails extends StatefulWidget {
  const UserDetails({super.key});

  @override
  State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
  late SharedPreferences prefs;
  late FlutterSecureStorage storage;

  @override
  void initState() {
    super.initState();

    AndroidOptions getAndroidOptions() => const AndroidOptions(
          encryptedSharedPreferences: true,
        );
    storage = FlutterSecureStorage(aOptions: getAndroidOptions());
  }

  Future<List<Widget>> _getUserDrawerDetails(GlobalKey<NavigatorState> navigatorKey) async {
    prefs = await SharedPreferences.getInstance();

    final String? userDataString = prefs.getString('userdata');

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
            await prefs.remove('userdata');
            await storage.delete(key: 'token');
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

  @override
  Widget build(BuildContext context) {
    final navigatorKey = Provider.of<AppData>(context).navigatorKey;

    return FutureBuilder(
      future: _getUserDrawerDetails(navigatorKey),
      builder: (BuildContext context, AsyncSnapshot<List<Widget>> snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return SizedBox(
            height: MediaQuery.of(context).size.height / 3.7,
            width: MediaQuery.of(context).size.width,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColorDark,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: snapshot.data!,
              ),
            ),
          );
        } else {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      },
    );
  }
}
