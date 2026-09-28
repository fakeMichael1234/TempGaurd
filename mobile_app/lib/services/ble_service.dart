import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../models/alert_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class BleService extends ChangeNotifier {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? _tempCharacteristic;
  BluetoothCharacteristic? _minTempCharacteristic;
  BluetoothCharacteristic? _maxTempCharacteristic;
  BluetoothCharacteristic? _alertCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _tempSubscription;
  StreamSubscription<List<int>>? _alertSubscription;

  List<ScanResult> scanResults = [];
  bool isScanning = false;
  bool isConnecting = false;
  bool isConnected = false;

  double currentTemperature = 0.0;
  DateTime? lastUpdated;
  TempStatus currentStatus = TempStatus.disconnected;
  TempStatus _lastNotificationStatus = TempStatus.disconnected;

  double minTempLimit = 2.0;
  double maxTempLimit = 8.0;

  void initService() async {
    minTempLimit = await StorageService.getMinTemp();
    maxTempLimit = await StorageService.getMaxTemp();
    notifyListeners();
  }

  // 1. Scan for BLE Devices
  void startScan() async {
    if (isScanning) return;
    scanResults.clear();
    isScanning = true;
    notifyListeners();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withNames: [BleConstants.targetDeviceName],
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        scanResults = results;
        notifyListeners();
      });

      FlutterBluePlus.isScanning.listen((scanning) {
        isScanning = scanning;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("BLE Scan Error: $e");
      isScanning = false;
      notifyListeners();
    }
  }

  void stopScan() async {
    await FlutterBluePlus.stopScan();
    isScanning = false;
    notifyListeners();
  }

  // 2. Connect to ESP32 Device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    isConnecting = true;
    notifyListeners();
    stopScan();

    try {
      await device.connect(autoConnect: true);
      connectedDevice = device;

      // Listen to connection state
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          isConnected = true;
          isConnecting = false;
          notifyListeners();
        } else if (state == BluetoothConnectionState.disconnected) {
          isConnected = false;
          isConnecting = false;
          currentStatus = TempStatus.disconnected;
          notifyListeners();
        }
      });

      // Discover Services & Characteristics
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == BleConstants.serviceUuid.toLowerCase()) {
          for (var char in service.characteristics) {
            final uuid = char.uuid.toString().toLowerCase();
            if (uuid == BleConstants.tempCharacteristicUuid.toLowerCase()) {
              _tempCharacteristic = char;
            } else if (uuid == BleConstants.minTempCharacteristicUuid.toLowerCase()) {
              _minTempCharacteristic = char;
            } else if (uuid == BleConstants.maxTempCharacteristicUuid.toLowerCase()) {
              _maxTempCharacteristic = char;
            } else if (uuid == BleConstants.alertCharacteristicUuid.toLowerCase()) {
              _alertCharacteristic = char;
            }
          }
        }
      }

      // Subscribe to Notifications
      await _subscribeToCharacteristics();

      // Write cached local min/max limits to ESP32
      await sendLimitsToEsp32(minTempLimit, maxTempLimit);

      return true;
    } catch (e) {
      debugPrint("BLE Connection Error: $e");
      isConnecting = false;
      isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Subscribe to live temperature and alert characteristics
  Future<void> _subscribeToCharacteristics() async {
    if (_tempCharacteristic != null) {
      await _tempCharacteristic!.setNotifyValue(true);
      _tempSubscription = _tempCharacteristic!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          String tempStr = utf8.decode(value);
          double? parsed = double.tryParse(tempStr);
          if (parsed != null) {
            currentTemperature = parsed;
            lastUpdated = DateTime.now();
            notifyListeners();
          }
        }
      });
    }

    if (_alertCharacteristic != null) {
      await _alertCharacteristic!.setNotifyValue(true);
      _alertSubscription = _alertCharacteristic!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          String alertStr = utf8.decode(value);
          int code = int.tryParse(alertStr) ?? 0;
          TempStatus newStatus;
          if (code == 1) {
            newStatus = TempStatus.low;
          } else if (code == 2) {
            newStatus = TempStatus.high;
          } else {
            newStatus = TempStatus.normal;
          }

          if (currentStatus != newStatus) {
            _handleStatusChange(newStatus);
          }
        }
      });
    }
  }

  // Handle status transitions & state-change notifications
  void _handleStatusChange(TempStatus newStatus) async {
    currentStatus = newStatus;
    notifyListeners();

    // Trigger local notification only when status changes
    if (_lastNotificationStatus != newStatus && newStatus != TempStatus.disconnected) {
      _lastNotificationStatus = newStatus;
      
      // Save to local alert history
      final record = AlertRecord(
        timestamp: DateTime.now(),
        temperature: currentTemperature,
        status: newStatus,
      );
      await StorageService.addAlertRecord(record);

      // Trigger phone notification
      await NotificationService.showAlertNotification(
        status: newStatus,
        temperature: currentTemperature,
      );
    }
  }

  // Write Limits to ESP32 Characteristic & save locally
  Future<void> sendLimitsToEsp32(double minTemp, double maxTemp) async {
    minTempLimit = minTemp;
    maxTempLimit = maxTemp;
    await StorageService.saveLimits(minTemp, maxTemp);
    notifyListeners();

    if (isConnected) {
      if (_minTempCharacteristic != null) {
        await _minTempCharacteristic!.write(utf8.encode(minTemp.toStringAsFixed(2)));
      }
      if (_maxTempCharacteristic != null) {
        await _maxTempCharacteristic!.write(utf8.encode(maxTemp.toStringAsFixed(2)));
      }
    }
  }

  // Disconnect from BLE Device
  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      await _tempSubscription?.cancel();
      await _alertSubscription?.cancel();
      await _connectionStateSubscription?.cancel();
      await connectedDevice!.disconnect();
      connectedDevice = null;
      isConnected = false;
      currentStatus = TempStatus.disconnected;
      notifyListeners();
    }
  }
}
