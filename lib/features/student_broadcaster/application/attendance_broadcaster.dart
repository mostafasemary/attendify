import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/id_extractor.dart';

class AttendanceBroadcaster {
  AttendanceBroadcaster(this._blePeripheral);

  final FlutterBlePeripheral _blePeripheral;

  Future<void> start() async {
    final storage = serviceLocator<StorageService>();
    final profileLink = await storage.readStudentProfileLink() ?? '';
    
    // Extract ID to use as a fallback name if the full URL is too long
    // However, the scanner looks for a URL or a numeric name.
    final studentId = IdExtractor.extractId(profileLink) ?? 'Unknown';

    await _blePeripheral.start(
      advertiseData: AdvertiseData(
        includeDeviceName: true,
        // We broadcast the ID as the local name so the teacher can discover it.
        // Standard BLE names are limited, but IDs are short.
        localName: studentId, 
        serviceUuids: const ['0000180D-0000-1000-8000-00805F9B34FB'],
      ),
    );
  }

  Future<bool> isReady() async {
    final supported = await _blePeripheral.isSupported;
    if (!supported) {
      return false;
    }

    final isBluetoothOn = await _blePeripheral.isBluetoothOn;
    if (!isBluetoothOn) {
      return false;
    }

    final permission = await _blePeripheral.hasPermission();
    return permission == BluetoothPeripheralState.granted ||
        permission == BluetoothPeripheralState.ready ||
        permission == BluetoothPeripheralState.limited;
  }

  Future<void> stop() async {
    await _blePeripheral.stop();
  }
}
