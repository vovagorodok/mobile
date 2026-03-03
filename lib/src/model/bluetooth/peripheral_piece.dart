import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';

@immutable
class PeripheralPiece {
  const PeripheralPiece({this.color, this.role, this.promoted = false});

  final Side? color;
  final Role? role;
  final bool promoted;

  PeripheralPiece copyWith({Side? color, Role? role, bool? promoted}) {
    return PeripheralPiece(
      color: color ?? this.color,
      role: role ?? this.role,
      promoted: promoted ?? this.promoted,
    );
  }
}

typedef PeripheralPieces = Map<Square, PeripheralPiece>;
