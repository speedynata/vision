import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// FAKTA: Import file layar lu di sini
import 'screens/login_screen.dart';
// import 'screens/dashboard_screen.dart'; // Nanti buka komen ini kalau layarnya udah dibuat

Future<void> main() async {
  // Wajib dipanggil sebelum inisialisasi plugin native
  WidgetsFlutterBinding.ensureInitialized();

  // URL valid hasil ekstraksi dari project reference Supabase lu
  await Supabase.initialize(
    url: 'https://keginmdkkgtvaxchtjug.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtlZ2lubWRra2d0dmF4Y2h0anVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODkwOTEsImV4cCI6MjA4NzE2NTA5MX0.KGiNU8S1oLpJ1fep8p9uqVTFg0OwPRvxduGqzHLz3BU',
  );

  runApp(const MyApp());
}

// Global instance untuk mengakses client Supabase secara efisien di memori
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GATEKEEPER LOGIC: Membaca status token JWT di lokal storage perangkat.
    // Jika token masih valid dan belum expired, session tidak akan null.
    final session = supabase.auth.currentSession;

    return MaterialApp(
      title: 'V.I.S.I.O.N Awdy Farm',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // ROUTING: Arahkan langsung ke dashboard jika session ada, jika kosong lempar ke LoginScreen
      home: session != null
          ? const Scaffold(
              body: Center(
                child: Text('Ini ceritanya halaman Dashboard V.I.S.I.O.N'),
              ),
            )
          : const LoginScreen(),
    );
  }
}
