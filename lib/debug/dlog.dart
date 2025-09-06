import 'dart:collection';
import 'package:flutter/foundation.dart';

class DLog {
  static final _buf = ListQueue<String>(300);

  static void i(String msg) => _add('INFO  $msg');
  static void w(String msg) => _add('WARN  $msg');
  static void e(String tag, Object error, StackTrace? stack) {
    _add('ERROR $tag: $error\n$stack');
  }

  static void _add(String line) {
    final ts = DateTime.now().toIso8601String();
    final out = '[$ts] $line';
    if (kDebugMode) debugPrint(out);
    _buf.add(out);
    while (_buf.length > 300) {
      _buf.removeFirst();
    }
  }

  static List<String> dump() => List.unmodifiable(_buf);
  static void clear() => _buf.clear();
}
