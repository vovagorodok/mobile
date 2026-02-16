import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/bluetooth/option.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral_piece.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';

class DummyFeatureSupport implements FeatureSupport {
  @override
  bool get getState => false;
  @override
  bool get setState => false;
  @override
  bool get submoveState => false;
  @override
  bool get lastMove => false;
  @override
  bool get check => false;
  @override
  bool get moved => false;
  @override
  bool get msg => false;
  @override
  bool get resign => false;
  @override
  bool get undoRedo => false;
  @override
  bool get undoOffer => false;
  @override
  bool get drawOffer => false;
  @override
  bool get side => false;
  @override
  bool get time => false;
  @override
  bool get score => false;
  @override
  bool get option => false;
  @override
  bool get drawReason => false;
  @override
  bool get variantReason => false;
}

class DummyVariantSupport implements VariantSupport {
  @override
  bool get standard => false;
  @override
  bool get chess960 => false;
  @override
  bool get threeCheck => false;
  @override
  bool get atomic => false;
  @override
  bool get kingOfTheHill => false;
  @override
  bool get antiChess => false;
  @override
  bool get horde => false;
  @override
  bool get racingKings => false;
  @override
  bool get crazyHouse => false;
}

class DummyRound implements Round {
  @override
  bool get isVariantSupported => false;
  @override
  bool get isStateSynchronized => false;
  @override
  bool get isStateGettable => false;
  @override
  bool get isStateSettable => false;
  @override
  PeripheralPieces? get pieces => null;
  @override
  NormalMove? get rejectedMove => null;
}

class DummyPeripheral implements Peripheral {
  final features = DummyFeatureSupport();
  final variants = DummyVariantSupport();
  final dummyRound = DummyRound();

  @override
  FeatureSupport get isFeatureSupported => features;
  @override
  VariantSupport get isVariantSupported => variants;

  @override
  bool get isInitialized => false;
  @override
  Round get round => dummyRound;
  @override
  bool get areOptionsInitialized => false;
  @override
  List<Option> get options => [];

  @override
  Stream<void> get initializedStream => const Stream.empty();
  @override
  Stream<void> get roundInitializedStream => const Stream.empty();
  @override
  Stream<void> get roundUpdateStream => const Stream.empty();
  @override
  Stream<bool> get stateSynchronizeStream => const Stream.empty();
  @override
  Stream<NormalMove> get moveStream => const Stream.empty();
  @override
  Stream<String> get errStream => const Stream.empty();
  @override
  Stream<String> get msgStream => const Stream.empty();
  @override
  Stream<void> get movedStream => const Stream.empty();
  @override
  Stream<void> get resignStream => const Stream.empty();
  @override
  Stream<void> get undoOfferStream => const Stream.empty();
  @override
  Stream<bool> get undoOfferAckStream => const Stream.empty();
  @override
  Stream<void> get drawOfferStream => const Stream.empty();
  @override
  Stream<bool> get drawOfferAckStream => const Stream.empty();
  @override
  Stream<void> get optionsUpdateStream => const Stream.empty();

  @override
  Future<void> handleBegin({
    required Position position,
    required Variant variant,
    NormalMove? lastMove,
    Side? side,
    String? time,
  }) async {}
  @override
  Future<void> handleMove({
    required Position position,
    required NormalMove move,
    String? time,
  }) async {}
  @override
  Future<void> handleReject() async {}
  @override
  Future<void> handleEnd({GameStatus? status, Variant? variant, String? score}) async {}
  @override
  Future<void> handleErr({required String err}) async {}
  @override
  Future<void> handleMsg({required String msg}) async {}
  @override
  Future<void> handleUndo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {}
  @override
  Future<void> handleRedo({
    required String fen,
    String? lastMove,
    String? check,
    String? time,
  }) async {}
  @override
  Future<void> handleUndoOffer() async {}
  @override
  Future<void> handleDrawOffer() async {}
  @override
  Future<void> handleGetState() async {}
  @override
  Future<void> handleSetState() async {}
  @override
  Future<void> handleState({required String fen}) async {}
  @override
  Future<void> handleOptionsBegin() async {}
  @override
  Future<void> handleOptionsReset() async {}
}
