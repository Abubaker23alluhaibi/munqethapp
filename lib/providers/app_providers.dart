import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';
import 'order_provider.dart';

/// قائمة جميع Providers في التطبيق
class AppProviders {
  static List<SingleChildWidget> get providers => [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(create: (_) => OrderProvider()),
  ];

  /// Helper method للحصول على Provider
  static T of<T>(BuildContext context) {
    return Provider.of<T>(context, listen: false);
  }

  /// Helper method للحصول على Provider مع listening
  static T watch<T>(BuildContext context) {
    return Provider.of<T>(context);
  }
}









