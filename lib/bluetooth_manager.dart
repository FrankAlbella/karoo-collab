/*
For apps targeting Build.VERSION_CODES#R or lower, this requires the Manifest.permission#BLUETOOTH permission which can be gained with a simple <uses-permission> manifest tag.
For apps targeting Build.VERSION_CODES#S or or higher, this requires the Manifest.permission#BLUETOOTH_CONNECT permission which can be gained with Activity.requestPermissions(String[], int).
*/

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:karoo_collab/rider_data.dart';
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logging/exercise_logger.dart';

class BluetoothManager {
  static final BluetoothManager _instance = BluetoothManager._();
  static BluetoothManager get instance => _instance;

  int lastConnectionId = 0;

  /// Maps bluetooth connection id to its connection
  final Map<int, BluetoothConnection> _connections = {};

  /// Maps bluetooth connection id to stream subscription
  final Map<int, StreamSubscription> _subscriptions = {};

  /// Device data that will be broadcasted
  final Map<int, Map<String, String>> _deviceData = {};

  /// StreamController for the device data
  final StreamController<Map<int, Map<String, String>>>
  _deviceDataStreamController = StreamController.broadcast();

  /// Private constructor
  BluetoothManager._() {
    Logger.root.level = Level.ALL; // defaults to Level.INFO
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  /// Stream for the device data
  Stream<Map<int, Map<String, String>>> get deviceDataStream =>
      _deviceDataStreamController.stream;

  /// This can be cancelled by cancelling subscription to this stream
  Future<Stream<BluetoothDiscoveryResult>> startDeviceDiscovery() async {
    try {
      return FlutterBluetoothSerial.instance.startDiscovery();
    } catch (e) {
      Logger.root.severe("Error starting device discovery: $e");
      throw ('Error starting device discovery: $e');
    }
  }

  /// According to FlutterBluetoothSerial, calling this isn't necessary as long as the event sink is closed
  Future<void> stopDeviceDiscovery() async {
    await FlutterBluetoothSerial.instance.cancelDiscovery();
  }

  /// Requests bluetooth discoverable status for a certain time.
  ///
  /// Duration can be capped. Try to stay below 120.
  Future<int?> requestDiscoverable(int seconds) async {
    return FlutterBluetoothSerial.instance.requestDiscoverable(seconds);
  }

  /// Attempts to connect to bluetooth server as a client
  /// Returns boolean on whether or not a connection was established
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Check if device is already connected
      if(device.isConnected) {

        Fluttertoast.showToast(
            msg: "Device is already connected!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0
        );

        throw Exception("Device already connected!");
      }

      // Connect the device
      BluetoothConnection connection =
      await BluetoothConnection.toAddress(device.address)
          .onError((error, stackTrace) => throw Exception(stackTrace));

      _connections[lastConnectionId] = connection;

      // Subscribe to data updates
      StreamSubscription? subscription = connection.input?.listen((data) {
        updateDeviceData(lastConnectionId, data);
      }, onDone: () {
        // Checking for when connection is closed
        disconnectFromDevice(lastConnectionId);
      });

      if (subscription != null) {
        _subscriptions[lastConnectionId] = subscription;
      }
      lastConnectionId++;
      ExerciseLogger.instance?.logBluetoothConnect("$device.name");
      Fluttertoast.showToast(
          msg: "Connected to device",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
      return true;
    } catch (e) {
      Logger.root.severe('Unable to connect to device: $e');

      Fluttertoast.showToast(
          msg: "Unable to connect to device",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );

      return false;
    }
  }

  /// Opens a bluetooth server socket and waits for client to connect
  /// Returns boolean on whether or not a connection was established
  Future<bool> listenForConnections(String sdpName, int timeout) async {
    try {
      // Connect the device
      
      BluetoothConnection connection =
      await BluetoothConnection.listenForConnections(sdpName, timeout);
      _connections[lastConnectionId] = connection;

      // Subscribe to data updates
      StreamSubscription? subscription = connection.input?.listen((data) {
        updateDeviceData(lastConnectionId, data);
      }, onDone: () {
        // Checking for when connection is closed
        disconnectFromDevice(lastConnectionId);
      });

      if (subscription != null) {
        _subscriptions[lastConnectionId] = subscription;
      }
      lastConnectionId++;

      Fluttertoast.showToast(
          msg: "Connected to device",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );

      return true;

    } catch (e) {
      Logger.root.severe('Error connecting to device: $e');

      Fluttertoast.showToast(
          msg: "Error connecting to device",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0
      );
      return false;
    }
  }

  /// Method to disconnect from a device
  Future<void> disconnectFromDevice(int id) async {
    try {
      await _connections[id]?.close();
      _connections.remove(id);
      _deviceData.remove(id);
      _subscriptions[id]?.cancel();
    } catch (e) {
      Logger.root.severe('Error disconnecting from device: $e');
    }
  }

  /// Sends device data to connected devices
  Future<void> broadcastDeviceDataFromMap(Map<String, double> data) async {
    // Create encoded string
    String? mac = await FlutterBluetoothSerial.instance.address;
    if (mac == null) {
      Logger.root.severe("Device MAC address is null!");
      return;
    }
    String dataString = mac;
    for (String key in data.keys) {
      dataString += ":$key:${data[key]}";
    }

    broadcastString(dataString);
  }

  /// Sends string to connected devices
  Future<void> broadcastString(String str) async {
    for (int id in _connections.keys) {
      BluetoothConnection connection = _connections[id]!;
      try {
        if (!connection.isConnected) {
          disconnectFromDevice(id);
        }
        Logger.root.info("Sending string via bluetooth: $str");
        connection.output.add(ascii.encode(str));
      } catch (e) {
        Logger.root.severe(e);
      }
    }
  }

  /// Update device data from connected devices
  /// Format for device data
  ///  - Data should be a string encoded as Uint8List
  ///  - All values should be separated by ":" (this will be the delimeter)
  ///  - All other values will be pairs of keys and values
  Future<void> updateDeviceData(int id, Uint8List data) async {
    List<String> list = ascii.decode(data).split(':');
    if (list.isEmpty) {
      Logger.root
          .severe("Received device data that was empty or not decodeable");
    }
    if (list.length % 2 != 0) {
      Logger.root.severe("Received device data was of odd length");
    }

    for (int i = 0; i < list.length; i += 2) {
      String key = list[i];
      String value = list[i + 1];
      if (_deviceData[id] == null) {
        _deviceData[id] = {};
      }
      _deviceData[id]![key] = value;
    }
    _deviceDataStreamController.sink.add(_deviceData);
  }

  Future<void> requestBluetoothPermissions() async {
    // Implement error/denied permission handling
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan
    ].request();
  }

  /// Sends personal info to connected devices needed for identification
  Future<void> sendPersonalInfo() async {
    // Get Name
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String name = prefs.getString('name') ?? "Unknown";
    int maxHr = prefs.getInt("maxHR") ?? 120;
    int ftp = prefs.getInt('FTP') ?? 250;

    // Get device info
    var deviceInfo = (await DeviceInfoPlugin().androidInfo);
    String? deviceId = deviceInfo.id;
    String? serialNum = deviceInfo.serialNumber;

    // Send to devices
    String str = "name:{$name}:device_id:$deviceId:serial_number:$serialNum:max_hr:$maxHr:ftp:$ftp";
    broadcastString(str);
  }

  // Listens for partner info to arrive, then closes the stream
  void startPartnerInfoListening() {
    late StreamSubscription<Map<int, Map<String, String>>> subscription;
    subscription = BluetoothManager.instance.deviceDataStream.listen((event) {
      Logger.root.info('got data from a connection: $event');
      final map = event.values.first;

      if(map['name'] != null) {
        Logger.root.info('Got partner data: $event');
        ExerciseLogger.instance?.logPartnerConnected(map['name'] ?? "Unknown",
            map['device_id'] ?? "Unknown",
            map['serial_number'] ?? "Unknown");

        RiderData.partnerName = map['name'] ?? "Partner";
        RiderData.partnerMaxHR = int.parse(map['max_hr'] ?? "120");
        RiderData.partnerFtp = int.parse(map['ftp'] ?? "250");

        Logger.root.info('Closing partner data stream...');
        subscription.cancel();
      }
    });
  }
}
