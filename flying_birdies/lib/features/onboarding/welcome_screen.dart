import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../widgets/glass_widgets.dart';
import '../auth/login_screen.dart'; // add at top

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnimatedGradientBackground(child: _WelcomeBody());
  }
}

class _WelcomeBody extends StatefulWidget {
  const _WelcomeBody();

  @override
  State<_WelcomeBody> createState() => _WelcomeBodyState();
}

class _WelcomeBodyState extends State<_WelcomeBody> with TickerProviderStateMixin {
  late final AnimationController _stagger =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
        ..forward();

  Interval _seg(double start, double end) =>
      Interval(start, end, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aLogo = CurvedAnimation(parent: _stagger, curve: _seg(.00, .20));
    final aTitle = CurvedAnimation(parent: _stagger, curve: _seg(.10, .35));
    final aTag = CurvedAnimation(parent: _stagger, curve: _seg(.20, .40));
    final aBody = CurvedAnimation(parent: _stagger, curve: _seg(.28, .50));
    final aC1 = CurvedAnimation(parent: _stagger, curve: _seg(.38, .62));
    final aC2 = CurvedAnimation(parent: _stagger, curve: _seg(.48, .72));
    final aC3 = CurvedAnimation(parent: _stagger, curve: _seg(.58, .82));

    Widget fadeSlide(Animation<double> a, {required Widget child, double dy = 18}) {
      return AnimatedBuilder(
        animation: a,
        child: child,
        builder: (_, c) => Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, (1 - a.value) * dy), child: c),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            // Logo
            fadeSlide(
              aLogo,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF9E5BFF), Color(0xFF59C9FF)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.monitor_heart, color: Colors.white, size: 34),
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB020),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.fitness_center, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            fadeSlide(
              aTitle,
              child: ShaderMask(
                shaderCallback: (r) =>
                    const LinearGradient(colors: AppTheme.titleGradient).createShader(r),
                child: const Text(
                  'StrikePro',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tagline
            fadeSlide(
              aTag,
              child: Text(
                'Transform Your Badminton Game',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFBBD2FF).withOpacity(.95),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Body copy
            fadeSlide(
              aBody,
              child: Text(
                'Connect your smart racket sensor and unlock elite-level training insights with real-time analytics and personalized coaching.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(.75),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 26),

            // HERO FEATURES (only these three)
            fadeSlide(
              aC1,
              child: const _BigFeature(
                gradient: AppTheme.gPink,
                icon: Icons.bolt_rounded,
                title: 'Real-Time Analytics',
                subtitle:
                    'Track swing speed, impact force, swing force, and acceleration live during training',
              ),
            ),
            const SizedBox(height: 16),
            fadeSlide(
              aC2,
              child: const _BigFeature(
                gradient: AppTheme.gBlue,
                icon: Icons.equalizer_rounded,
                title: 'Performance History',
                subtitle:
                    'Review your training calendar and track progress across all sessions',
              ),
            ),
            const SizedBox(height: 16),
            fadeSlide(
              aC3,
              child: const _BigFeature(
                gradient: AppTheme.gTeal,
                icon: Icons.security_rounded,
                title: 'Elite Training',
                subtitle:
                    'Train like a pro with biomechanics-focused performance metrics',
              ),
            ),
            const SizedBox(height: 22),

            // CTA
                      BounceTap(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(colors: AppTheme.gCTA),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.30),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Get Started',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Footer note
            Text(
              'No credit card required · Free forever',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(.60),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }
}

// ================= components =================

class _BigFeature extends StatelessWidget {
  const _BigFeature({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        border: Border.all(color: Colors.white.withOpacity(.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(.86),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
