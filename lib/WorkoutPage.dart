import 'dart:math';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'BluetoothManager.dart';
import 'PairingPage.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import 'RiderData.dart';


Random random = Random();

void sayHi() async {
  final int randomNum = random.nextInt(100);
  String dataStr = "randomNum:$randomNum";
  print("Broadcasting data: $dataStr");
  BluetoothManager.instance.broadcastString(dataStr);
}

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<WorkoutPage> createState() => _WorkoutPage();
}

class _WorkoutPage extends State<WorkoutPage> {
  static const platform = MethodChannel('edu.uf.karoo_collab');

  double heartRate = 0;
  double power = 0;
  double speed = 0;

  _WorkoutPage() {
    BluetoothManager.instance.deviceDataStream.listen((event) {
      final map = event.values.first;

      for(final key in map.keys) {
        switch(key) {
          case "heartRate":
            setState(() {
              heartRate = double.parse(map[key] ?? "-1");
            });
            try {
              platform.invokeListMethod('setPartnerHR', {"hr": heartRate});
              Logger.root.info('Partner HR set to $heartRate');
            } on PlatformException catch (e) {
              Logger.root.severe('Failed to set partner HR: $e');
            }
            break;
          case "power":
            setState(() {
              power = double.parse(map[key] ?? "-1");
            });
            try {
              platform.invokeListMethod('setPartnerPower', {"power": power});
              Logger.root.info('Partner power set to $power');
            } on PlatformException catch (e) {
              Logger.root.severe('Failed to set partner power: $e');
            }
            break;
          case "speed":
            setState(() {
              speed = double.parse(map[key] ?? "-1");
            });
            try {
              platform.invokeListMethod('setPartnerSpeed', {"speed": speed});
              Logger.root.info('Partner power set to $speed');
            } on PlatformException catch (e) {
              Logger.root.severe('Failed to set partner speed: $e');
            }
            break;
          default:
            Logger.root.warning('Unknown map key received: $key');
        }
      }
    });

    final streamController = StreamController<RiderData>();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        final double myHR = platform.invokeMethod('getMyHR') as double;
        final double myPower = platform.invokeMethod('getMyPower') as double;

        final RiderData data = RiderData();
        data.heartRate = myHR;
        data.power = myPower;

        streamController.add(data);

      } on PlatformException catch (e) {
        Logger.root.severe('Failed to get partner data from Stream: $e');
      }
    });

    streamController.stream.listen((event) {
        BluetoothManager.instance.broadcastString("heartRate:${event.heartRate}");
        BluetoothManager.instance.broadcastString("power:${event.power}");
        //BluetoothManager.instance.broadcastString("speed:${event.speed}");
    });
  }

  Future<void> _getBatteryLevel() async {
    String batteryLevel;

    int percentageBattery = 0;
    try {
      final int result = await platform.invokeMethod(
          'getBatteryLevel', {"HR": 69});
      print(result);
      batteryLevel = ' $result % ';
      percentageBattery = result;
    } on PlatformException catch (e) {
      batteryLevel = "Failed to get battery level: '${e.message}'.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                        const PairingPage(title: 'Pairing with Partner')),
                  );
                },
                icon: const Icon(
                  Icons.bluetooth,
                ),
                label: const Align(
                    alignment: Alignment.centerLeft,
                    child: ListTile(
                        title: Text("Pair with Partner"),
                        trailing: Icon(Icons.keyboard_arrow_right)))),

            TextButton.icon(
              onPressed: sayHi,
              icon: const Icon(
                Icons.people,
              ),
              label: const Align(
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                      title: Text("Say Hi"),
                      trailing: Icon(Icons.keyboard_arrow_right))),
            ),

          ],
        ),
      ),
      persistentFooterButtons: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.pop(context);
          },
          alignment: Alignment.bottomLeft,
        ),
        SizedBox(width: 100),
        ElevatedButton(
          onPressed: () {
            _getBatteryLevel();
            print("pressed");
          },
          child: Icon(Icons.play_arrow),
          style: ElevatedButton.styleFrom(
            fixedSize: const Size(50, 50),
            shape: const CircleBorder(),
            backgroundColor: Colors.yellow,
          ),
        )
      ],
      persistentFooterAlignment: AlignmentDirectional.bottomStart,
    );
  }
}