import 'package:flutter/foundation.dart';

class NotificationState {
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(2);

  static void setUnreadCount(int count) {
    unreadCount.value = count < 0 ? 0 : count;
  }
}
