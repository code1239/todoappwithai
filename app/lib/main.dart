import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api_client.dart';
import 'providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  final api = await ApiClient.create();
  runApp(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const TodoApp(),
    ),
  );
}

class TodoApp extends ConsumerWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'Planlayici',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: !auth.initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.loggedIn
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}
