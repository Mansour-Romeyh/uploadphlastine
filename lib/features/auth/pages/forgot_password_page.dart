import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

import 'auth_layout.dart';
import 'otp_verification_page.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE71D24);

    return AuthLayout(
      headerTitle: 'استعادة الحساب'.tr,
      showBackButton: true,
      title: 'استعادة كلمة المرور'.tr,
      subtitle: 'ادخل بريدك الإلكتروني أو رقم الهاتف لإرسال رمز التحقق.'.tr,
      centered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'البريد الإلكتروني / رقم الهاتف'.tr,
            hint: 'ادخل البريد الإلكتروني أو رقم الهاتف'.tr,
          ),
          SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OtpVerificationPage(),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text('إرسال رمز التحقق'.tr),
          ),
        ],
      ),
    );
  }
}
