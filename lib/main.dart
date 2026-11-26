import 'package:flutter/material.dart';

import 'home_page.dart';
import 'store.dart';
import 'updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LeaveStore();
  await store.load();

  // In-app updates exist only on Android.
  final updates = GithubUpdateSource.supported ? UpdateController(GithubUpdateSource()) : null;
  runApp(LeaveApp(store: store, updates: updates));
  updates?.check();
}

class LeaveApp extends StatelessWidget {
  const LeaveApp({super.key, required this.store, this.updates});

  final LeaveStore store;

  /// Null where in-app updates are not supported.
  final UpdateController? updates;

  static const _seed = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Annual Leave',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      home: HomePage(store: store, updates: updates),
    );
  }
}
