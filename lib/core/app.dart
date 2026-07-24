import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_storage/get_storage.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';

import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/services/api_service.dart';
import 'package:online_ezzy/core/theme/app_theme.dart';
import 'package:online_ezzy/features/auth/controllers/auth_provider.dart';
import 'package:online_ezzy/features/auth/pages/login_page.dart';
import 'package:online_ezzy/features/auth/pages/splash_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class OnlineEzzyApp extends StatefulWidget {
  const OnlineEzzyApp({super.key});

  @override
  State<OnlineEzzyApp> createState() => _OnlineEzzyAppState();
}

class _OnlineEzzyAppState extends State<OnlineEzzyApp> {
  @override
  void initState() {
    super.initState();
    ApiService.onUnauthorized = _handleUnauthorizedSession;
  }

  @override
  void dispose() {
    ApiService.onUnauthorized = null;
    super.dispose();
  }

  Future<void> _handleUnauthorizedSession() async {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await Get.find<AuthProvider>().logout();
    } else {
      final box = GetStorage();
      await box.remove('auth_token');
      await box.remove('user_data');
    }

    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'انتهت صلاحية جلسة تسجيل الدخول. سجّل دخولك مجدداً لاستخدام التطبيق بالكامل.'
              .tr,
        ),
      ),
    );

    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'OnlineEzzy',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: AppTheme.light(),
      home: const SplashPage(),
    );
  }
}
