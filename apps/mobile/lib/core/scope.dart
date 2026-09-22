import 'package:flutter/material.dart';

import 'services.dart';

class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final Services services;

  static Services of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ServicesScope>();
    assert(scope != null, 'ServicesScope introuvable');
    return scope!.services;
  }

  static Services? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServicesScope>()?.services;

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      oldWidget.services != services;
}
