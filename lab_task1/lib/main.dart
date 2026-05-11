import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'models/cart.dart';
import 'screens/cart.dart';
import 'screens/catalog.dart';
import 'screens/login.dart';

void main() {
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/catalog',
      builder: (context, state) => const CatalogScreen(),
      routes: [
        GoRoute(
          path: 'cart',
          builder: (context, state) => const CartScreen(),
        ),
      ],
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Quản lý state giỏ hàng bằng provider (ChangeNotifier, ChangeNotifierProvider, Consumer)
    return ChangeNotifierProvider(
      create: (context) => CartModel(),
      child: MaterialApp.router(
        title: 'Shopping Cart App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.yellow,
        ),
        routerConfig: _router,
      ),
    );
  }
}
