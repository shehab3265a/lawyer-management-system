import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// شريط بيظهر لما التطبيق يعرض بيانات محفوظة بدل بيانات السيرفر.
class OfflineBanner extends StatelessWidget {
  final DateTime? savedAt;

  const OfflineBanner({super.key, this.savedAt});

  String _when() {
    final date = savedAt;
    if (date == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');

    return ' (آخر تحديث ${two(date.day)}/${two(date.month)} '
        '${two(date.hour)}:${two(date.minute)})';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'غير متصل بالخادم. تعرض آخر بيانات محفوظة${_when()}. '
              'الإضافة والتعديل والحذف تحتاج اتصالًا.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}