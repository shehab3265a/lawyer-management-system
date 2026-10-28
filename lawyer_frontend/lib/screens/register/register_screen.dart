import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../dashboard/dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String _baseUrl = 'http://localhost:8080/api';
  static const Color _primaryColor = Color(0xFF173B57);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _officeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _officeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _validationMessage(dynamic data) {
    if (data is Map) {
      if (data.containsKey('fullName')) return 'الاسم الكامل مطلوب';
      if (data.containsKey('username')) {
        return 'اسم المستخدم غير صالح (8 أحرف على الأقل: إنجليزي وأرقام و @ _ -)';
      }
      if (data.containsKey('phone')) return 'رقم الهاتف مطلوب';
      if (data.containsKey('email')) return 'البريد الإلكتروني غير صالح';
      if (data.containsKey('password')) {
        return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
      }
    }

    return 'بيانات غير صالحة، راجع الحقول وحاول مرة أخرى';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final phone = _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
    final office = _officeController.text.trim();

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/lawyers'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': _fullNameController.text.trim(),
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              'phone': phone,
              'officeName': office.isEmpty ? null : office,
            }),
          )
          .timeout(const Duration(seconds: 15));

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = null;
      }

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        // الحساب اتعمل: ندخل على الداشبورد مباشرة
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              fullName: data['fullName'].toString(),
              email: data['email'].toString(),
              lawyerId: (data['id'] as num).toInt(),
            ),
          ),
          (route) => false,
        );
      } else if (response.statusCode == 409) {
        final message = data is Map ? (data['message'] ?? '').toString() : '';

        if (message.contains('Username')) {
          _showError('اسم المستخدم مستخدم بالفعل، اختر اسمًا آخر');
        } else {
          _showError('هذا البريد الإلكتروني مسجل بالفعل');
        }
      } else if (response.statusCode == 400) {
        _showError(_validationMessage(data));
      } else {
        _showError('فشل إنشاء الحساب (${response.statusCode})');
      }
    } catch (_) {
      _showError('تعذر الاتصال بالخادم. تأكد من تشغيل الـ Backend.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: const Text('إنشاء حساب جديد'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.balance,
                            size: 56,
                            color: _primaryColor,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'أنشئ حسابك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الكامل',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'أدخل الاسم الكامل';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            textDirection: TextDirection.ltr,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              helperText:
                                  'إنجليزي، 8 أحرف على الأقل (حروف وأرقام و @ _ -)',
                              helperMaxLines: 2,
                              prefixIcon: Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';

                              if (text.isEmpty) {
                                return 'أدخل اسم المستخدم';
                              }
                              if (text.length < 8) {
                                return 'اسم المستخدم 8 أحرف على الأقل';
                              }
                              if (text.length > 50) {
                                return 'اسم المستخدم طويل جدًا';
                              }
                              if (!RegExp(r'^[A-Za-z0-9@_-]+$').hasMatch(text)) {
                                return 'استخدم حروفًا إنجليزية وأرقامًا والرموز @ _ - فقط';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textDirection: TextDirection.ltr,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'أدخل البريد الإلكتروني';
                              }

                              final emailPattern = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );

                              if (!emailPattern.hasMatch(value.trim())) {
                                return 'أدخل بريدًا إلكترونيًا صحيحًا';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final text = (value ?? '').replaceAll(
                                RegExp(r'[\s-]'),
                                '',
                              );

                              if (text.isEmpty) {
                                return 'أدخل رقم الهاتف';
                              }
                              if (!RegExp(r'^\+?\d{8,15}$').hasMatch(text)) {
                                return 'أدخل رقم هاتف صحيح';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _officeController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المكتب (اختياري)',
                              prefixIcon: Icon(Icons.business_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textDirection: TextDirection.ltr,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              helperText: '8 أحرف على الأقل',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'أدخل كلمة المرور';
                              }
                              if (value.length < 8) {
                                return 'كلمة المرور يجب ألا تقل عن 8 أحرف';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            textDirection: TextDirection.ltr,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _register();
                            },
                            decoration: InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'أعد إدخال كلمة المرور';
                              }
                              if (value != _passwordController.text) {
                                return 'كلمتا المرور غير متطابقتين';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _register,
                              style: FilledButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'إنشاء الحساب',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'لديك حساب بالفعل؟',
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFB8860B),
                                ),
                                child: const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}