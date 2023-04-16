import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/files.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
              backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
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
                fontFamily: 'Futura',
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Theme.of(context).colorScheme.secondary,
            selectionColor: Theme.of(context).colorScheme.secondary,
            selectionHandleColor: Theme.of(context).colorScheme.tertiary,
          )),
      home: const MainPage(),
    );
  }
}

/* class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pressed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
 */