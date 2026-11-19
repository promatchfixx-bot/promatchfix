
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    throw StateError(
      'Supabase configuration is missing.',
    );
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
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.handyman_outlined,
              size: 64,
              color: Color(0xFF7041D8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Promatchfix',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ระบบค้นหาช่างและบริการสำหรับทุกคน',
            ),
            const SizedBox(height: 24),
            const Chip(
              avatar: Icon(Icons.cloud_done),
              label: Text('Supabase Connected'),
            ),
          ],
        ),
      ),
    );
  }
}
