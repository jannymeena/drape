import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hydrate the session flag before the router's first redirect runs.
  await SessionStore.load();
  runApp(const ProviderScope(child: DrapeApp()));
}
