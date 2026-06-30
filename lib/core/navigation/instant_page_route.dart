import 'package:flutter/material.dart';

Route<T> instantPageRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => child,
  );
}
