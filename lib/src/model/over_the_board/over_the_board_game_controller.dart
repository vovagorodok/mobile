import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/bluetooth/bluetooth_service.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/common/chess960.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/common/perf.dart';
import 'package:lichess_mobile/src/model/common/service/move_feedback.dart';
import 'package:lichess_mobile/src/model/common/speed.dart';
import 'package:lichess_mobile/src/model/common/time_increment.dart';
import 'package:lichess_mobile/src/model/game/game.dart';
import 'package:lichess_mobile/src/model/game/game_status.dart';
import 'package:lichess_mobile/src/model/game/material_diff.dart';
import 'package:lichess_mobile/src/model/game/over_the_board_game.dart';

part 'over_the_board_game_controller.freezed.dart';

final _random = Random();

final overTheBoardGameControllerProvider =
    NotifierProvider.autoDispose<OverTheBoardGameController, OverTheBoardGameState>(
      OverTheBoardGameController.new,
      name: 'OverTheBoardGameControllerProvider',
    );

class OverTheBoardGameController extends Notifier<OverTheBoardGameState> {
  @override
  OverTheBoardGameState build() => OverTheBoardGameState.fromVariant(
    Variant.standard,
    Speed.fromTimeIncrement(const TimeIncrement(0, 0)),
  );

  void startNewGame(Variant variant, TimeIncrement timeIncrement, {String? initialFen}) {
    state = OverTheBoardGameState.fromVariant(
      variant,
      Speed.fromTimeIncrement(timeIncrement),
      initialFen: initialFen,
    );
    _sendBeginToBluetooth();
  }

  void loadOngoingGame(OverTheBoardGame game) {
    state = OverTheBoardGameState(game: game, stepCursor: game.steps.length - 1);
    _sendBeginToBluetooth();
  }

  void rematch() {
    state = OverTheBoardGameState.fromVariant(
      state.game.meta.variant,
      state.game.meta.speed,
      initialFen: state.game.initialFen,
    );
    _sendBeginToBluetooth();
  }

  void resign() {
    state = state.copyWith(
      game: state.game.copyWith(status: GameStatus.resign, winner: state.turn.opposite),
    );
    _sendEndToBluetooth();
  }

  void draw() {
    state = state.copyWith(game: state.game.copyWith(status: GameStatus.draw));
    _sendEndToBluetooth();
  }

  void makeMove(Move move) {
    if (move case NormalMove() when isPromotionPawnMove(state.currentPosition, move)) {
      state = state.copyWith(promotionMove: move);
      return;
    }

    final (newPos, newSan) = state.currentPosition.makeSan(Move.parse(move.uci)!);
    final sanMove = SanMove(newSan, move);
    final newStep = GameStep(
      position: newPos,
      sanMove: sanMove,
      diff: MaterialDiff.fromPosition(newPos),
    );

    // In an over-the-board game, we support "implicit takebacks":
    // When going back one or more steps (i.e. stepCursor < game.steps.length - 1),
    // a new move can be made, removing all steps after the current stepCursor.
    state = state.copyWith(
      game: state.game.copyWith(
        steps: state.game.steps
            .removeRange(state.stepCursor + 1, state.game.steps.length)
            .add(newStep),
      ),
      stepCursor: state.stepCursor + 1,
    );

    // check for threefold repetition
    if (state.game.steps.count((p) => p.position.board == newStep.position.board) == 3) {
      state = state.copyWith(game: state.game.copyWith(isThreefoldRepetition: true));
    } else {
      state = state.copyWith(game: state.game.copyWith(isThreefoldRepetition: false));
    }

    if (state.currentPosition.isCheckmate) {
      state = state.copyWith(
        game: state.game.copyWith(status: GameStatus.mate, winner: state.turn.opposite),
      );
    } else if (state.currentPosition.isStalemate) {
      state = state.copyWith(game: state.game.copyWith(status: GameStatus.stalemate));
    } else if (state.currentPosition.variantOutcome != null) {
      switch (state.currentPosition.variantOutcome!.winner) {
        case Side.white:
          state = state.copyWith(
            game: state.game.copyWith(status: GameStatus.variantEnd, winner: Side.white),
          );
        case Side.black:
          state = state.copyWith(
            game: state.game.copyWith(status: GameStatus.variantEnd, winner: Side.black),
          );
        case null:
          state = state.copyWith(game: state.game.copyWith(status: GameStatus.variantEnd));
      }
    }

    _sendMoveToBluetooth(move);
    _moveFeedback(sanMove);
  }

  void makeBluetoothMove(Move move) {
    if (state.currentPosition.isLegal(move)) {
      makeMove(move);
    } else {
      ref.read(bluetoothServiceProvider).handleReject();
    }
  }

  void onPromotionSelection(Role? role) {
    if (role == null) {
      state = state.copyWith(promotionMove: null);
      return;
    }
    final promotionMove = state.promotionMove;
    if (promotionMove != null) {
      final move = promotionMove.withPromotion(role);
      makeMove(move);
      state = state.copyWith(promotionMove: null);
    }
  }

  void onFlag(Side side) {
    state = state.copyWith(
      game: state.game.copyWith(status: GameStatus.outoftime, winner: side.opposite),
    );
    _sendEndToBluetooth();
  }

  void goForward() {
    if (state.canGoForward) {
      state = state.copyWith(stepCursor: state.stepCursor + 1, promotionMove: null);
      _sendRedoToBluetooth();
    }
  }

  void goBack() {
    if (state.canGoBack) {
      state = state.copyWith(stepCursor: state.stepCursor - 1, promotionMove: null);
      _sendUndoToBluetooth();
    }
  }

  void offerDraw() {
    final service = ref.read(bluetoothServiceProvider);
    if (service.isFeatureSupported.drawOffer) {
      service.handleDrawOffer();
    }
  }

  void _sendBeginToBluetooth() {
    final service = ref.read(bluetoothServiceProvider);
    service.handleBegin(
      position: state.currentPosition,
      variant: state.game.meta.variant,
      lastMove: state.lastMove,
    );
  }

  void _sendMoveToBluetooth(Move move) {
    final service = ref.read(bluetoothServiceProvider);
    service.handleMove(
      position: state.currentPosition,
      variant: state.game.meta.variant,
      move: move,
    );
    if (state.game.finished) {
      service.handleEnd(variant: state.game.meta.variant, status: state.game.status);
    }
  }

  void _sendEndToBluetooth() {
    final service = ref.read(bluetoothServiceProvider);
    service.handleEnd(variant: state.game.meta.variant, status: state.game.status);
  }

  void _sendUndoToBluetooth() {
    final service = ref.read(bluetoothServiceProvider);
    service.handleUndo(
      position: state.currentPosition,
      variant: state.game.meta.variant,
      lastMove: state.lastMove,
    );
  }

  void _sendRedoToBluetooth() {
    final service = ref.read(bluetoothServiceProvider);
    service.handleRedo(
      position: state.currentPosition,
      variant: state.game.meta.variant,
      lastMove: state.lastMove,
    );
  }

  void _moveFeedback(SanMove sanMove) {
    final isCheck = sanMove.san.contains('+');
    if (sanMove.san.contains('x')) {
      ref
          .read(moveFeedbackServiceProvider)
          .captureFeedback(state.game.meta.variant, check: isCheck);
    } else {
      ref.read(moveFeedbackServiceProvider).moveFeedback(check: isCheck);
    }
  }
}

@freezed
sealed class OverTheBoardGameState with _$OverTheBoardGameState {
  const OverTheBoardGameState._();

  const factory OverTheBoardGameState({
    required OverTheBoardGame game,
    @Default(0) int stepCursor,
    @Default(null) NormalMove? promotionMove,
  }) = _OverTheBoardGameState;

  factory OverTheBoardGameState.fromVariant(Variant variant, Speed speed, {String? initialFen}) {
    final Position position;
    final Variant effectiveVariant;
    if (initialFen != null) {
      effectiveVariant = variant == Variant.standard ? Variant.fromPosition : variant;
      position = Position.setupPosition(effectiveVariant.rule, Setup.parseFen(initialFen));
    } else if (variant == Variant.chess960) {
      position = randomChess960Position();
      effectiveVariant = variant;
    } else {
      position = variant.initialPosition;
      effectiveVariant = variant;
    }
    final sessionId = StringId('otb_${_random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0')}');
    return OverTheBoardGameState(
      game: OverTheBoardGame(
        id: sessionId,
        steps: [GameStep(position: position)].lock,
        status: GameStatus.started,
        initialFen: initialFen,
        meta: GameMeta(
          createdAt: DateTime.now(),
          rated: false,
          variant: effectiveVariant,
          speed: speed,
          perf: Perf.fromVariantAndSpeed(effectiveVariant, speed),
        ),
      ),
    );
  }

  Position get currentPosition => game.stepAt(stepCursor).position;
  Side get turn => currentPosition.turn;
  bool get finished => game.finished;
  Move? get lastMove =>
      stepCursor > 0 ? Move.parse(game.steps[stepCursor].sanMove!.move.uci) : null;

  MaterialDiffSide? currentMaterialDiff(Side side) {
    return game.steps[stepCursor].diff?.bySide(side);
  }

  List<String> get moves => game.steps.skip(1).map((e) => e.sanMove!.san).toList(growable: false);

  bool get canGoForward => stepCursor < game.steps.length - 1;
  bool get canGoBack => stepCursor > 0;
}
