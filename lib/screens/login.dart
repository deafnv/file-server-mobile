import 'dart:convert';

import 'package:file_server_mobile/screens/files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:file_server_mobile/app_data.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final apiUrl = dotenv.env['API_URL']!;
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addUserBorderStyle = OutlineInputBorder(
      borderSide: BorderSide(width: 2, color: Theme.of(context).colorScheme.secondary),
    );

    final navigatorKey = Provider.of<AppData>(context).navigatorKey;
    final scaffoldKey = Provider.of<AppData>(context).scaffoldMessengerKey;
    GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

    return Scaffold(
      key: _scaffoldKey,
      body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 80, 30, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: SizedBox(
                  width: 200,
                  child: Image.asset('assets/app_logo.png'),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: usernameController,
                cursorColor: Theme.of(context).colorScheme.secondary,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: "Username",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: addUserBorderStyle,
                  focusedBorder: addUserBorderStyle,
                  errorBorder: addUserBorderStyle,
                  focusedErrorBorder: addUserBorderStyle,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                cursorColor: Theme.of(context).colorScheme.secondary,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: addUserBorderStyle,
                  focusedBorder: addUserBorderStyle,
                  errorBorder: addUserBorderStyle,
                  focusedErrorBorder: addUserBorderStyle,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 24),
                ),
                onPressed: () async {
                  showDialog(
                    barrierDismissible: true,
                    context: context,
                    builder: (context) => Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  );

                  final username = usernameController.text.trim();
                  final response = await http.post(
                    Uri.parse('$apiUrl/authorize/get'),
                    body: jsonEncode({"user": username}),
                    headers: {"X-API-Key": passwordController.text.trim(), "content-type": "application/json"},
                  );

                  //* If response returned with set-cookie header, set cookie
                  String? rawCookie = response.headers['set-cookie'];
                  if (rawCookie != null) {
                    final SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setString('userdata', '{"user": "$username"}');

                    AndroidOptions getAndroidOptions() => const AndroidOptions(
                          encryptedSharedPreferences: true,
                        );
                    final storage = FlutterSecureStorage(aOptions: getAndroidOptions());

                    int index = rawCookie.indexOf(';');
                    await storage.write(
                      key: 'token',
                      value: ((index == -1) ? rawCookie : rawCookie.substring(0, index)).replaceAll('token=', ''),
                      aOptions: getAndroidOptions(),
                    );

                    _scaffoldKey.currentState!.closeEndDrawer();
                    navigatorKey.currentState!.pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
                  } else {
                    scaffoldKey.currentState!.showSnackBar(const SnackBar(
                      backgroundColor: Colors.red,
                      content: Text('Wrong password'),
                    ));
                    navigatorKey.currentState!.pop();
                  }
                },
              ),
            ],
          )),
    );
  }
}
