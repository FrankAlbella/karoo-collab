import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart' hide Logger;
import 'package:geolocator/geolocator.dart';
import 'package:wakelock/wakelock.dart';
import '../ble_sensor_device.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:logging/logging.dart';
import '../rider_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/exercise_logger.dart';
import '../bluetooth_manager.dart';
import 'package:karoo_collab/pages/paired_workout.dart';
import 'package:fluttertoast/fluttertoast.dart';

class WorkoutPage extends StatefulWidget {
  final FlutterReactiveBle flutterReactiveBle;
  final List<BleSensorDevice>? deviceList;
  final String title;

  const WorkoutPage({
    super.key,
    required this.flutterReactiveBle,
    required this.deviceList,
    required this.title,
  });

  @override
  State<WorkoutPage> createState() => _WorkoutPage();
}

class _WorkoutPage extends State<WorkoutPage> {
  Stream<BluetoothDiscoveryResult>? discoveryStream;
  StreamSubscription<BluetoothDiscoveryResult>? discoveryStreamSubscription;

  static int myHR = 0;
  int myPower = 0;
  int myCadence = 0;
  int mySpeed = 0;

  int partnerHR = 0;
  int partnerPower = 0;
  int partnerCadence = 0;
  int partnerSpeed = 0;
  String _name = "";
  int _maxHR = 120;
  int _FTP = 150;
  final RiderData data = RiderData();
  Duration duration = Duration();
  Timer? timer;
  double speed = 0.0;
  double distance = 0;
  bool pauseWorkout = false;
  bool stopWorkout = false;
  bool distanceSwitch = false;
  bool hrSwitch = false;
  bool powerSwitch = false;
  bool partnerHrSwitch = false;
  bool partnerpowerSwitch = false;
  Position? currentPosition;
  Position? initialPosition;
  late StreamSubscription<Position> positionStreamSubscription;

  late StreamSubscription peerSubscription;
  StreamSubscription<List<int>>? subscribeStreamHR;

  int _readPower(List<int> data) {
    int total = data[3];
    /*
    data = [_, 0x??, 0x??, ...]
    want to read index 2 and 3 as one integer
    shift integer at index 3 left by 8 bits
    and add the 8 bits from index 2
    since the data is being stored in little-endian
    format
     */
    total = total << 8;
    return total + data[2];
  }

  //TODO: need to fix this
  double _readCadence(List<int> data) {
    int time = data[11] << 8;
    time += data[10];
    double timeDouble = time.toDouble();
    timeDouble *= 1 / 2048;
    return (1 / timeDouble) * 60.0;
  }

  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    _loadSettings();
    startTimer();
    getCurrentLocation();

    positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 15))
        .listen(onPositionUpdate);

    startBluetoothListening();
    BluetoothManager.instance.deviceDataStream.listen((dataMap) {
      Logger.root.info('got data from a connection: $dataMap');
    });

    startPartnerListening();

    BluetoothManager.instance.sendPersonalInfo();
  }

  Widget _buildPopupDialog(BuildContext context) {
    return AlertDialog(
      title: Text('Are you sure you want to end the ride?',
          style: TextStyle(fontSize: 14)),
      //contentPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      actions: <Widget>[
        TextButton(
          onPressed: () {
            //back to workout
            Navigator.pop(context);
          },
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () {
            //END WORKOUT!
            stopWorkout = true;
            ExerciseLogger.instance?.endWorkoutAndSaveLog();
            Fluttertoast.showToast(
                msg: "Workout logged and sent!",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.green,
                textColor: Colors.white,
                fontSize: 16.0);
            int count = 0;
            Navigator.of(context).popUntil((_) => count++ >= 2);
          },
          child: const Text('Yes'),
        ),
      ],
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = (prefs.getString('name') ?? "Name");
      print("Is this okay: {$_name}");
    });
    setState(() {
      _maxHR = (prefs.getInt('maxHR') ?? _maxHR);
      print('$_maxHR');
    });
    setState(() {
      _FTP = (prefs.getInt('FTP') ?? _FTP);
      print('$_FTP');
    });
  }

  void startBluetoothListening() {
    if (widget.deviceList != null) {
      debugPrint("MAYBE GOTTEM?");
      for (BleSensorDevice device in widget.deviceList!) {
        debugPrint("we Gottem");
        if (device.type == 'HR') {
          debugPrint("Device sub: ${device.deviceId}");
          subscribeStreamHR = widget.flutterReactiveBle
              .subscribeToCharacteristic(QualifiedCharacteristic(
                  characteristicId: device.characteristicId,
                  serviceId: device.serviceId,
                  deviceId: device.deviceId))
              .listen((event) {
            setState(() {
              // Update UI.
              myHR = event[1];
              // Broadcast heart rate to partner.
              BluetoothManager.instance.broadcastString('heartRate:$myHR');
              debugPrint("Broadcast string: heartRate:$myHR");
              // Log heart rate.
              ExerciseLogger.instance?.logHeartRateData(myHR);
            });
          });
        } else if (device.type == 'POWER') {
          debugPrint("Device sub: ${device.deviceId}");
          subscribeStreamHR = widget.flutterReactiveBle
              .subscribeToCharacteristic(QualifiedCharacteristic(
                  characteristicId: device.characteristicId,
                  serviceId: device.serviceId,
                  deviceId: device.deviceId))
              .listen((event) {
            setState(() {
              // Update UI.
              myPower = _readPower(event);
              //myCadence = _readCadence(event).toInt();
              // Broadcast power and cadence to partner.
              BluetoothManager.instance.broadcastString('power:$myPower');
              debugPrint("Broadcast string: power:$myPower");
              //BluetoothManager.instance.broadcastString('cadence:$myCadence');
              //debugPrint("Broadcast string: cadence:$myCadence");
              // Log heart rate.
              ExerciseLogger.instance?.logPowerData(myPower);
            });
          });
        }
      }
    }
  }

  void startPartnerListening() {
    BluetoothManager.instance.deviceDataStream.listen((event) {
      Logger.root.info('got data from a connection: $event');
      final map = event.values.first;
      setState(() {
        for (final key in map.keys) {
          switch (key) {
            case "heartRate":
              partnerHR = int.parse(map[key] ?? "-1");
              Logger.root.info('Set partner HR: $partnerHR');
              break;
            case "power":
              partnerPower = int.parse(map[key] ?? "-1");
              Logger.root.info('Set partner power: $partnerPower');
              break;
            case "cadence":
              partnerCadence = int.parse(map[key] ?? "-1");
              Logger.root.info('Set partner cadence: $partnerCadence');
              break;
            case "speed":
              partnerSpeed = int.parse(map[key] ?? "-1");
              Logger.root.info('Set partner speed: $partnerSpeed');
              break;
            default:
              Logger.root.warning('Unknown map key received: $key');
          }
        }
      });
    });
  }

  void getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      initialPosition = position;
      currentPosition = position;
    });
  }

  void onPositionUpdate(Position newPosition) {
    setState(() {
      currentPosition = newPosition;
      if (initialPosition != null) {
        final distanceInMeters = Geolocator.distanceBetween(
          initialPosition!.latitude,
          initialPosition!.longitude,
          currentPosition!.latitude,
          currentPosition!.longitude,
        );
        initialPosition = newPosition;

        if (!pauseWorkout) {
          setState(() {
            distance += distanceInMeters;
            debugPrint("CURRENT DISTANCE IS: $distance");
          });
          debugPrint("DISTANCE IS UPDATED!");
          debugPrint("DISTANCE IS INCREASED BY $distanceInMeters");
        }
      }
    });
  }

  void getLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission was denied again, handle the error
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission was permanently denied, take the user to app settings
      return;
    }

    // Permission has been granted, you can now access the device's location
    final position = await Geolocator.getCurrentPosition();
    print(position);
  }

  void addTime() {
    setState(() {
      final seconds = duration.inSeconds + 1;
      duration = Duration(seconds: seconds);
    });
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) => addTime());
  }

  @override
  void dispose() {
    peerSubscription =
        BluetoothManager.instance.deviceDataStream.listen((event) {});
    if (subscribeStreamHR != null) {
      subscribeStreamHR?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String? hours, minutes, seconds;
    hours = twoDigits(duration.inHours.remainder(60));
    minutes = twoDigits(duration.inMinutes.remainder(60));
    seconds = twoDigits(duration.inSeconds.remainder(60));
    return Scaffold(
      backgroundColor: Colors.black26,
      floatingActionButton: Row(children: [
        Container(
          height: 60.0,
          width: 60.0,
          child: Visibility(
            visible: pauseWorkout == true,
            child: FloatingActionButton(
              heroTag: "endride",
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              child: Container(
                  width: 20,
                  height: 20,
                  child: Image(image: AssetImage('images/chequered-flag.png'))),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) => _buildPopupDialog(context),
                );
              },
            ),
            replacement: const SizedBox(width: 60),
          ),
          transform: Matrix4.translationValues(-5, 0.0, 0.0),
        ),
        Container(
          height: 60.0,
          width: 60.0,
          child: FloatingActionButton(
            heroTag: "playpause",
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            onPressed: () {
              setState(() {
                pauseWorkout = !pauseWorkout;
                if (pauseWorkout) //PLAY/PAUSE WORKOUT!
                {
                  timer?.cancel();
                } else {
                  startTimer();
                }
              });
            },
            child: Icon(pauseWorkout ? Icons.play_arrow : Icons.pause),
          ),
          transform: Matrix4.translationValues(165, 0.0, 0.0),
        )
      ]),
      body: SafeArea(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              SizedBox(
                  height: 30,
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    children: [
                      const Text(
                        "Duration:",
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$hours:$minutes:$seconds',
                        style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ))
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              SizedBox(
                height: 30,
                width: MediaQuery.of(context).size.width / 2,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      distanceSwitch = !distanceSwitch;
                      distanceSwitch
                          ? debugPrint("Switching to km")
                          : debugPrint("Switching to mi");
                    });
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: Column(
                    children: distanceSwitch
                        ? [
                            const Text(
                              "Distance:",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "${(distance / 1000).toStringAsFixed(2)}km",
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ]
                        : [
                            const Text(
                              "Distance:",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "${(distance / 1609.34).toStringAsFixed(2)}mi",
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                width: MediaQuery.of(context).size.width / 2,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      distanceSwitch = !distanceSwitch;
                      distanceSwitch
                          ? debugPrint("Switching to km")
                          : debugPrint("Switching to mi");
                    });
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: Column(
                    children: distanceSwitch
                        ? [
                            const Text(
                              "Speed:",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                      Text(
                        "${distance == 0 ? '0' : ((distance / 1000) / (duration.inSeconds / 3600)).toStringAsFixed(2)} km/h",
                        style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                          ]
                        : [
                            const Text(
                              "Speed:",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "${distance == 0 ? '0' : ((distance / 1609.34) / (duration.inSeconds / 3600)).toStringAsFixed(2)} mi/h",
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                  ),
                ),
              ),
            ]),
            Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 20,
                  child: Text(
                    "$_name",
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            ),
            Row(
              children: [
                SizedBox(
                    width: 120,
                    height: 100,
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              hrSwitch = !hrSwitch;
                              hrSwitch
                                  ? debugPrint(
                                      "Switching to heart rate percentage")
                                  : debugPrint("Switching to heart rate");
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black),
                          child: Column(
                            children: hrSwitch
                                ? [
                                    Text(
                                      "${(myHR / _maxHR * 100).round()}%",
                                      style: const TextStyle(
                                          fontSize: 25,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]
                                : [
                                    Text(
                                      "$myHR",
                                      style: const TextStyle(
                                          fontSize: 50,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    )),
                SizedBox(
                    width: 120,
                    height: 100,
                    child: Column(
                      children: [
                        Icon(
                          Icons.flash_on,
                          color: Colors.white,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              powerSwitch = !powerSwitch;
                              powerSwitch
                                  ? debugPrint("Switching to power percentage")
                                  : debugPrint("Switching to power");
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black),
                          child: Column(
                            children: powerSwitch
                                ? [
                                    Text(
                                      "${(myPower / _FTP * 100).round()}%",
                                      style: const TextStyle(
                                          fontSize: 25,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]
                                : [
                                    Text(
                                      "$myPower",
                                      style: const TextStyle(
                                          fontSize: 50,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    )),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 20,
                  child: Text(
                    RiderData.partnerName.replaceAll(RegExp("{|}"), ""),
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                )
              ],
            ),
            Row(
              children: [
                SizedBox(
                    width: 120,
                    height: 100,
                    child: Column(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              partnerHrSwitch = !partnerHrSwitch;
                              partnerHrSwitch
                                  ? debugPrint(
                                      "Switching to heart rate percentage")
                                  : debugPrint("Switching to heart rate");
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black),
                          child: Column(
                            children: partnerHrSwitch
                                ? [
                                    Text(
                                      "${(partnerHR/RiderData.partnerMaxHR * 100).round()}%",
                                      style: const TextStyle(
                                          fontSize: 25,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]
                                : [
                                    Text(
                                      "$partnerHR",
                                      style: const TextStyle(
                                          fontSize: 50,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    )),
                SizedBox(
                    width: 120,
                    height: 100,
                    child: Column(
                      children: [
                        Icon(
                          Icons.flash_on,
                          color: Colors.white,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              partnerpowerSwitch = !partnerpowerSwitch;
                              partnerpowerSwitch
                                  ? debugPrint("Switching to power percentage")
                                  : debugPrint("Switching to power");
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black),
                          child: Column(
                            children: partnerpowerSwitch
                                ? [
                                    Text(
                                      "${(partnerPower/RiderData.partnerFtp * 100).round()}%",
                                      style: const TextStyle(
                                          fontSize: 25,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ]
                                : [
                                    Text(
                                      "$partnerPower",
                                      style: const TextStyle(
                                          fontSize: 50,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          ])),
    );
  }
}
