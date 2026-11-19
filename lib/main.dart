import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError('Supabase configuration missing');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(
    const ProviderScope(
      child: PromatchfixApp(),
    ),
  );
}

class PromatchfixApp extends StatelessWidget {
  const PromatchfixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Promatchfix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7041D8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FC),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}