import 'package:flutter/widgets.dart';

/// Shared observer for the router's root [Navigator] (registered on
/// [GoRouter]'s `observers`), so a screen can use [RouteAware] to notice when
/// it becomes visible again after a route pushed on top of it is popped.
///
/// This covers a case app-lifecycle resume ([WidgetsBindingObserver]) does
/// not: in-app navigation (push/pop) never changes the app's lifecycle state,
/// so a screen that only re-arms itself on resume — the camera viewfinder,
/// the gallery picker — stays stuck showing its last, already-consumed
/// terminal state when the user is popped back onto it (e.g. "retake" from
/// the preview screen, or the device back button from OCR review).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
