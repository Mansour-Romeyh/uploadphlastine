import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../dashboard/pages/shell_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  static const _slides = [
    _OnboardingSlide(
      title: 'خوفك من الجمارك نحن نحله!',
      subtitle:
          'ابدأ طلبك بثقة ودعنا نهتم بكل الإجراءات\nالمتعلقة بالجمارك نيابة عنك',
      imageUrl: 'assets/images/on1.png',
    ),
    _OnboardingSlide(
      title: 'تتبع شحناتك لحظة بلحظة',
      subtitle: 'تابع حالة طردك بسهولة من الاستلام\nحتى التسليم.',
      imageUrl: 'assets/images/on2.png',
    ),
    _OnboardingSlide(
      title: 'اختر الباقة المناسبة لك',
      subtitle: 'خطط مرنة لتوصيل الطرود\nتناسب احتياجاتك.',
      imageUrl: 'assets/images/on3.png',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goHome() async {
    // حفظ أن المستخدم شاهد الـ Onboarding
    await GetStorage().write('onboarding_completed', true);

    if (!mounted) return;

    // الذهاب مباشرة إلى الصفحة الرئيسية كضيف
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ShellPage()),
    );
  }

  void _onPrimaryAction() {
    if (_currentIndex == _slides.length - 1) {
      _goHome();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE71D24);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Align(
                // We want it on the physical left, which is centerLeft.
                // Wait, looking closely at the image again:
                // The notch is in the middle. The time is left. The battery is right.
                // Below the battery (so on the right) is the text "تخطي".
                // In RTL, AlignmentDirectional.centerStart is physical Right.
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _goHome,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(
                      0xFF2E3440,
                    ), // Dark color as in screenshot
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    side: BorderSide(
                      color: const Color(0xFF2E3440).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'تخطي',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final item = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF15171C),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Expanded(
                          child: Image.asset(
                            item.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6C727F),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Section (Button + Dots)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _onPrimaryAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            12,
                          ), // Matching the slightly rounded corners in screenshot
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentIndex == _slides.length - 1
                            ? 'ابدأ الآن'
                            : 'التالي',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (index) {
                      // The screenshots show dots where:
                      // active dot is red and slightly larger, inactive ones are small and grey.
                      final isActive = _currentIndex == index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: isActive ? 6.0 : 6.0,
                        height: isActive ? 6.0 : 6.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? red : const Color(0xFFD9D9D9),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String imageUrl;
}
