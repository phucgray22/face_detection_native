import 'package:easy_debounce/easy_debounce.dart';

class DebounceUtils {
  static debounce({
    String tag = '',
    int milliseconds = 500,
    Function() callback,
  }) {
    EasyDebounce.debounce(
      tag,
      Duration(milliseconds: milliseconds),
      () {
        callback?.call();
      },
    );
  }

  static cancel(String tag) {
    EasyDebounce.cancel(tag);
  }

  static cancelAll() {
    EasyDebounce.cancelAll();
  }
}