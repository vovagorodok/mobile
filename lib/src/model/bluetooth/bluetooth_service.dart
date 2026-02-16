import 'dart:async';

import 'package:ble_backend/ble_connector.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lichess_mobile/src/model/bluetooth/cpp_peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/dummy_peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/time.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';

/// A provider instance of the [BluetoothService].
final bluetoothServiceProvider = Provider<BluetoothService>((Ref ref) {
  final service = BluetoothService();
  ref.onDispose(() => service._dispose());
  return service;
});

class BluetoothService {
  // TODO: As state will be peripheral and connector
  // TODO: Use storege like final Ref _ref.read(OverTheBoardGameStorage) check notificationServiceProvider
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

  Future<void> connect(BleConnector bleConnector) async {
    _bleConnector = bleConnector;
    _subscription = bleConnector.stateStream.listen(_onConnectionStateChanged);
    await bleConnector.connect();
  }

  Future<void> disconnect() async {
    await _bleConnector?.disconnect();
  }

  Future<void> handleBegin({
    required Position position,
    required Variant variant,
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

  Future<void> handleEnd({GameStatus? status, Variant? variant, String? score}) async {
    await _peripheral.handleEnd(status: status, variant: variant, score: score);
  }

  Future<void> handleReject() async {
    await _peripheral.handleReject();
    _showMessage('Rejected');
  }

  void _onConnectionStateChanged(BleConnectorStatus status) {
    if (status == BleConnectorStatus.disconnected) {
      _peripheral = DummyPeripheral();
      _showMessage('Disconnected');
    } else if (status == BleConnectorStatus.connected) {
      _initPeripheral();
      _showMessage('Connected');
    }
    _connectedController.add(null);
  }

  Future<void> _initPeripheral() async {
    final bleConnector = _bleConnector!;
    final mtu = bleConnector.createMtu();
    final requestedMtu = await mtu.request(mtu: maxStringSize);
    if (requestedMtu < maxStringSize) {
      await bleConnector.disconnect();
      _showError('Mtu: $requestedMtu, is less than the required: $maxStringSize');
      return;
    }

    final serial = BleStringSerial(
      bleSerial: bleConnector.createSerial(
        serviceId: serviceUuid,
        rxCharacteristicId: characteristicUuidRx,
        txCharacteristicId: characteristicUuidTx,
      ),
    );
    _peripheral = CppPeripheral(stringSerial: serial);
    _peripheral.initializedStream.listen(_handlePeripheralInitialized);
    _peripheral.roundInitializedStream.listen(_handlePeripheralRoundInitialized);
    _peripheral.roundUpdateStream.listen(_handlePeripheralRoundUpdate);
    _peripheral.stateSynchronizeStream.listen(_handlePeripheralStateSynchronize);
    _peripheral.moveStream.listen(_handlePeripheralMove);
    _peripheral.errStream.listen(_showError);
    _peripheral.msgStream.listen(_showMessage);
    // _peripheral.resignStream.listen(_handlePeripheralResign);
    // _peripheral.undoOfferStream.listen(_handlePeripheralUndoOffer);
    // _peripheral.undoOfferAckStream.listen(_handleCentralUndoOfferAck);
    // _peripheral.drawOfferStream.listen(_handlePeripheralDrawOffer);
    // _peripheral.drawOfferAckStream.listen(_handleCentralDrawOfferAck);
  }

  Future<void> _dispose() async {
    await _subscription?.cancel();
    await _bleConnector?.disconnect();

    await _connectedController.close();
    await _initializedController.close();
    await _roundUpdateController.close();
    await _moveController.close();
  }

  void _handlePeripheralInitialized(_) {
    _initializedController.add(null);
  }

  void _handlePeripheralRoundInitialized(_) {
    _handlePeripheralRoundUpdate(null);
    if (!_peripheral.round.isVariantSupported) {
      _showMessage('Unsupported variant');
    }
  }

  void _handlePeripheralRoundUpdate(_) {
    // isAutocompleteOngoing = false;
    // isOfferOngoing = false;
    _roundUpdateController.add(null);
  }

  void _handlePeripheralStateSynchronize(bool isSynchronized) {
    _showMessage(isSynchronized ? 'Synchronized' : 'Unsynchronized');
  }

  void _handlePeripheralMove(NormalMove move) {
    _moveController.add(move);
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
