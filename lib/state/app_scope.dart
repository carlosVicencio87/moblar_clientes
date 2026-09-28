import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Pone [AppState] al alcance de toda la app sin paquetes extra.
///
/// `AppScope.of(context)` redibuja el widget cuando el estado cambia;
/// `AppScope.read(context)` solo lo consulta (para callbacks de botones).
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
