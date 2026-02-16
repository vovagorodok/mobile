import 'package:dartchess/dartchess.dart';
import 'package:lichess_mobile/src/model/bluetooth/option.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral_piece.dart';
import 'package:lichess_mobile/src/model/bluetooth/score.dart';
import 'package:lichess_mobile/src/model/bluetooth/time.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';

abstract class FeatureSupport {
  bool get getState;
  bool get setState;
  bool get submoveState;
  bool get lastMove;
  bool get check;
  bool get moved;
  bool get msg;
  bool get resign;
  bool get undoRedo;
  bool get undoOffer;
  bool get drawOffer;
  bool get side;
  bool get time;
  bool get score;
  bool get option;
  bool get drawReason;
  bool get variantReason;
}

abstract class VariantSupport {
  bool get standard;
  bool get chess960;
  bool get threeCheck;
  bool get atomic;
  bool get kingOfTheHill;
  bool get antiChess;
  bool get horde;
  bool get racingKings;
  bool get crazyHouse;
}

abstract class Round {
  bool get isVariantSupported;
  bool get isStateSynchronized;
  // get_state feature
  bool get isStateGettable;
  // set_state feature
  bool get isStateSettable;

  PeripheralPieces? get pieces;
  NormalMove? get rejectedMove;
}

abstract class Peripheral {
  FeatureSupport get isFeatureSupported;
  VariantSupport get isVariantSupported;

  bool get isInitialized;
  Round get round;
  // option feature
  bool get areOptionsInitialized;
  List<Option> get options;

  Stream<void> get initializedStream;
  Stream<void> get roundInitializedStream;
  Stream<void> get roundUpdateStream;
  Stream<bool> get stateSynchronizeStream;
  Stream<NormalMove> get moveStream;
  Stream<String> get errStream;
  // msg feature
  Stream<String> get msgStream;
  // moved feature
  Stream<void> get movedStream;
  // resign feature
  Stream<void> get resignStream;
  // undo_offer feature
  Stream<void> get undoOfferStream;
  Stream<bool> get undoOfferAckStream;
  // draw_offer feature
  Stream<void> get drawOfferStream;
  Stream<bool> get drawOfferAckStream;
  // option feature
  Stream<void> get optionsUpdateStream;

  Future<void> handleBegin({
    required Position position,
    required Variant variant,
    NormalMove? lastMove,
    Side? side,
    Time? time,
  });
  Future<void> handleMove({required Position position, required NormalMove move, Time? time});
  Future<void> handleReject();
  Future<void> handleEnd({GameStatus? status, Variant? variant, Score? score});
  Future<void> handleErr({required String err});
  // msg feature
  Future<void> handleMsg({required String msg});
  // undo_redo feature
  Future<void> handleUndo({required String fen, String? lastMove, String? check, String? time});
  Future<void> handleRedo({required String fen, String? lastMove, String? check, String? time});
  // undo_offer feature
  Future<void> handleUndoOffer();
  // draw_offer feature
  Future<void> handleDrawOffer();
  // get_state feature
  Future<void> handleGetState();
  // set_state feature
  Future<void> handleSetState();
  // submove_state feature
  Future<void> handleState({required String fen});
  // option feature
  Future<void> handleOptionsBegin();
  Future<void> handleOptionsReset();
}
