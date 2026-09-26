import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A message from a controller (not a screen) for the app root to show, e.g. "Your driver cancelled
/// the ride" pushed by the server. With [goTo] the app also navigates there first.
@immutable
class AppNotice {
  const AppNotice(this.message, {this.goTo});
  final String message;
  final String? goTo;
}

/// Every [show] emits a new notice (instances are never equal), so the same text can repeat.
class AppNoticeController extends Notifier<AppNotice?> {
  @override
  AppNotice? build() => null;

  void show(String message, {String? goTo}) => state = AppNotice(message, goTo: goTo);
}

final appNoticeProvider = NotifierProvider<AppNoticeController, AppNotice?>(AppNoticeController.new);
