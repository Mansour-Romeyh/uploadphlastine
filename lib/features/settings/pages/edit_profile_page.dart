import 'package:flutter/material.dart';
import 'package:online_ezzy/core/localization/app_translations.dart';
import 'package:online_ezzy/core/localization/get_x_import.dart';
import 'package:online_ezzy/features/auth/controllers/auth_provider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Get.find<AuthProvider>();
      _prefillControllers(auth);
    });
  }

  void _prefillControllers(AuthProvider auth) {
    final user = auth.userData;
    if (user == null) return;

    final resolvedName = _normalizeName(auth.displayName, auth.isAuthenticated);
    final resolvedEmail = _normalizeEmail(auth.primaryEmail);
    final resolvedPhone = _extractPhone(user);

    if (_fullNameController.text.trim().isEmpty && resolvedName.isNotEmpty) {
      _fullNameController.text = resolvedName;
    }
    if (_emailController.text.trim().isEmpty && resolvedEmail.isNotEmpty) {
      _emailController.text = resolvedEmail;
    }
    if (_phoneController.text.trim().isEmpty && resolvedPhone.isNotEmpty) {
      _phoneController.text = resolvedPhone;
    }

    _didPrefill = true;
  }

  String _normalizeName(String value, bool isAuthenticated) {
    final text = value.trim();
    if (text.isEmpty) return '';
    if (text == 'مستخدم') return '';
    if (!isAuthenticated && text == 'ضيف') return '';
    return text;
  }

  String _normalizeEmail(String value) {
    final text = value.trim();
    if (text.isEmpty || text == 'غير متوفر') return '';
    return text;
  }

  String _extractPhone(Map<String, dynamic> user) {
    final directPhone = user['phone']?.toString().trim() ?? '';
    if (directPhone.isNotEmpty && directPhone.toLowerCase() != 'null') {
      return directPhone;
    }

    final billing = user['billing'];
    if (billing is Map) {
      final billingPhone = billing['phone']?.toString().trim() ?? '';
      if (billingPhone.isNotEmpty && billingPhone.toLowerCase() != 'null') {
        return billingPhone;
      }
    }

    return '';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final auth = Get.find<AuthProvider>();
    final userId = AuthProvider.extractUserId(auth.userData);

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد رقم المستخدم، أعد تسجيل الدخول'),
        ),
      );
      return;
    }

    final nameParts = _fullNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    final data = {
      'first_name': firstName,
      'last_name': lastName,
      'email': _emailController.text.trim(),
      'billing': {
        'first_name': firstName,
        'last_name': lastName,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      },
    };

    final success = await auth.updateCustomerDetails(userId, data);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? 'حدث خطأ أثناء تحديث البيانات'),
          // ignore: avoid_print
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'تعديل البيانات',
            style: TextStyle(
              color: Color(0xFF2C3E50),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: GetBuilder<AuthProvider>(
          builder: (auth) {
            if (!_didPrefill && auth.userData != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _prefillControllers(auth);
              });
            }

            if (auth.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            auth.userData != null &&
                                auth.userData!['avatar_url'] != null
                            ? NetworkImage(auth.userData!['avatar_url'])
                            : null,
                        child:
                            auth.userData == null ||
                                auth.userData!['avatar_url'] == null
                            ? const Icon(
                                Icons.person,
                                size: 55,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.red,
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _buildTextField('الاسم الكامل', _fullNameController),
                const SizedBox(height: 16),
                _buildTextField(
                  'البريد الإلكتروني',
                  _emailController,
                  TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'رقم الهاتف'.tr,
                  _phoneController,
                  TextInputType.phone,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'حفظ التعديلات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, [
    TextInputType? keyboardType,
  ]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
