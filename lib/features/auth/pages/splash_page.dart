import 'package:online_ezzy/core/localization/app_translations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:get_storage/get_storage.dart';

import 'onboarding_page.dart';
import '../../dashboard/pages/shell_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _navigationTimer = Timer(const Duration(milliseconds: 2300), () async {
      if (!mounted) {
        return;
      }

      final box = GetStorage();
      final hasToken = box.read<String>('auth_token') != null;
      final hasSeenOnboarding = box.read<bool>('onboarding_completed') ?? false;

      if (!mounted) return;

      // تحديد الصفحة المناسبة
      Widget nextPage;
      if (hasToken) {
        // مستخدم مسجل دخول
        nextPage = const ShellPage();
      } else if (hasSeenOnboarding) {
        // شاهد الـ Onboarding من قبل، يذهب للصفحة الرئيسية كضيف
        nextPage = const ShellPage();
      } else {
        // أول مرة، يعرض الـ Onboarding
        nextPage = const OnboardingPage();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) => nextPage,
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFE61F2D);
    // const deepRed = Color(0xFFB80F20);
    const charcoal = Color(0xFF191C22);
    const softSurface = Color(0xFFF6F7F9);

    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = math.min(screenWidth * 0.8, 360.0);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [softSurface, Colors.white],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: logoWidth,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: brandRed.withValues(alpha: 0.25),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x2619171C),
                            blurRadius: 28,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 8,
                        child: Image.asset(
                          'assets/images/splash.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 28),
                Text(
                  'أونلاين إيزي'.tr,
                  style: textTheme.headlineSmall?.copyWith(
                    color: charcoal,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'توصيل أسرع. إدارة أذكى.'.tr,
                  style: textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF545B66),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 34),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 7,
                      child: LinearProgressIndicator(
                        value: _controller.value,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          brandRed,
                        ),
                        backgroundColor: const Color(0xFFDCE0E6),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'راحه في الإرسال، سهولة في الاستلام'.tr,
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6F7783),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
