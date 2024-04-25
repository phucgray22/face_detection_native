import 'dart:convert';

import 'package:face_detection_native/debounce.dart';
import 'package:face_detection_native/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, @required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isTrain = true;
  List<Object> list1 = [];
  List<Object> list2 = [];

  String currentEmpId = '';
  String score = '';
  String predictedLabel = '';

  static const _channel = MethodChannel('irhp/channel');
  final urlTrain = 'https://w3vd768m-5177.asse.devtunnels.ms/TrainImage2';
  final urlVerify = 'https://w3vd768m-5177.asse.devtunnels.ms/VerifyImage';
  

  String getID() {
    var uuid = const Uuid();
    return uuid.v1();
  }

  void resetAll() async {
    await StorageUtils.instance.clearAllKeys();
    loadOptions();
  }

  void newID() {
    setState(() {
      currentEmpId = getID();
    });
  }

  void train() async {
    setState(() {
      isTrain = true;
      currentEmpId = getID();
    });
    try {
      await _channel.invokeMethod('openCamera', {
        "steps": stepsTrain.map((e) => e.toJson()).toList(),
        "detections": getDetectionOptions(),
        "function": "training"
      });
    } catch (e) {
      print('%% ${e}');
    }
  }

  void predict() async {
    setState(() {
      isTrain = false;
    });
    try {
      await _channel.invokeMethod('openCamera', {
        "steps": stepsPredict.map((e) => e.toJson()).toList(),
        "detections": getDetectionOptions(),
        "function": "checkIn"
      });
    } catch (e) {
      print('%% ${e}');
    }
  }

  @override
  void initState() {
    super.initState();

    init();
  }

  void init() async {
    currentEmpId = getID();

    await StorageUtils.instance.init();

    loadOptions();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'getListBase64') {
        final listBase64 = call.arguments as List<Object>;

        setState(() {
          if (isTrain) {
            list1 = listBase64;
          } else {
            list2 = listBase64;
          }
        });

        if (isTrain) {
          final res = await http.post(
            Uri.parse(urlTrain),
            body: jsonEncode({
              "empId": currentEmpId,
              "listImageData": listBase64.map((e) {
                return {
                  "fileName": "${getID()}.jpeg",
                  "base64": e,
                };
              }).toList()
            }),
          );

          print('%% ${res.statusCode}');
          print('%% ${res.body}');
        } else {
          final res = await http.post(
            Uri.parse(urlVerify),
            body: jsonEncode({
              "empId": currentEmpId,
              "ImageData": {
                "fileName": "${getID()}.jpeg",
                "base64": listBase64[0],
              }
            }),
          );

          // print('%% ${res.statusCode}');
          // print('%% ${res.body}');
          // print('%% ${res.body}');
          // print('%% ${res.body.runtimeType}');
          // print('%% ${res.bodyBytes}');

          final map = jsonDecode(res.body);

         setState(() {
            score = "${(map["Score"] * 100).toString().substring(0, 4)}%";
            predictedLabel = map["PredictedLabel"];
         });

          // print('%% ${map["Score"]}');
          // print('%% ${map["PredictedLabel"]}');

        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Column(
                    children: [
                      Text(
                        'Current EmpID:\n $currentEmpId',
                        textAlign: TextAlign.center,
                      ),
                      Text('Score: $score',  textAlign: TextAlign.center),
                      Text('PredictedLabel: $predictedLabel',  textAlign: TextAlign.center),
                      // Text('Count train: ${list1.length}'),
                      // Text('Count predict: ${list2.length}')
                    ],
                  ),
                  const SizedBox(height: 20),
                  ..._buildInputs(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: train,
                        child: const Text('TRAIN'),
                      ),
                      const SizedBox(width: 30),
                      ElevatedButton(
                        onPressed: predict,
                        child: const Text('PREDICT'),
                      ),
                      const SizedBox(width: 30),
                      ElevatedButton(
                        onPressed: resetAll,
                        child: const Text('RESET'),
                      ),
                    ],
                  ),
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     const SizedBox(width: 30),
                  //     ElevatedButton(
                  //       onPressed: resetAll,
                  //       child: const Text('Resel all'),
                  //     ),
                  //     // const SizedBox(width: 30),
                  //     // ElevatedButton(
                  //     //   onPressed: newID,
                  //     //   child: const Text('Create new ID'),
                  //     // ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextEditingController smillingController = TextEditingController();
  TextEditingController closeEyeController = TextEditingController();
  TextEditingController openEyeController = TextEditingController();
  TextEditingController turnLeftController = TextEditingController();
  TextEditingController turnRightController = TextEditingController();
  TextEditingController lookUpController = TextEditingController();
  TextEditingController lookDownController = TextEditingController();
  TextEditingController fromSizeController = TextEditingController();
  TextEditingController toSizeController = TextEditingController();
  TextEditingController fromTopController = TextEditingController();
  TextEditingController toTopController = TextEditingController();
  TextEditingController fromLeftController = TextEditingController();
  TextEditingController toLeftController = TextEditingController();
  TextEditingController fromStraightController = TextEditingController();
  TextEditingController toStraightController = TextEditingController();
  TextEditingController fromMidController = TextEditingController();
  TextEditingController toMidController = TextEditingController();

  double getValue(String strValue) {
    if (strValue == null || strValue == '') {
      return 0;
    }

    return double.parse(strValue);
  }

  Map<String, dynamic> getDetectionOptions() {
    return {
      'closeEyeProbability': getValue(closeEyeController.text),
      'openEyeProbability': getValue(openEyeController.text),
      'smilingProbability': getValue(smillingController.text),
      'turnleft': getValue(turnLeftController.text),
      'turnRight': getValue(turnRightController.text),
      'lookUp': getValue(lookUpController.text),
      'lookDown': getValue(lookDownController.text),
      'lookStraight': [
        getValue(fromStraightController.text),
        getValue(toStraightController.text),
      ],
      'mid': [
        getValue(fromMidController.text),
        getValue(toMidController.text),
      ],
      'faceSize': [
        getValue(fromSizeController.text),
        getValue(toSizeController.text)
      ],
      'faceTop': [
        getValue(fromTopController.text),
        getValue(toTopController.text)
      ],
      'faceLeft': [
        getValue(fromLeftController.text),
        getValue(toLeftController.text)
      ],
    };
  }

  void loadOptions() async {
    final smilling = StorageUtils.instance.getDouble(key: 'smilling') ?? 0.8;
    final closeEye = StorageUtils.instance.getDouble(key: 'closeEye') ?? 0.1;
    final openEye = StorageUtils.instance.getDouble(key: 'openEye') ?? 0.9;
    final turnLeft = StorageUtils.instance.getDouble(key: 'turnLeft') ?? -20;
    final turnRight = StorageUtils.instance.getDouble(key: 'turnRight') ?? 40;
    // final lookUp = StorageUtils.instance.getDouble(key: 'lookUp') ?? 30;
    // final lookDown = StorageUtils.instance.getDouble(key: 'lookDown') ?? -15;
    final fromSize = StorageUtils.instance.getDouble(key: 'fromSize') ?? 250;
    final toSize = StorageUtils.instance.getDouble(key: 'toSize') ?? 290;

    final fromTop = StorageUtils.instance.getDouble(key: 'fromTop') ?? 0;
    final toTop = StorageUtils.instance.getDouble(key: 'toTop') ?? 150;
    final fromLeft = StorageUtils.instance.getDouble(key: 'fromLeft') ?? 10;
    final toLeft = StorageUtils.instance.getDouble(key: 'toLeft') ?? 80;

    final fromStraight = StorageUtils.instance.getDouble(key: 'fromStraight') ?? 210;
    final toStraight = StorageUtils.instance.getDouble(key: 'toStraight') ?? 290;

    final fromMid =
        StorageUtils.instance.getDouble(key: 'fromMid') ?? -12;
    final toMid =
        StorageUtils.instance.getDouble(key: 'toMid') ?? 12;

    smillingController.text = '$smilling';
    closeEyeController.text = '$closeEye';
    openEyeController.text = '$openEye';
    turnLeftController.text = '$turnLeft';
    turnRightController.text = '$turnRight';
    // lookUpController.text = '$lookUp';
    // lookDownController.text = '$lookDown';
    fromSizeController.text = '$fromSize';
    toSizeController.text = '$toSize';
    fromTopController.text = '$fromTop';
    toTopController.text = '$toTop';
    fromLeftController.text = '$fromLeft';
    toLeftController.text = '$toLeft';
    fromStraightController.text = '$fromStraight';
    toStraightController.text = '$toStraight';
    fromMidController.text = '$fromMid';
    toMidController.text = '$toMid';
  }

  List<Widget> _buildInputs() {
    return [
      _buildInput(
        title: 'Smilling Probability',
        controller: smillingController,
        id: 'smilling',
      ),
      _buildInput(
        title: 'Eye Probability',
        controller: closeEyeController,
        controller2: openEyeController,
        id: 'closeEye',
        id2: 'openEye',
      ),
      _buildInput(
        title: 'Turn left/right\n(headEulerAngleY)',
        controller: turnLeftController,
        controller2: turnRightController,
        id: 'turnLeft',
        id2: 'turnRight'
      ),
      // _buildInput(
      //   title: 'Turn right\n(headEulerAngleY)',
      //   controller: turnRightController,
      //   id: 'turnRight',
      // ),
      // _buildInput(
      //   title: 'Look up/down\n(headEulerAngleX)',
      //   controller: lookUpController,
      //   controller2: lookDownController,
      //   id: 'lookUp',
      //   id2: 'lookDown'
      // ),
      // _buildInput(
      //   title: 'Look down\n(headEulerAngleX)',
      //   controller: lookDownController,
      //   id: 'lookDown',
      // ),
      _buildInput(
        title: 'Look straight B\n(headEulerAngleX)',
        controller: fromMidController,
        controller2: toMidController,
        id: 'fromMid',
        id2: 'toMid',
      ),
      
      _buildInput(
        title: 'Look straight A\n(frame.midX)',
        controller: fromStraightController,
        controller2: toStraightController,
        id: 'fromStraight',
        id2: 'toStraight',
      ),
      
      _buildInput(
        title: 'Face size\n(frame.height)',
        controller: fromSizeController,
        controller2: toSizeController,
        id: 'fromSize',
        id2: 'toSize',
      ),
      _buildInput(
        title: 'Face top\n(frame.origin.x)',
        controller: fromTopController,
        controller2: toTopController,
        id: 'fromTop',
        id2: 'toTop',
      ),
      _buildInput(
        title: 'Face left\n(frame.origin.y)',
        controller: fromLeftController,
        controller2: toLeftController,
        id: 'fromLeft',
        id2: 'toLeft',
      ),
    ];
  }

  Widget _buildInput({
    TextEditingController controller,
    TextEditingController controller2,
    String id = '',
    String id2 = '',
    String title = '',
  }) {
    const decoration = InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          width: 1,
          color: Colors.grey,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          width: 1,
          color: Colors.blueAccent,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$title: ',
          ),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 40,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  decoration: decoration,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [
                    CommaFormatter(),
                    FilteringTextInputFormatter.allow(
                      RegExp(
                        // r'^[0-9]*[.]?[0-9]*',
                        r'^-?[0-9]*[.]?[0-9]*'
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    DebounceUtils.debounce(
                      tag: id,
                      milliseconds: 500,
                      callback: () {
                        final doubleVal = double.tryParse(value);

                        if (doubleVal != null) {
                          StorageUtils.instance
                              .setDouble(key: id, val: doubleVal);
                        }
                      },
                    );
                  },
                  onTapOutside: (_) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ),
              if (controller2 != null)
                Container(
                  margin: const EdgeInsets.only(left: 15),
                  width: 100,
                  height: 40,
                  child: TextField(
                    controller: controller2,
                    textAlign: TextAlign.center,
                    decoration: decoration,
                    onChanged: (value) {
                      DebounceUtils.debounce(
                        tag: id2,
                        milliseconds: 500,
                        callback: () {
                          final doubleVal = double.tryParse(value);

                          if (!doubleVal.isNaN && doubleVal != null) {
                            StorageUtils.instance
                                .setDouble(key: id2, val: doubleVal);
                          }
                        },
                      );
                    },
                    onTapOutside: (_) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
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

const stepsTrain = [
  Step('turnLeft', 'Quay trái'),
  Step('smile', 'Cười'),
  Step('closeLeftEye', 'Nhắm mắt trái'),
  Step('closeRightEye', 'Nhắm mắt phải'),
  Step('turnRight', 'Quay phải'),
  // Step('lookUp', 'Ngước lên'),
  // Step('lookDown', 'Cúi xuống'),
];

const stepsPredict = [
  // Step('turnLeft', 'Quay trái'),
  Step('smile', 'Cười'),
  // Step('closeLeftEye', 'Nhắm mắt trái'),
  // Step('closeRightEye', 'Nhắm mắt phải'),
  // Step('turnRight', 'Quay mặt sang phải')
];

// -15 <  30 >

class CommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String _text = newValue.text;

    return newValue.copyWith(
      text: _text.replaceAll(',', '.'),
    );
  }
}
