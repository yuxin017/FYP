import 'package:flutter/material.dart';

/// A signed-in visitor's temporary session at a staffed photo terminal.
class PhotoSessionScope extends InheritedWidget {
  final Future<void> Function(String? collectionPass) finish;
  const PhotoSessionScope({
    super.key,
    required this.finish,
    required super.child,
  });
  static PhotoSessionScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoSessionScope>();
  @override
  bool updateShouldNotify(PhotoSessionScope oldWidget) =>
      finish != oldWidget.finish;
}
