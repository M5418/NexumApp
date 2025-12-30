// Web implementation for Agora video display
// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

final Set<String> _registeredViews = {};

void registerVideoView(String containerId) {
  if (_registeredViews.contains(containerId)) return;
  
  // Create a div element for Agora to render video into
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    containerId,
    (int viewId) {
      final div = html.DivElement()
        ..id = containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black';
      return div;
    },
  );
  
  _registeredViews.add(containerId);
}

Widget buildVideoView(String containerId) {
  return HtmlElementView(
    viewType: containerId,
  );
}
