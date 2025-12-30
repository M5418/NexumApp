// Stub implementation for non-web platforms
import 'package:flutter/material.dart';

void registerVideoView(String containerId) {
  // No-op on non-web platforms
}

Widget buildVideoView(String containerId) {
  return Container(
    color: Colors.black,
    child: const Center(
      child: Text(
        'Web video not supported',
        style: TextStyle(color: Colors.grey),
      ),
    ),
  );
}
