import 'dart:async';

import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart'
    show Features, Sides, StringSerial, Variants;
import 'package:ble_chess_peripheral_driver/chess_peripheral_driver.dart' as driver;
import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/bluetooth/cpp_peripheral_fen.dart';
import 'package:lichess_mobile/src/model/bluetooth/option.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral_piece.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';

class CppFeatureSupport implements FeatureSupport {
  CppFeatureSupport(this._peripheral);
  final driver.Peripheral _peripheral;

  @override
  bool get getState => _peripheral.isFeatureSupported(Features.getState);
  @override
  bool get setState => _peripheral.isFeatureSupported(Features.setState);
  @override
  bool get submoveState => _peripheral.isFeatureSupported(Features.submoveState);
  @override
  bool get lastMove => _peripheral.isFeatureSupported(Features.lastMove);
  @override
  bool get check => _peripheral.isFeatureSupported(Features.check);
  @override
  bool get moved => _peripheral.isFeatureSupported(Features.moved);
  @override
  bool get msg => _peripheral.isFeatureSupported(Features.msg);
  @override
  bool get resign => _peripheral.isFeatureSupported(Features.resign);
  @override
  bool get undoRedo => _peripheral.isFeatureSupported(Features.undoRedo);
  @override
  bool get undoOffer => _peripheral.isFeatureSupported(Features.undoOffer);
  @override
  bool get drawOffer => _peripheral.isFeatureSupported(Features.drawOffer);
  @override
  bool get side => _peripheral.isFeatureSupported(Features.side);
  @override
  bool get time => _peripheral.isFeatureSupported(Features.time);
  @override
  bool get score => _peripheral.isFeatureSupported(Features.score);
  @override
  bool get option => _peripheral.isFeatureSupported(Features.option);
  @override
  bool get drawReason => _peripheral.isFeatureSupported(Features.drawReason);
  @override
  bool get variantReason => _peripheral.isFeatureSupported(Features.variantReason);
}

class CppVariantSupport implements VariantSupport {
  CppVariantSupport(this._peripheral);
  final driver.Peripheral _peripheral;

  @override
  bool get standard => _peripheral.isVariantSupported(Variants.standard);
  @override
  bool get chess960 => _peripheral.isVariantSupported(Variants.chess960);
  @override
  bool get threeCheck => _peripheral.isVariantSupported(Variants.threeCheck);
  @override
  bool get atomic => _peripheral.isVariantSupported(Variants.atomic);
  @override
  bool get kingOfTheHill => _peripheral.isVariantSupported(Variants.kingOfTheHill);
  @override
  bool get antiChess => _peripheral.isVariantSupported(Variants.antiChess);
  @override
  bool get horde => _peripheral.isVariantSupported(Variants.horde);
  @override
  bool get racingKings => _peripheral.isVariantSupported(Variants.racingKings);
  @override
  bool get crazyHouse => _peripheral.isVariantSupported(Variants.crazyHouse);
}

class CppRound implements Round {
  CppRound(this._round);
  final driver.Round _round;

  @override
  bool get isVariantSupported => _round.isVariantSupported;
  @override
  bool get isStateSynchronized => _round.isStateSynchronized;
  @override
  bool get isStateGettable => isPeripheralFenGettable(_round.fen);
  @override
  bool get isStateSettable => _round.isStateSettable;
  @override
  PeripheralPieces? get pieces => _round.fen != null ? readPeripheralFen(_round.fen!) : null;
  @override
  NormalMove? get rejectedMove =>
      _round.rejectedMove != null ? NormalMove.fromUci(_round.rejectedMove!) : null;
}

class CppPeripheral implements Peripheral {
  CppPeripheral({required StringSerial stringSerial})
    : _peripheral = driver.CppPeripheral(
        stringSerial: stringSerial,
        features: [
          Features.msg,
          Features.lastMove,
          Features.check,
          // Features.side,
          // Features.resign,
          // Features.undoRedo,
          // Features.undoOffer,
          // Features.drawOffer,
          // Features.getState,
          // Features.setState,
          Features.submoveState,
          // Features.drawReason,
          Features.option,
        ],
        variants: [Variants.standard],
      ) {
    _features = CppFeatureSupport(_peripheral);
    _variants = CppVariantSupport(_peripheral);
    _round = CppRound(_peripheral.round);
    _peripheral.moveStream.listen(_handlePeripheralMove);
  }
  final driver.Peripheral _peripheral;
  late CppFeatureSupport _features;
  late CppVariantSupport _variants;
  late CppRound _round;

  final _moveController = StreamController<NormalMove>.broadcast();

  @override
  FeatureSupport get isFeatureSupported => _features;
  @override
  VariantSupport get isVariantSupported => _variants;

  @override
  bool get isInitialized => _peripheral.isInitialized;
  @override
  Round get round => _round;
  @override
  bool get areOptionsInitialized => _peripheral.areOptionsInitialized;
  @override
  List<Option> get options => _peripheral.options;

  @override
  Stream<void> get initializedStream => _peripheral.initializedStream;
  @override
  Stream<void> get roundInitializedStream => _peripheral.roundInitializedStream;
  @override
  Stream<void> get roundUpdateStream => _peripheral.roundUpdateStream;
  @override
  Stream<bool> get stateSynchronizeStream => _peripheral.stateSynchronizeStream;
  @override
  Stream<NormalMove> get moveStream => _moveController.stream;
  @override
  Stream<String> get errStream => _peripheral.errStream;
  @override
  Stream<String> get msgStream => _peripheral.msgStream;
  @override
  Stream<void> get movedStream => _peripheral.movedStream;
  @override
  Stream<void> get resignStream => _peripheral.resignStream;
  @override
  Stream<void> get undoOfferStream => _peripheral.undoOfferStream;
  @override
  Stream<bool> get undoOfferAckStream => _peripheral.undoOfferAckStream;
  @override
  Stream<void> get drawOfferStream => _peripheral.drawOfferStream;
  @override
  Stream<bool> get drawOfferAckStream => _peripheral.drawOfferAckStream;
  @override
  Stream<void> get optionsUpdateStream => _peripheral.optionsUpdateStream;

  @override
  Future<void> handleBegin({
    required Position position,
    required Variant variant,
    NormalMove? lastMove,
    Side? side,
    String? time,
  }) async {
    await _peripheral.handleBegin(
      fen: position.fen,
      variant: _getVariant(variant),
      side: _getSide(side),
      lastMove: lastMove?.uci,
      check: _getCheck(position),
    );
  }

  @override
  Future<void> handleMove({
    required Position position,
    required NormalMove move,
    String? time,
  }) async {
    await _peripheral.handleMove(move: move.uci, check: _getCheck(position));
  }

  @override
  Future<void> handleReject() async {
    await _peripheral.handleReject();
  }

  @override
  Future<void> handleEnd({
    String? reason,
    String? drawReason,
    String? variantReason,
    String? score,
  }) async {
    await _peripheral.handleEnd(
      reason: reason,
      drawReason: drawReason,
      variantReason: variantReason,
      score: score,
    );
  }

  @override
  Future<void> handleErr({required String err}) async {
    await _peripheral.handleErr(err: err);
  }

  @override
  Future<void> handleMsg({required String msg}) async {
    await _peripheral.handleMsg(msg: msg);
  }

  @override
  Future<void> handleUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    await _peripheral.handleUndo(fen: fen, lastMove: lastMove, check: check, time: time);
  }

  @override
  Future<void> handleRedo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {
    await _peripheral.handleRedo(fen: fen, lastMove: lastMove, check: check, time: time);
  }

  @override
  Future<void> handleUndoOffer() async {
    await _peripheral.handleUndoOffer();
  }

  @override
  Future<void> handleDrawOffer() async {
    await _peripheral.handleDrawOffer();
  }

  @override
  Future<void> handleGetState() async {
    await _peripheral.handleGetState();
  }

  @override
  Future<void> handleSetState() async {
    await _peripheral.handleSetState();
  }

  @override
  Future<void> handleState({required String fen}) async {
    await _peripheral.handleState(fen: fen);
  }

  @override
  Future<void> handleOptionsBegin() async {
    await _peripheral.handleOptionsBegin();
  }

  @override
  Future<void> handleOptionsReset() async {
    await _peripheral.handleOptionsReset();
  }

  void _handlePeripheralMove(String uci) {
    _moveController.add(NormalMove.fromUci(uci));
  }

  String? _getVariant(Variant variant) {
    return variant.label.toLowerCase(); // TODO: Use map
  }

  String? _getSide(Side? side) {
    return side != null
        ? side == Side.white
              ? Sides.white
              : Sides.black
        : Sides.both;
  }

  String? _getCheck(Position position) {
    final king = position.board.kingOf(position.turn);
    return king != null && position.checkers.isNotEmpty ? king.name : null;
  }
}
