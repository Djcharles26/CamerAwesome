import 'package:flutter/material.dart';

/// Since .withOpacityA was depreciated, this util replace withOpacityA for withOpacityAA
extension ColorsExt on Color {
  Color withOpacityA (double opacity) {
    return withAlpha((255 * opacity.clamp (0, 1)).ceil ());
  }
}