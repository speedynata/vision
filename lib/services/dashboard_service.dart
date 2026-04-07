import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DashboardService {
  final _supabase = Supabase.instance.client;

  // FAKTA KONFIGURASI: Ganti IP ini sesuai dengan IP Laptop lu di jaringan WiFi yang sama
  static const String _flaskBaseUrl = 'http://192.168.1.10:5001';

  // =======================================================
  // 1. LOGIKA SUPABASE (Data Historis & Profil)
  // =======================================================

  Future<Map<String, dynamic>?> getKolamInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Sesi tidak valid. Harap login kembali.');

    final response = await _supabase
        .from('kolam')
        .select()
        .eq('id_akun', user.id)
        .maybeSingle();
    return response;
  }

  Stream<List<Map<String, dynamic>>> streamRiwayatPh(int idKolam) {
    return _supabase
        .from('riwayat_ph')
        .stream(primaryKey: ['id_log'])
        .eq('id_kolam', idKolam)
        .order('waktu_rekam', ascending: false)
        .limit(24);
  }

  Future<Map<String, dynamic>?> getSesiPakanTerakhir(int idKolam) async {
    final response = await _supabase
        .from('sesi_pakan')
        .select('''
          *,
          telemetri_feeder ( sisa_pakan_persen ),
          log_visual_ai ( status_ikan )
        ''')
        .eq('id_kolam', idKolam)
        .order('waktu_mulai', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  Future<List<Map<String, dynamic>>> getRiwayatPakanLengkap(int idKolam) async {
    final response = await _supabase
        .from('sesi_pakan')
        .select('''
          *,
          telemetri_feeder ( sisa_pakan_persen, putaran_stepper ),
          log_visual_ai ( status_ikan, url_foto )
        ''')
        .eq('id_kolam', idKolam)
        .order('waktu_mulai', ascending: false);

    return response;
  }

  // =======================================================
  // 2. LOGIKA FLASK API (Data Real-time & Kontrol IoT)
  // =======================================================

  /// Mengambil status real-time langsung dari RAM Flask (pH, Persen, Jadwal)
  Future<Map<String, dynamic>> getRealtimeStatus() async {
    try {
      final response = await http.get(Uri.parse('$_flaskBaseUrl/api/status'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Server Flask merespons: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Gagal sinkronisasi real-time ke Flask: $e");
    }
  }

  /// Trigger pakan manual (tombol di Dashboard)
  Future<void> triggerPakanManual() async {
    try {
      final respons = await http.post(
        Uri.parse('$_flaskBaseUrl/api/kontrol'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"aksi": "feed"}),
      );

      if (respons.statusCode != 200) {
        throw Exception("Flask gagal mengeksekusi kontrol manual.");
      }
    } catch (e) {
      throw Exception("Koneksi ke Flask terputus: $e");
    }
  }
}
