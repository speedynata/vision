import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final _supabase = Supabase.instance.client;

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

  Future<void> triggerPakanManual(int idKolam) async {
    await _supabase.from('sesi_pakan').insert({
      'id_kolam': idKolam,
      'waktu_mulai': DateTime.now().toUtc().toIso8601String(),
      'status_eksekusi': false,
    });
  }
}
