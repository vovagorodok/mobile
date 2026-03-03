import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_backend_factory/ble_central.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lichess_mobile/src/model/bluetooth/bluetooth_preferences.dart';
import 'package:lichess_mobile/src/model/bluetooth/cpp_peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/dummy_peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/score.dart';
import 'package:lichess_mobile/src/model/bluetooth/time.dart';
import 'package:lichess_mobile/src/model/bluetooth/uuids.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';
import 'package:logging/logging.dart';

final _logger = Logger('BluetoothService');

/// A provider instance of the [BluetoothService].
final bluetoothServiceProvider = Provider<BluetoothService>((Ref ref) {
  final service = BluetoothService(ref);
  ref.onDispose(() => service._dispose());
  return service;
});

class BluetoothService {
  BluetoothService(this._ref);

  final Ref _ref;
  Peripheral _peripheral = DummyPeripheral();
  BleConnector? _bleConnector;
  StreamSubscription<BleConnectorStatus>? _subscription;

  Peripheral get peripheral => _peripheral;

  final _connectedController = StreamController<void>.broadcast();
  Stream<void> get connectedStream => _connectedController.stream;
  bool get isConnected => _bleConnector?.state == BleConnectorStatus.connected;

  final _initializedController = StreamController<void>.broadcast();
  Stream<void> get initializedStream => _initializedController.stream;
  bool get isInitialized => _peripheral.isInitialized;

  final _roundUpdateController = StreamController<void>.broadcast();
  Stream<void> get roundUpdateStream => _roundUpdateController.stream;

  final _moveController = StreamController<NormalMove>.broadcast();
  Stream<NormalMove> get moveStream => _moveController.stream;

  final _resignController = StreamController<void>.broadcast();
  Stream<void> get resignStream => _resignController.stream;

  final _undoOfferController = StreamController<void>.broadcast();
  Stream<void> get undoOfferStream => _undoOfferController.stream;

  final _undoOfferAckController = StreamController<bool>.broadcast();
  Stream<bool> get undoOfferAckStream => _undoOfferAckController.stream;

  final _drawOfferController = StreamController<void>.broadcast();
  Stream<void> get drawOfferStream => _drawOfferController.stream;

  final _drawOfferAckController = StreamController<bool>.broadcast();
  Stream<bool> get drawOfferAckStream => _drawOfferAckController.stream;

  void start() {
    final prefs = _ref.read(bluetoothPreferencesProvider);
    if (bleCentral.isCreateConnectorToKnownDeviceSupported &&
        prefs.autoconnect &&
        prefs.isDeviceSaved) {
      final bleConnector = bleCentral.createConnectorToKnownDevice(
        deviceId: prefs.deviceId,
        serviceIds: [],
      );
      connect(bleConnector);
    }
  }

  Future<void> connect(BleConnector bleConnector) async {
    _logger.info('Connect');
    _bleConnector = bleConnector;
    _subscription = bleConnector.stateStream.listen(_onConnectionStateChanged);
    await bleConnector.connect();
    await _ref.read(bluetoothPreferencesProvider.notifier).setDevice(bleConnector.deviceId);
  }

  Future<void> disconnect() async {
    _logger.info('Disconnect');
    await _bleConnector?.disconnect();
    await _ref.read(bluetoothPreferencesProvider.notifier).clearDevice();
  }

  Future<void> handleBegin({
    required Position position,
    Variant? variant,
    NormalMove? lastMove,
    Side? side,
    Time? time,
  }) async {
    await _peripheral.handleBegin(
      position: position,
      variant: variant,
      lastMove: lastMove,
      side: side,
      time: time,
    );
  }

  Future<void> handleMove({
    required Position position,
    required NormalMove move,
    Time? time,
  }) async {
    await _peripheral.handleMove(position: position, move: move, time: time);
  }

  Future<void> handleEnd({GameStatus? status, Variant? variant, Score? score}) async {
    await _peripheral.handleEnd(status: status, variant: variant, score: score);
  }

  Future<void> handleReject() async {
    await _peripheral.handleReject();
    _showMessage('Rejected');
  }

  Future<void> handleUndo({required Position position, NormalMove? lastMove, Time? time}) async {
    if (!_peripheral.isFeatureSupported.undoRedo) {
      await _peripheral.handleBegin(position: position, lastMove: lastMove, time: time);
      return;
    }
    await _peripheral.handleUndo(position: position, lastMove: lastMove, time: time);
  }

  Future<void> handleRedo({required Position position, NormalMove? lastMove, Time? time}) async {
    if (!_peripheral.isFeatureSupported.undoRedo) {
      await _peripheral.handleBegin(position: position, lastMove: lastMove, time: time);
      return;
    }
    await _peripheral.handleRedo(position: position, lastMove: lastMove, time: time);
  }

  Future<void> handleGetState() async {
    await _peripheral.handleGetState();
  }

  Future<void> handleSetState() async {
    await _peripheral.handleSetState();
  }

  Future<void> handleDrawOffer() async {
    await _peripheral.handleDrawOffer();
  }

  void _onConnectionStateChanged(BleConnectorStatus status) {
    if (status == BleConnectorStatus.disconnected) {
      _peripheral = DummyPeripheral();
      _logger.info('Disconnected');
      _showMessage('Disconnected');
    } else if (status == BleConnectorStatus.connected) {
      _initPeripheral(_bleConnector!);
      _logger.info('Connected');
      _showMessage('Connected');
    }
    _connectedController.add(null);
  }

  Future<void> _initPeripheral(BleConnector bleConnector) async {
    final mtu = bleConnector.createMtu();
    final requestedMtu = await mtu.request(mtu: maxStringSize);
    if (requestedMtu < maxStringSize) {
      await bleConnector.disconnect();
      _showError('Mtu: $requestedMtu, is less than the required: $maxStringSize');
      return;
    }

    _peripheral = await _createPeripheral(bleConnector);
    _peripheral.initializedStream.listen(_handlePeripheralInitialized);
    _peripheral.roundInitializedStream.listen(_handlePeripheralRoundInitialized);
    _peripheral.roundUpdateStream.listen(_handlePeripheralRoundUpdate);
    _peripheral.stateSynchronizeStream.listen(_handlePeripheralStateSynchronize);
    _peripheral.moveStream.listen(_handlePeripheralMove);
    _peripheral.errStream.listen(_showError);
    _peripheral.msgStream.listen(_showMessage);
    _peripheral.resignStream.listen(_handlePeripheralResign);
    _peripheral.undoOfferStream.listen(_handlePeripheralUndoOffer);
    _peripheral.undoOfferAckStream.listen(_handleCentralUndoOfferAck);
    _peripheral.drawOfferStream.listen(_handlePeripheralDrawOffer);
    _peripheral.drawOfferAckStream.listen(_handleCentralDrawOfferAck);
  }

  Future<Peripheral> _createPeripheral(BleConnector bleConnector) async {
    final serviceIds = await bleConnector.discoverServices();

    if (serviceIds.contains(CppUuids.service)) {
      final serial = BleStringSerial(
        bleSerial: bleConnector.createSerial(
          serviceId: CppUuids.service,
          rxCharacteristicId: CppUuids.characteristicRx,
          txCharacteristicId: CppUuids.characteristicTx,
        ),
      );
      return CppPeripheral(stringSerial: serial);
    }

    _logger.warning('No peripheral found for: $serviceIds');
    await disconnect();
    return DummyPeripheral();
  }

  Future<void> _dispose() async {
    await _subscription?.cancel();
    await _bleConnector?.disconnect();

    await _connectedController.close();
    await _initializedController.close();
    await _roundUpdateController.close();
    await _moveController.close();
    await _resignController.close();
    await _undoOfferController.close();
    await _undoOfferAckController.close();
    await _drawOfferController.close();
    await _drawOfferAckController.close();
  }

  void _handlePeripheralInitialized(_) {
    _showMessage('Ready');
    _initializedController.add(null);
  }

  void _handlePeripheralRoundInitialized(_) {
    _handlePeripheralRoundUpdate(null);
    if (!_peripheral.round.isVariantSupported) {
      _showMessage('Unsupported variant');
    }
  }

  void _handlePeripheralRoundUpdate(_) {
    _roundUpdateController.add(null);
  }

  void _handlePeripheralStateSynchronize(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  void _handlePeripheralMove(NormalMove move) {
    _moveController.add(move);
  }

  void _handlePeripheralResign(_) {
    _resignController.add(null);
  }

  void _handlePeripheralUndoOffer(_) {
    _undoOfferController.add(null);
  }

  void _handleCentralUndoOfferAck(bool ack) {
    _undoOfferAckController.add(ack);
  }

  void _handlePeripheralDrawOffer(_) {
    _drawOfferController.add(null);
  }

  void _handleCentralDrawOfferAck(bool ack) {
    _drawOfferAckController.add(ack);
  }

  void _showMessage(String msg) {
    Fluttertoast.showToast(msg: msg, fontSize: 18.0);
  }

  void _showError(String err) {
    Fluttertoast.showToast(
      msg: err,
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 18.0,
    );
  }
}
