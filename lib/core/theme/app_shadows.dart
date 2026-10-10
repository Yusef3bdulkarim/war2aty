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

  /// Just the contact layer of [card]: `0 1px 3px rgba(20,40,45,.06)`.
  ///
  /// The design uses it for surfaces that sit *on* the page rather than above
  /// it — a collapsed panel, a row inside a sheet.
  static const List<BoxShadow> low = [
    BoxShadow(color: Color(0x0F142D31), blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// The softer, single shadow the design puts under an empty-state
  /// illustration's page: `0 8px 22px rgba(20,40,45,.08)`.
  ///
  /// **Currently unused.** Its only two callers — Home's and «مستنداتي»'s
  /// empty-state art — dropped their shadows at the owner's request
  /// (F29-T02), and the owner asked for the token itself to stay for future
  /// use rather than be deleted with them. Anything reaching for it again
  /// should check that decision first.
  static const List<BoxShadow> paper = [
    BoxShadow(color: Color(0x14142D31), blurRadius: 22, offset: Offset(0, 8)),
  ];
}
