import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final String fullName;
  final String email;

  const SettingsScreen({
    super.key,
    required this.fullName,
    required this.email,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primaryColor = Color(0xFF173B57);

  bool appointmentNotifications = true;
  bool caseNotifications = true;
  bool paymentNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          title: const Text('الإعدادات'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إعدادات الحساب والتطبيق',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: 'الملف الشخصي',
                    icon: Icons.person_outline,
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE7EEF3),
                          child: Icon(Icons.person, color: primaryColor),
                        ),
                        title: Text(
                          widget.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          widget.email,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'الإشعارات',
                    icon: Icons.notifications_outlined,
                    children: [
                      SwitchListTile(
                        value: appointmentNotifications,
                        activeThumbColor: primaryColor,
                        title: const Text('تذكيرات المواعيد'),
                        subtitle: const Text(
                          'التنبيه بمواعيد العملاء والجلسات',
                        ),
                        onChanged: (value) {
                          setState(() {
                            appointmentNotifications = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: caseNotifications,
                        activeThumbColor: primaryColor,
                        title: const Text('إشعارات القضايا'),
                        subtitle: const Text(
                          'التنبيه بالتحديثات المهمة للقضايا',
                        ),
                        onChanged: (value) {
                          setState(() {
                            caseNotifications = value;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: paymentNotifications,
                        activeThumbColor: primaryColor,
                        title: const Text('إشعارات المدفوعات'),
                        subtitle: const Text(
                          'التنبيه بمواعيد استحقاق المدفوعات',
                        ),
                        onChanged: (value) {
                          setState(() {
                            paymentNotifications = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'الأمان',
                    icon: Icons.security_outlined,
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.lock_outline,
                          color: primaryColor,
                        ),
                        title: const Text('تغيير كلمة المرور'),
                        trailing: const Icon(Icons.arrow_back_ios, size: 16),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'خاصية تغيير كلمة المرور لم يتم تنفيذها بعد',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'حول التطبيق',
                    icon: Icons.info_outline,
                    children: const [
                      ListTile(
                        leading: Icon(
                          Icons.gavel,
                          color: primaryColor,
                        ),
                        title: Text('إدارة مكتب المحاماة'),
                        subtitle: Text('الإصدار 1.0.0'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: primaryColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}