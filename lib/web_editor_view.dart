// Web implementation — registers an iframe view factory for the TipTap editor.
// This file is only compiled on the web platform.
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/widgets.dart';

const String editorViewType = 'editor-iframe-view';
const String editorUrl = 'http://127.0.0.1:8000';

void registerEditorViewFactory() {
  ui_web.platformViewRegistry.registerViewFactory(
    editorViewType,
    (int viewId) {
      final iframe = html.IFrameElement()
        ..id = 'govgen-editor-iframe'
        ..src = editorUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'auto';
      return iframe;
    },
  );
}

/// Web version of the editor body — renders the iframe.
Widget buildEditorView() {
  return const HtmlElementView(viewType: editorViewType);
}

/// Sends HTML content to the web iframe via postMessage.
void sendHtmlToWebEditor(String htmlContent) {
  final iframes = html.document.querySelectorAll('iframe');
  for (final element in iframes) {
    if (element is html.IFrameElement && element.src?.contains(editorUrl) == true) {
      element.contentWindow?.postMessage({
        'type': 'insertContent',
        'content': htmlContent
      }, '*');
      break;
    }
  }
}

