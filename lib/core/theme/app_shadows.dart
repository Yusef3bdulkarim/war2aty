import 'package:flutter/painting.dart';

/// Elevation shadows from the Waraqti design.
///
/// The design gives every raised card the same two-layer shadow: a tight
/// contact shadow plus a wide soft one. Keeping it in one place means a card
/// on Home, in the documents list and in a result all sit at the same height.
abstract final class AppShadows {
  /// `0 1px 3px rgba(20,40,45,.06), 0 8px 22px rgba(20,40,45,.05)`.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F142D31), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D142D31), blurRadius: 22, offset: Offset(0, 8)),
  ];

  /// The softer, single shadow the empty-state illustration's page uses:
  /// `0 8px 22px rgba(20,40,45,.08)`.
  static const List<BoxShadow> paper = [
    BoxShadow(color: Color(0x14142D31), blurRadius: 22, offset: Offset(0, 8)),
  ];
}
