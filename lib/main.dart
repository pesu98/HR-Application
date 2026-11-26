import 'package:flutter/material.dart';

import 'home_page.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LeaveStore();
  await store.load();
  runApp(LeaveApp(store: store));
}

class LeaveApp extends StatelessWidget {
  const LeaveApp({super.key, required this.store});

  final LeaveStore store;

  static const _seed = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Annual Leave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: HomePage(store: store),
    );
  }
}
