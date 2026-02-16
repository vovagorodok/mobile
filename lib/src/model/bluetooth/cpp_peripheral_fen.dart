import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral_piece.dart';

PeripheralPieces readPeripheralFen(String fen) {
  final PeripheralPieces pieces = {};
  int rank = 7;
  int file = 0;
  for (final c in fen.characters) {
    switch (c) {
      case ' ':
      case '[':
        return pieces;
      case '/':
        --rank;
        if (rank < 0) return pieces;
        file = 0;
      case '~':
        final square = Square.fromCoords(File(file - 1), Rank(rank));
        final piece = pieces[square];
        if (piece != null) {
          pieces[square] = piece.copyWith(promoted: true);
        }
      default:
        final code = c.codeUnitAt(0);
        if (code < 57) {
          file += code - 48;
        } else {
          final roleLetter = c.toLowerCase();
          final square = Square.fromCoords(File(file), Rank(rank));
          pieces[square] = PeripheralPiece(
            role: 'u?'.contains(roleLetter) ? null : _rolesMap[roleLetter]!,
            color: roleLetter == '?'
                ? null
                : c == roleLetter
                ? Side.black
                : Side.white,
          );
          ++file;
        }
    }
  }
  return pieces;
}

bool isPeripheralFenGettable(String? fen) {
  return fen != null && !fen.contains(RegExp(r'[uU?]'));
}

const _rolesMap = {
  'p': Role.pawn,
  'r': Role.rook,
  'n': Role.knight,
  'b': Role.bishop,
  'q': Role.queen,
  'k': Role.king,
  'm': Role.pawn,
  'd': Role.queen,
};
