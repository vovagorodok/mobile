import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';

class CppUuids {
  static const String service = serviceUuid;
  static const String characteristicTx = characteristicUuidTx;
  static const String characteristicRx = characteristicUuidRx;
}

const List<String> serviceUuids = [CppUuids.service];
