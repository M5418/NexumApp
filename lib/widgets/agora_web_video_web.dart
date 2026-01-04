// Web implementation for Agora video display
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

final Set<String> _registeredViews = {};
final Map<String, html.DivElement> _videoContainers = {};

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
        ..style.backgroundColor = 'black'
        ..style.position = 'relative';
      
      // Store reference for Agora to find
      _videoContainers[containerId] = div;
      
      // Also add to document body as a hidden reference for Agora SDK
      // Agora SDK searches document.body for elements by ID
      return div;
    },
  );
  
  _registeredViews.add(containerId);
}

/// Get the actual DOM element for a container ID
html.DivElement? getVideoContainer(String containerId) {
  return _videoContainers[containerId];
}

/// Wait for the video container to be available in DOM
Future<bool> waitForContainer(String containerId, {int maxWaitMs = 2000}) async {
  final startTime = DateTime.now().millisecondsSinceEpoch;
  while (DateTime.now().millisecondsSinceEpoch - startTime < maxWaitMs) {
    final element = html.document.getElementById(containerId);
    if (element != null) {
      return true;
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
  return false;
}

Widget buildVideoView(String containerId) {
  return HtmlElementView(
    viewType: containerId,
  );
}
