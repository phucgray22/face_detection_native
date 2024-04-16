import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, @required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  static const _channel = MethodChannel('irhp/channel');

  void _incrementCounter() async {
    try {
      final result = await _channel.invokeMethod('openCamera', {
        "steps": steps.map((e) => e.toJson()).toList(),
        "detections": detections,
      });
    } catch (e) {
      print('%% ${e}');
    }
  }

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if(call.method == 'getListBase64') {
        // print('%% ${call.arguments.runtimeType}');
        final listBase64 = call.arguments as List<Object>;

        print('%%length: ${listBase64.length}');

        if(listBase64.isNotEmpty == true) {
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
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
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class Step {
  final String id;
  final String description;
  const Step(this.id, this.description);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
    };
  }
}

const steps = [
  Step('smile', 'Cười'),
  Step('turnLeft', 'Quay trái'),
  Step('closeLeftEye', 'Nhắm mắt trái'),
  Step('closeRightEye', 'Nhắm mắt phải'),
  Step('turnRight', 'Quay mặt sang phải')
];

const  detections = {
  'smiling': {
    'smilingProbability': 0.3,
  },
  'turnLeft': {
    'headEulerAngleY': 30.0,
  },
  'turnRight': {
    'headEulerAngleY': -40,
  },
  'closeLeftEye': {
    'closeProbability': 0.1,
    'openProbability': 0.3,
  },
  'faceInCamera': {
    'height': [150, 400.5],
    'width': [150, 400],
    'top': [100, 290],
    'left': [10, 220],
  }
};
