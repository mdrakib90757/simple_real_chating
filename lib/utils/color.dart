import 'dart:ui';

import 'package:flutter/material.dart';

class AppColor {
  static Color primaryColor = Color(0xFF321A92);
}

Color getCallColor(String callID, List<String> usedCallIDs) {
  final colors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  int index;
  if (usedCallIDs.contains(callID)) {
    // Already used, pick the same index
    index = usedCallIDs.indexOf(callID) % colors.length;
  } else {
    // New call, pick first unused color
    final availableIndexes = List.generate(
      colors.length,
      (i) => i,
    ).where((i) => !usedCallIDs.contains(colors[i].toString())).toList();
    index = availableIndexes.isNotEmpty ? availableIndexes.first : 0;
    usedCallIDs.add(callID);
  }
  return colors[index];
}
