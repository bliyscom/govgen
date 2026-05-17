// Stub file for native (non-web) platforms.
// This provides no-op implementations of the web-specific functions.
import 'package:flutter/widgets.dart';

void registerEditorViewFactory() {
  // No-op on native — WebViewController is used directly.
}

Widget buildEditorView() {
  // Should never be called on native — WebViewWidget is used instead.
  return const SizedBox.shrink();
}

void sendHtmlToWebEditor(String htmlContent) {
  // No-op on native.
}
