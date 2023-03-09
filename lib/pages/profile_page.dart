import 'dart:math';
import 'package:flutter/material.dart';
import 'package:karoo_collab/pages/workout_page.dart';
import '../bluetooth_manager.dart';
import 'pairing_page.dart';
import '../monitor_sensor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble_sensor_device.dart';
import 'dart:async';
import 'package:flutter/services.dart';

Random random = Random();

void sayHi() async {
  final int randomNum = random.nextInt(100);
  String dataStr = "randomNum:$randomNum";
  print("Broadcasting data: $dataStr");
  BluetoothManager.instance.broadcastString(dataStr);
}

Widget _buildPopupDialog(BuildContext context) {
  return AlertDialog(
    title: const Text('Popup example'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const <Widget>[
        Text("Hello"),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<ProfilePage> createState() => _ProfilePage();
}

class _ProfilePage extends State<ProfilePage> {
  // final flutterReactiveBle = FlutterReactiveBle();
  // List<BleSensorDevice> connectedDevices = <BleSensorDevice>[];
  late double dialogWidth = MediaQuery.of(context).size.width * 1;
  late double dialogHeight = MediaQuery.of(context).size.height * 1;
  final LayerLink layerLink = LayerLink();
  late OverlayEntry overlayEntry;
  late Offset dialogOffset;

  int _counter = 0;
  static const platform = const MethodChannel('edu.uf.karoo_collab');

  String _batteryLevel = 'Unknown battery level';
  double _indicatorWidth = 0;

  Future<void> _getBatteryLevel() async {
    print("got in");
    String batteryLevel;

    int percentageBattery=0;
    try {
      final int result = await platform.invokeMethod('getBatteryLevel', {"HR": 69});
      print(result);
      batteryLevel = ' $result % ';
      percentageBattery=result;

    } on PlatformException catch (e) {
      batteryLevel = "Failed to get battery level: '${e.message}'.";
    }

    setState(() {
      _batteryLevel = batteryLevel;
      _indicatorWidth=(percentageBattery)*1.9;
    });
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
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
                icon: Icon(
                  Icons.bluetooth,
                ),
                label: const Align(
                    alignment: Alignment.centerLeft,
                    child: ListTile(
                        title: Text("Pair with Partner"),
                        trailing: Icon(Icons.keyboard_arrow_right)))),

            TextButton.icon(
              onPressed: sayHi,
              icon: Icon(
                Icons.people,
              ),
              label: const Align(
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                      title: Text("Say Hi"),
                      trailing: Icon(Icons.keyboard_arrow_right))),
            ),
            TextButton.icon(
              onPressed: () {
                showConnectMonitorsDialog();
              },
              icon: Icon(
                Icons.people,
              ),
              label: const Align(
                  alignment: Alignment.centerLeft,
                  child: ListTile(
                      title: Text("Sensors"),
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
        const SizedBox(width: 100),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(_createRoute(
                          flutterReactiveBle, connectedDevices, ""));
          },
          style: ElevatedButton.styleFrom(
            fixedSize: const Size(50, 50),
            shape: const CircleBorder(),
            backgroundColor: Colors.yellow,
          ),
          child: const Icon(Icons.play_arrow),
        )
      ],
      persistentFooterAlignment: AlignmentDirectional.bottomStart,
    );
  }

  void showConnectMonitorsDialog() {
    dialogOffset = Offset(dialogWidth * 0, dialogHeight * 0);
    overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Stack(
            children: <Widget>[
              Positioned.fill(
                  child: GestureDetector(
                    onTap: dismissMenu,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  )
              ),
              Positioned(
                width: dialogWidth,
                height: dialogHeight,
                top: 0.0,
                left: 0.0,
                child: MonitorConnect(
                    flutterReactiveBle: flutterReactiveBle,
                    callback: (deviceList)=> setState(() {
                      connectedDevices = deviceList;
                    }),
                    connectedDevices: connectedDevices,
                    offset: dialogOffset,
                    link: layerLink,
                    dialogWidth: dialogWidth,
                    dialogHeight: dialogHeight
                ),
              )
            ]
        );
      },
    );
    Overlay.of(context)?.insert(overlayEntry);
  }
  Route _createRoute(FlutterReactiveBle ble,
    List<BleSensorDevice>? connectedDevices, String type) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => WorkoutPage(
        flutterReactiveBle: ble,
        deviceList: connectedDevices,
        title: "Active Run"),
  );
}
  void dismissMenu() {
    overlayEntry.remove();
  }
  List<BleSensorDevice> connectedDevices = <BleSensorDevice>[];
  // Obtain FlutterReactiveBle instance for entire app.
  final flutterReactiveBle = FlutterReactiveBle();


}