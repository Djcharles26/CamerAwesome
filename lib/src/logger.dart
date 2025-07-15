import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/foundation.dart';

/// Print logs if [CamerawesomePlugins.printLogs] is true, otherwise stays quiet
void printLog(String text) {
  if (CamerawesomePlugin.printLogs) {
    debugPrint(text);
  }
}
