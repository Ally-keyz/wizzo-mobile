import 'package:flutter/widgets.dart';

/// Root navigator key shared by the router and services that need to navigate
/// from outside the widget tree (e.g. tapping a push notification).
final rootNavigatorKey = GlobalKey<NavigatorState>();
