import 'package:flutter/widgets.dart';

import 'app_state.dart';
import 'playback/sleep_timer.dart';
import 'playback/tuner.dart';
import 'profiles/household.dart';

/// Makes [AppState], the [Tuner] and the [SleepTimer] available to the
/// widget tree and rebuilds dependents when app state changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState app, required this.tuner, this.sleep, required super.child})
      : super(notifier: app);

  final Tuner tuner;

  /// The sleep timer, made with the tuner (screens built without one, in
  /// tests, have no sleep controls).
  final SleepTimer? sleep;

  static SleepTimer? sleepOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()?.sleep;

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing to rebuilds (for callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static Tuner tunerOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.tuner;
}

/// Makes the [Household] (profiles, who's watching) available everywhere.
class HouseholdScope extends InheritedNotifier<Household> {
  const HouseholdScope({super.key, required Household household, required super.child})
      : super(notifier: household);

  static Household of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HouseholdScope>()!.notifier!;

  /// Read without subscribing to rebuilds (for callbacks).
  static Household read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HouseholdScope>()!.notifier!;
}
