import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

import 'auth_layout.dart';
import 'reset_password_page.dart';

class OtpVerificationPage extends StatelessWidget {
  const OtpVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE71D24);

    return AuthLayout(
      headerTitle: 'تأكيد الهوية'.tr,
      showBackButton: true,
      title: 'تأكيد رمز التحقق'.tr,
      subtitle: 'ادخل الرمز المكوّن من 4 أرقام الذي تم إرساله إلى هاتفك.'.tr,
      centered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'رمز التحقق'.tr,
            hint: '____',
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: Text('إعادة إرسال الرمز'.tr),
            ),
          ),
          SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ResetPasswordPage(),
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
            child: Text('تأكيد'.tr),
          ),
        ],
      ),
    );
  }
}
