import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isObscure = true;

  late AnimationController _fadeController;
  late AnimationController _scanController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scanAnimation = CurvedAnimation(
      parent: _scanController,
      curve: Curves.linear,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    String rawEmail = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (rawEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Email/Username dan password tidak boleh kosong!',
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    String finalEmail = rawEmail;
    if (!rawEmail.contains('@')) {
      finalEmail = '$rawEmail@gmail.com';
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.login(finalEmail, password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Otentikasi berhasil. Mengakses sistem...'),
          backgroundColor: const Color(0xFF00C9A7),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );

      // TODO: Navigator ke DashboardScreen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFE63946),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: Stack(
        children: [
          // --- Background: Grid Pattern ---
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // --- Background: Animated Scan Line ---
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, _) {
              final screenHeight = MediaQuery.of(context).size.height;
              return Positioned(
                top: _scanAnimation.value * screenHeight,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x3000C9A7),
                        Color(0x8800C9A7),
                        Color(0x3000C9A7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // --- Glow Orbs ---
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00C9A7).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0077B6).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // --- Main Content ---
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo & Title
                      _buildHeader(),
                      const SizedBox(height: 48),

                      // Form Card
                      _buildFormCard(),
                      const SizedBox(height: 16),

                      // Footer
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon Badge
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00C9A7), width: 1.5),
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF00C9A7).withOpacity(0.08),
          ),
          child: const Icon(Icons.water, color: Color(0xFF00C9A7), size: 36),
        ),
        const SizedBox(height: 20),

        // Title
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFF00C9A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'V.I.S.I.O.N',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 10,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle with decorative lines
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 1,
              color: const Color(0xFF00C9A7).withOpacity(0.4),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sistem Monitoring Empang Lele',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF7B8FA6),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 1,
              color: const Color(0xFF00C9A7).withOpacity(0.4),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C9A7).withOpacity(0.18),
          width: 1,
        ),
        color: const Color(0xFF0D1520),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C9A7).withOpacity(0.05),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card header label
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C9A7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'OTORISASI AKSES',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF00C9A7),
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Email/Username Field
          _buildTextField(
            controller: _emailController,
            label: 'Username atau Email',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Password Field
          _buildTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _isObscure,
            suffixIcon: IconButton(
              icon: Icon(
                _isObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF4A6070),
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isObscure = !_isObscure;
                });
              },
            ),
          ),
          const SizedBox(height: 28),

          // Submit Button
          _isLoading
              ? Container(
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00C9A7).withOpacity(0.3),
                    ),
                    color: const Color(0xFF00C9A7).withOpacity(0.05),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00C9A7),
                        ),
                      ),
                    ),
                  ),
                )
              : _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Color(0xFFD0E8F2),
        fontSize: 15,
        letterSpacing: 0.3,
      ),
      cursorColor: const Color(0xFF00C9A7),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF4A6070),
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF00C9A7),
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        filled: true,
        fillColor: const Color(0xFF0A1118),
        prefixIcon: Icon(icon, color: const Color(0xFF3A5A6A), size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1C2E3E), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF00C9A7), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _handleLogin,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF00A896), Color(0xFF00C9A7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00C9A7).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'OTORISASI AKSES',
            style: TextStyle(
              color: Color(0xFF080C14),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF00C9A7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'SISTEM AKTIF  •  v1.0.0',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF2E4A5A),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF00C9A7),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// Custom painter untuk grid background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C9A7).withOpacity(0.04)
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
