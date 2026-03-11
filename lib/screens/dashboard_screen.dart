import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _dashboardService = DashboardService();
  final _authService = AuthService();

  Map<String, dynamic>? _kolamInfo;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isFeedingManual = false;

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _initDashboard();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initDashboard() async {
    try {
      final info = await _dashboardService.getKolamInfo();
      if (mounted) {
        setState(() {
          _kolamInfo = info;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data kolam: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _eksekusiPakanManual(int idKolam) async {
    setState(() {
      _isFeedingManual = true;
    });

    try {
      await _dashboardService.triggerPakanManual(idKolam);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Komando terkirim! Menunggu respons aktuator ESP32...',
          ),
          backgroundColor: const Color(0xFF0D1520),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim komando: $e'),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFeedingManual = false;
        });
      }
    }
  }

  bool _checkSistemOnline(String waktuRekamTerakhir) {
    final lastUpdate = DateTime.parse(waktuRekamTerakhir).toLocal();
    final difference = DateTime.now().difference(lastUpdate);
    return difference.inMinutes <= 30;
  }

  void _bukaDetailPh(int idKolam) {
    debugPrint("Navigasi ke Analitik pH Historis untuk kolam $idKolam");
    // Navigator.push(context, MaterialPageRoute(builder: (context) => PhHistoryScreen(idKolam: idKolam)));
  }

  void _bukaDetailTelemetri(int idKolam) {
    debugPrint("Navigasi ke Log Kamera AI untuk kolam $idKolam");
    // Navigator.push(context, MaterialPageRoute(builder: (context) => TelemetriHistoryScreen(idKolam: idKolam)));
  }

  @override
  Widget build(BuildContext context) {
    // --- Loading State ---
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF080C14),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF00C9A7),
                strokeWidth: 2,
              ),
              SizedBox(height: 20),
              Text(
                'MENGINISIALISASI SISTEM...',
                style: TextStyle(
                  color: Color(0xFF3A5A6A),
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- Error State ---
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF080C14),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE63946).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFFE63946).withOpacity(0.05),
                  ),
                  child: const Icon(
                    Icons.signal_wifi_connected_no_internet_4,
                    size: 48,
                    color: Color(0xFFE63946),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'KONEKSI GAGAL',
                  style: TextStyle(
                    color: Color(0xFFE63946),
                    fontSize: 13,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4A6070),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Empty State ---
    if (_kolamInfo == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080C14),
        appBar: _buildAppBar('TIDAK ADA KOLAM'),
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _GridPainter())),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    size: 56,
                    color: Color(0xFF1C2E3E),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'TIDAK ADA DATA EMPANG',
                    style: TextStyle(
                      color: Color(0xFF00C9A7),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Sistem tidak mendeteksi kolam yang terikat\ndengan identitas akun Anda saat ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF4A6070),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final idKolam = _kolamInfo!['id_kolam'] as int;
    final namaKolam = _kolamInfo!['nama_kolam'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: _buildAppBar(namaKolam),
      body: Stack(
        children: [
          // Grid background
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _dashboardService.streamRiwayatPh(idKolam),
                    builder: (context, snapshot) {
                      bool isOnline = false;
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        isOnline = _checkSistemOnline(
                          snapshot.data!.first['waktu_rekam'],
                        );
                      }
                      return _buildStatusHeader(isOnline);
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildPhRealtimeSection(idKolam),
                  const SizedBox(height: 16),
                  _buildTelemetrySection(idKolam),
                  const SizedBox(height: 16),
                  _buildManualFeedButton(idKolam),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String namaKolam) {
    return AppBar(
      backgroundColor: const Color(0xFF0D1520),
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF00C9A7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00C9A7), width: 1),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF00C9A7).withOpacity(0.08),
            ),
            child: const Icon(Icons.water, color: Color(0xFF00C9A7), size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFE0F7FA), Color(0xFF00C9A7)],
                ).createShader(bounds),
                child: const Text(
                  'V.I.S.I.O.N',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                namaKolam.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF4A6070),
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1C2E3E)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF4A6070),
                size: 18,
              ),
            ),
            onPressed: _handleLogout,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeader(bool isOnline) {
    final color = isOnline ? const Color(0xFF00C9A7) : const Color(0xFFE63946);
    final statusLabel = isOnline
        ? 'SISTEM KONTROL AKTIF & TERHUBUNG'
        : 'KONEKSI SENSOR TERPUTUS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          // Pulsing dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3 + (_pulseAnimation.value * 0.7)),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(_pulseAnimation.value * 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            statusLabel,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                'LIVE',
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhRealtimeSection(int idKolam) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dashboardService.streamRiwayatPh(idKolam),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('METRIK pH REAL-TIME');
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildCardWrapper(
            title: 'METRIK pH REAL-TIME',
            icon: Icons.science_outlined,
            child: const _EmptyDataWidget(
              message: 'Belum ada data hidrologi masuk.',
            ),
          );
        }

        final data = snapshot.data!;
        final latestPh = data.first['ph_level'] as num;

        Color phColor = const Color(0xFF00C9A7);
        String statusText = 'OPTIMAL';
        String statusDesc = 'Kadar pH dalam rentang ideal 6.5 – 8.5';
        if (latestPh < 6.5 || latestPh > 8.5) {
          phColor = const Color(0xFFE63946);
          statusText = 'PERINGATAN ANOMALI';
          statusDesc = 'Kadar pH di luar rentang ideal!';
        }

        return _buildClickableCardWrapper(
          title: 'METRIK pH REAL-TIME',
          icon: Icons.science_outlined,
          onTap: () => _bukaDetailPh(idKolam),
          child: Column(
            children: [
              // pH Value + Status Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Big pH number
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [phColor.withOpacity(0.8), phColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      latestPh.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: phColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: phColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: phColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusDesc,
                            style: const TextStyle(
                              color: Color(0xFF4A6070),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Chart
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: const Color(0xFF1C2E3E),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                (data.length - 1 - e.key).toDouble(),
                                (e.value['ph_level'] as num).toDouble(),
                              ),
                            )
                            .toList(),
                        isCurved: true,
                        color: phColor,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              phColor.withOpacity(0.18),
                              phColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Tap hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 12,
                    color: const Color(0xFF3A5A6A),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Ketuk untuk melihat histori analitik',
                    style: TextStyle(
                      color: Color(0xFF3A5A6A),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTelemetrySection(int idKolam) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _dashboardService.getSesiPakanTerakhir(idKolam),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard('TELEMETRI FEEDER & AI');
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildCardWrapper(
            title: 'TELEMETRI FEEDER & AI',
            icon: Icons.router_outlined,
            child: const _EmptyDataWidget(message: 'Belum ada log sesi pakan.'),
          );
        }

        final session = snapshot.data!;
        final List telemetri = session['telemetri_feeder'] ?? [];
        final List visualAi = session['log_visual_ai'] ?? [];
        final sisaPakan = telemetri.isNotEmpty
            ? telemetri.first['sisa_pakan_persen']
            : '--';
        final statusIkan = visualAi.isNotEmpty
            ? visualAi.first['status_ikan']
            : 'Tidak ada data kamera';
        final waktuFormatted = DateFormat(
          'dd MMM yyyy, HH:mm',
        ).format(DateTime.parse(session['waktu_mulai']).toLocal());

        // Tentukan warna sisa pakan
        double? sisaPakanNum;
        if (sisaPakan != '--') {
          sisaPakanNum = (sisaPakan as num).toDouble();
        }
        final pakanColor = sisaPakanNum != null && sisaPakanNum < 20
            ? const Color(0xFFE63946)
            : const Color(0xFF00C9A7);

        return _buildClickableCardWrapper(
          title: 'TELEMETRI FEEDER & AI',
          icon: Icons.router_outlined,
          onTap: () => _bukaDetailTelemetri(idKolam),
          child: Column(
            children: [
              _buildTelemetryRow(
                icon: Icons.access_time_rounded,
                label: 'Sesi Terakhir',
                value: waktuFormatted,
              ),
              _buildDivider(),
              _buildTelemetryRow(
                icon: Icons.inventory_2_outlined,
                label: 'Sisa Pakan Dispenser',
                value: '$sisaPakan%',
                valueColor: pakanColor,
              ),
              _buildDivider(),
              _buildTelemetryRow(
                icon: Icons.camera_alt_outlined,
                label: 'Analisis Visual AI',
                value: statusIkan.toString().toUpperCase(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 12,
                    color: const Color(0xFF3A5A6A),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Ketuk untuk melihat log kamera AI',
                    style: TextStyle(
                      color: Color(0xFF3A5A6A),
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 1,
      color: const Color(0xFF1C2E3E),
    );
  }

  Widget _buildTelemetryRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0A1118),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1C2E3E)),
          ),
          child: Icon(icon, color: const Color(0xFF3A5A6A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF7B8FA6), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Card Wrappers ---

  Widget _buildLoadingCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2E3E)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildCardHeader(title: title, icon: Icons.hourglass_empty_rounded),
          const SizedBox(height: 24),
          const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              color: Color(0xFF00C9A7),
              strokeWidth: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C2E3E)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(title: title, icon: icon),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildClickableCardWrapper({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFF00C9A7).withOpacity(0.08),
        highlightColor: const Color(0xFF00C9A7).withOpacity(0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1520),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1C2E3E)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCardHeader(title: title, icon: icon),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1118),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1C2E3E)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF3A5A6A),
                      size: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF00C9A7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00C9A7),
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // --- Manual Feed Button ---
  Widget _buildManualFeedButton(int idKolam) {
    return GestureDetector(
      onTap: _isFeedingManual ? null : () => _eksekusiPakanManual(idKolam),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: _isFeedingManual
                ? [const Color(0xFF1C2E3E), const Color(0xFF1C2E3E)]
                : [const Color(0xFFE63946), const Color(0xFFD62828)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: _isFeedingManual
                ? const Color(0xFF2A3E4E)
                : const Color(0xFFE63946).withOpacity(0.5),
            width: 1,
          ),
          boxShadow: _isFeedingManual
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFE63946).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isFeedingManual
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A6070),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'MENGIRIM KOMANDO...',
                      style: TextStyle(
                        color: Color(0xFF4A6070),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.power_settings_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'BERI PAKAN MANUAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _EmptyDataWidget extends StatelessWidget {
  final String message;
  const _EmptyDataWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF2A3E4E), size: 18),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF3A5A6A), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Grid background painter — sama seperti LoginScreen
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C9A7).withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
