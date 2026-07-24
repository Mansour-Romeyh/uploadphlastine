import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:flutter/material.dart';

import 'auth_layout.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE71D24);

    return AuthLayout(
      headerTitle: 'كلمة مرور جديدة'.tr,
      showBackButton: true,
      title: 'تعيين كلمة مرور جديدة'.tr,
      subtitle: 'اختر كلمة مرور قوية لحماية حسابك.'.tr,
      centered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            label: 'كلمة المرور الجديدة'.tr,
            hint: '••••••••',
            obscureText: true,
          ),
          SizedBox(height: 12),
          AuthTextField(
            label: 'تأكيد كلمة المرور'.tr,
            hint: '••••••••',
            obscureText: true,
          ),
          SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم تحديث كلمة المرور بنجاح'.tr)),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const LoginPage()),
                (route) => false,
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
            child: Text('حفظ كلمة المرور'.tr),
          ),
        ],
      ),
    );
  }
}
