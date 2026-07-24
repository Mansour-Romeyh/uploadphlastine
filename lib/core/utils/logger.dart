import 'package:flutter/foundation.dart';

void logInfo(Object? msg) {
  if (kDebugMode) debugPrint("ℹ️ $msg");
}

void logWarn(Object? msg) {
  if (kDebugMode) debugPrint("⚠️ $msg");
}

void logError(Object? msg, [Object? error]) {
  if (kDebugMode) debugPrint("❌ $msg ${error != null ? ': $error' : ''}");
}

void logSuccess(Object? msg) {
  if (kDebugMode) debugPrint("✅ $msg");
}
