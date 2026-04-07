import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'ph_history_screen.dart';
import 'feeding_history_screen.dart';
import 'jadwal_screen.dart';

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

  // ── Feed Button State ──────────────────────────────────────────────────────
  bool _isSendingCommand = false;
  bool _isWaitingForSatiated = false;
  Timer? _satiatedPollingTimer;

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
    _satiatedPollingTimer?.cancel();
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

        if (info != null) {
          _checkCurrentSatiatedStatus(info['id_kolam'] as int);
        }
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

  Future<void> _checkCurrentSatiatedStatus(int idKolam) async {
    try {
      final session = await _dashboardService.getSesiPakanTerakhir(idKolam);
      if (session == null) return;

      final List visualAi = session['log_visual_ai'] ?? [];
      final statusIkan = visualAi.isNotEmpty
          ? (visualAi.first['status_ikan'] as String? ?? '').toLowerCase()
          : '';

      if (statusIkan == 'ikan kenyang') {
        _onIkanKenyang();
      }
    } catch (_) {}
  }

  void _onIkanKenyang() {
    _satiatedPollingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isWaitingForSatiated = false;
        _isSendingCommand = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Ikan sudah kenyang — tombol pakan aktif kembali.',
            style: TextStyle(color: Color(0xFF0D3D33)),
          ),
          backgroundColor: const Color(0xFFD0F5EE),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      );
    }
  }

  void _startSatiatedPolling(int idKolam) {
    _satiatedPollingTimer?.cancel();
    _satiatedPollingTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkCurrentSatiatedStatus(idKolam),
    );
  }

  void _handleLogout() async {
    _satiatedPollingTimer?.cancel();
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _eksekusiPakanManual(int idKolam) async {
    if (_isSendingCommand || _isWaitingForSatiated) return;

    setState(() => _isSendingCommand = true);

    try {
      await _dashboardService.triggerPakanManual();

      if (!mounted) return;

      setState(() {
        _isSendingCommand = false;
        _isWaitingForSatiated = true;
      });

      _startSatiatedPolling(idKolam);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Komando terkirim! Menunggu ikan kenyang...',
            style: TextStyle(color: Color(0xFF0D3D33)),
          ),
          backgroundColor: const Color(0xFFD0F5EE),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingCommand = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim komando: $e'),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  bool _checkSistemOnline(String waktuRekamTerakhir) {
    final lastUpdate = DateTime.parse(waktuRekamTerakhir).toLocal();
    return DateTime.now().difference(lastUpdate).inMinutes <= 30;
  }

  void _bukaDetailPh(int idKolam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhHistoryScreen(idKolam: idKolam),
      ),
    );
  }

  void _bukaDetailTelemetri(int idKolam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedingHistoryScreen(idKolam: idKolam),
      ),
    );
  }

  void _bukaJadwalPakan() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const JadwalScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  // ── Derived button state ───────────────────────────────────────────────────
  bool get _isButtonDisabled => _isSendingCommand || _isWaitingForSatiated;

  String get _buttonLabel {
    if (_isSendingCommand) return 'MENGIRIM KOMANDO...';
    if (_isWaitingForSatiated) return 'MENUNGGU IKAN KENYANG...';
    return 'BERI PAKAN MANUAL';
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF0F4F3),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF009E83),
                strokeWidth: 2,
              ),
              SizedBox(height: 20),
              Text(
                'MENGINISIALISASI SISTEM...',
                style: TextStyle(
                  color: Color(0xFF4A7A72),
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F3),
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
                    color: const Color(0xFFE63946).withOpacity(0.07),
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
                    color: Color(0xFF2E4F48),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_kolamInfo == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F3),
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
                    color: Color(0xFFBDD8D3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'TIDAK ADA DATA EMPANG',
                    style: TextStyle(
                      color: Color(0xFF009E83),
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
                      color: Color(0xFF2E4F48),
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
      backgroundColor: const Color(0xFFF0F4F3),
      appBar: _buildAppBar(namaKolam),
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  // ── Feed Action Group ──────────────────────────────────
                  _buildFeedActionGroup(idKolam),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // APP BAR
  // =========================================================================
  PreferredSizeWidget _buildAppBar(String namaKolam) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF009E83),
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
              border: Border.all(color: const Color(0xFF009E83), width: 1),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF009E83).withOpacity(0.10),
            ),
            child: const Icon(Icons.water, color: Color(0xFF009E83), size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF006B58), Color(0xFF009E83)],
                ).createShader(bounds),
                child: const Text(
                  'V.I.S.I.O.N',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                namaKolam.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF4A7A72),
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
                border: Border.all(color: const Color(0xFFD5E5E2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF4A7A72),
                size: 18,
              ),
            ),
            onPressed: _handleLogout,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // STATUS HEADER
  // =========================================================================
  Widget _buildStatusHeader(bool isOnline) {
    final color = isOnline ? const Color(0xFF009E83) : const Color(0xFFE63946);
    final statusLabel = isOnline
        ? 'SISTEM KONTROL AKTIF & TERHUBUNG'
        : 'KONEKSI SENSOR TERPUTUS';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color.withOpacity(0.3 + (_pulseAnimation.value * 0.7)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(_pulseAnimation.value * 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
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
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withOpacity(0.35)),
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

  // =========================================================================
  // pH SECTION
  // =========================================================================
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

        Color phColor = const Color(0xFF009E83);
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [phColor.withOpacity(0.75), phColor],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Text(
                      latestPh.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
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
                                color: phColor.withOpacity(0.35),
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
                              color: Color(0xFF2E4F48),
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
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: const Color(0xFFD5E5E2),
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
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 12,
                    color: Color(0xFF4A7A72),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Ketuk untuk melihat histori analitik',
                    style: TextStyle(
                      color: Color(0xFF4A7A72),
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

  // =========================================================================
  // TELEMETRY SECTION
  // =========================================================================
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
        final List tele = session['telemetri_feeder'] ?? [];
        final List visAi = session['log_visual_ai'] ?? [];
        final sisaPakan = tele.isNotEmpty
            ? tele.first['sisa_pakan_persen']
            : '--';
        final statusIkan = visAi.isNotEmpty
            ? visAi.first['status_ikan']
            : 'Tidak ada data kamera';
        final waktuFormatted = DateFormat(
          'dd MMM yyyy, HH:mm',
        ).format(DateTime.parse(session['waktu_mulai']).toLocal());

        double? sisaPakanNum;
        if (sisaPakan != '--') sisaPakanNum = (sisaPakan as num).toDouble();
        final pakanColor = sisaPakanNum != null && sisaPakanNum < 20
            ? const Color(0xFFE63946)
            : const Color(0xFF009E83);

        final statusLower = (statusIkan as String).toLowerCase();
        if (_isWaitingForSatiated && statusLower == 'ikan kenyang') {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onIkanKenyang());
        }

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
                value: statusIkan.toUpperCase(),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 12,
                    color: Color(0xFF4A7A72),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Ketuk untuk melihat log kamera AI',
                    style: TextStyle(
                      color: Color(0xFF4A7A72),
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

  // =========================================================================
  // FEED ACTION GROUP — tombol manual + tombol jadwal
  // =========================================================================
  Widget _buildFeedActionGroup(int idKolam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Label section ──
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF009E83),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'KENDALI PAKAN',
                style: TextStyle(
                  color: Color(0xFF009E83),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // ── Tombol Pakan Manual ──
        _buildManualFeedButton(idKolam),
        const SizedBox(height: 10),

        // ── Tombol Atur Jadwal ──
        _buildJadwalButton(),
      ],
    );
  }

  // =========================================================================
  // MANUAL FEED BUTTON
  // =========================================================================
  Widget _buildManualFeedButton(int idKolam) {
    final isDisabled = _isButtonDisabled;

    return GestureDetector(
      onTap: isDisabled ? null : () => _eksekusiPakanManual(idKolam),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isDisabled
                ? [const Color(0xFFE8F2F0), const Color(0xFFE8F2F0)]
                : [const Color(0xFFE63946), const Color(0xFFD62828)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(
            color: isDisabled
                ? const Color(0xFFD5E5E2)
                : const Color(0xFFE63946).withOpacity(0.5),
          ),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFE63946).withOpacity(0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSendingCommand || _isWaitingForSatiated)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: _isWaitingForSatiated
                        ? const Color(0xFF009E83)
                        : const Color(0xFF4A7A72),
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _buttonLabel,
                  key: ValueKey(_buttonLabel),
                  style: TextStyle(
                    color: isDisabled
                        ? (_isWaitingForSatiated
                              ? const Color(0xFF009E83)
                              : const Color(0xFF2E4F48))
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // JADWAL BUTTON
  // =========================================================================
  Widget _buildJadwalButton() {
    return _JadwalButton(onTap: _bukaJadwalPakan);
  }

  // =========================================================================
  // HELPERS
  // =========================================================================
  Widget _buildDivider() => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    height: 1,
    color: const Color(0xFFD5E5E2),
  );

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
            color: const Color(0xFFF5FAF9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD5E5E2)),
          ),
          child: Icon(icon, color: const Color(0xFF4A7A72), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF2E4F48), fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF0D1F1B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E5E2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009E83).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
              color: Color(0xFF009E83),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E5E2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF009E83).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
        splashColor: const Color(0xFF009E83).withOpacity(0.07),
        highlightColor: const Color(0xFF009E83).withOpacity(0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD5E5E2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF009E83).withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                      color: const Color(0xFFF5FAF9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD5E5E2)),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF4A7A72),
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
            color: const Color(0xFF009E83),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF009E83),
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// JADWAL BUTTON — stateful untuk press scale + animasi arrow
// ============================================================================
class _JadwalButton extends StatefulWidget {
  final VoidCallback onTap;
  const _JadwalButton({required this.onTap});

  @override
  State<_JadwalButton> createState() => _JadwalButtonState();
}

class _JadwalButtonState extends State<_JadwalButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _arrowSlide = Tween<double>(
      begin: 0,
      end: 4,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _arrowSlide,
          builder: (_, child) => Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(
                  0xFF009E83,
                ).withOpacity(0.3 + _ctrl.value * 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF009E83).withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Ikon jadwal
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF009E83).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF009E83).withOpacity(0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFF009E83),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Teks
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ATUR JADWAL OTOMATIS',
                          style: TextStyle(
                            color: Color(0xFF009E83),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kelola waktu pemberian pakan terjadwal',
                          style: TextStyle(
                            color: Color(0xFF4A7A72),
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow animasi
                  Transform.translate(
                    offset: Offset(_arrowSlide.value, 0),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF009E83),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================
class _EmptyDataWidget extends StatelessWidget {
  final String message;
  const _EmptyDataWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF4A7A72), size: 18),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF2E4F48), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF009E83).withOpacity(0.05)
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
