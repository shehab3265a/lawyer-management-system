import 'package:flutter/material.dart';

import '../../data/data_repository.dart';
import '../../data/local_cache.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/offline_banner.dart';
import '../appointments/appointments_screen.dart';
import '../cases/cases_screen.dart';
import '../clients/clients_screen.dart';
import '../login/login_screen.dart';
import '../settings/settings_screen.dart';

/// الإطار الرئيسي للتطبيق: شريط تنقل سفلي + 5 تبويبات.
/// (الاسم والـ constructor زي ما كانوا عشان login و register و main مايتغيروش)
class DashboardScreen extends StatefulWidget {
  final String fullName;
  final String email;
  final int lawyerId;

  const DashboardScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.lawyerId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  // كل تبويب بيتبني من جديد عند فتحه، فالبيانات بتتحدث دايمًا
  Widget _buildPage() {
    switch (_index) {
      case 1:
        return const ClientsScreen();
      case 2:
        return CasesScreen(lawyerId: widget.lawyerId);
      case 3:
        return const AppointmentsScreen();
      case 4:
        return _MoreTab(fullName: widget.fullName, email: widget.email);
      default:
        return _HomeTab(
          fullName: widget.fullName,
          email: widget.email,
          onOpenTab: _goTo,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        // زر الرجوع في الأندرويد: من أي تبويب يرجّع للرئيسية بدل ما يقفل التطبيق
        canPop: _index == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _goTo(0);
        },
        child: Scaffold(
          body: _buildPage(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _goTo,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'الرئيسية',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'العملاء',
              ),
              NavigationDestination(
                icon: Icon(Icons.gavel_outlined),
                selectedIcon: Icon(Icons.gavel),
                label: 'القضايا',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'المواعيد',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu),
                selectedIcon: Icon(Icons.menu),
                label: 'المزيد',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الرئيسية
// ---------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  final String fullName;
  final String email;
  final ValueChanged<int> onOpenTab;

  const _HomeTab({
    required this.fullName,
    required this.email,
    required this.onOpenTab,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _isLoading = true;
  bool _fromCache = false;
  DateTime? _cacheTime;
  String? _error;

  int _clientsCount = 0;
  int _activeCasesCount = 0;
  int _upcomingCount = 0;

  List<Map<String, dynamic>> _upcomingAppointments = [];
  List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        DataRepository.getList('clients'),
        DataRepository.getList('cases'),
        DataRepository.getList('appointments'),
      ]);

      final clients = results[0].items;
      final cases = results[1].items;
      final appointments = results[2].items;

      final fromCache = results.any((result) => result.fromCache);
      DateTime? cacheTime;
      for (final result in results) {
        cacheTime = DataRepository.oldest(cacheTime, result.savedAt);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayText =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // القضايا الجارية = أي قضية حالتها مش CLOSED
      final activeCases = cases
          .where((c) => c['status']?.toString().toUpperCase() != 'CLOSED')
          .toList();

      // المواعيد القادمة = SCHEDULED وتاريخها اليوم أو بعده
      final upcoming = appointments.where((a) {
        final status = a['status']?.toString().toUpperCase();
        final date = a['appointmentDate']?.toString() ?? '';
        return status == 'SCHEDULED' && date.compareTo(todayText) >= 0;
      }).toList();

      upcoming.sort((a, b) {
        final first =
            '${a['appointmentDate'] ?? ''} ${a['appointmentTime'] ?? ''}';
        final second =
            '${b['appointmentDate'] ?? ''} ${b['appointmentTime'] ?? ''}';
        return first.compareTo(second);
      });

      // ربط كل موعد ببيانات القضية الكاملة (فيها اسم العميل)
      final casesById = {
        for (final c in cases) (c['id'] as num).toInt(): c,
      };

      final upcomingWithCase = upcoming.map((a) {
        final legalCase = a['legalCase'];
        final caseId =
            legalCase is Map ? (legalCase['id'] as num?)?.toInt() : null;

        return {
          ...a,
          'fullCase': caseId != null ? casesById[caseId] : null,
        };
      }).toList();

      // تذكيرات: قضايا جارية جلستها القادمة خلال 14 يوم
      final reminders = <Map<String, dynamic>>[];
      for (final c in activeCases) {
        final date = DateTime.tryParse(c['nextHearingDate']?.toString() ?? '');
        if (date == null) continue;

        final days =
            DateTime(date.year, date.month, date.day).difference(today).inDays;

        if (days < 0 || days > 14) continue;

        reminders.add({...c, '_days': days});
      }
      reminders.sort(
        (a, b) => (a['_days'] as int).compareTo(b['_days'] as int),
      );

      if (!mounted) return;

      setState(() {
        _fromCache = fromCache;
        _cacheTime = cacheTime;
        _clientsCount = clients.length;
        _activeCasesCount = activeCases.length;
        _upcomingCount = upcoming.length;
        _upcomingAppointments = upcomingWithCase.take(3).toList();
        _reminders = reminders.take(3).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'تعذر تحميل البيانات. تأكد من تشغيل الـ Backend.';
      });
    }
  }

  String _statValue(int value) {
    if (_isLoading) return '...';
    if (_error != null) return '—';
    return value.toString();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final parts = value.toString().split('T').first.split('-');
    if (parts.length != 3) return value.toString();
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  String _formatTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return '';
    final parts = value.toString().split(':');
    if (parts.length < 2) return value.toString();

    final hour24 = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour24 == null || minute == null) return value.toString();

    final period = hour24 >= 12 ? 'مساءً' : 'صباحًا';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '${hour12.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} $period';
  }

  String _daysText(int days) {
    if (days == 0) return 'اليوم';
    if (days == 1) return 'غدًا';
    if (days == 2) return 'بعد يومين';
    if (days <= 10) return 'بعد $days أيام';
    return 'بعد $days يومًا';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(context),
            const SizedBox(height: 52),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_fromCache) OfflineBanner(savedAt: _cacheTime),
                  if (_error != null) _buildErrorBanner(),
                  _sectionHeader(
                    'المواعيد القادمة',
                    onViewAll: () => widget.onOpenTab(3),
                  ),
                  const SizedBox(height: 10),
                  _buildUpcomingSection(),
                  const SizedBox(height: 24),
                  _sectionHeader(
                    'تذكيرات مهمة',
                    onViewAll: () => widget.onOpenTab(2),
                  ),
                  const SizedBox(height: 10),
                  _buildRemindersSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 76),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(
            children: [
              _Avatar(name: widget.fullName, radius: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مرحبًا بك',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: -36,
          child: _buildStatsCard(),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    Widget divider() =>
        Container(width: 1, height: 46, color: AppColors.border);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.gavel_outlined,
              value: _statValue(_activeCasesCount),
              label: 'قضايا جارية',
            ),
          ),
          divider(),
          Expanded(
            child: _StatItem(
              icon: Icons.people_outline,
              value: _statValue(_clientsCount),
              label: 'عملاء',
            ),
          ),
          divider(),
          Expanded(
            child: _StatItem(
              icon: Icons.event_available_outlined,
              value: _statValue(_upcomingCount),
              label: 'مواعيد قادمة',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onViewAll}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        TextButton(
          onPressed: onViewAll,
          style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          child: const Text(
            'عرض الكل',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!)),
          TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(color: AppColors.textMuted)),
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildUpcomingSection() {
    if (_isLoading) return _loadingCard();
    if (_upcomingAppointments.isEmpty) {
      return _emptyCard('لا توجد مواعيد قادمة');
    }

    return Column(
      children: _upcomingAppointments.map(_appointmentTile).toList(),
    );
  }

  Widget _buildRemindersSection() {
    if (_isLoading) return _loadingCard();
    if (_reminders.isEmpty) {
      return _emptyCard('لا توجد جلسات قضايا خلال الأسبوعين القادمين');
    }

    return Column(children: _reminders.map(_reminderTile).toList());
  }

  Widget _appointmentTile(Map<String, dynamic> appointment) {
    final fullCase = appointment['fullCase'];
    final client = fullCase is Map ? fullCase['client'] : null;
    final clientName =
        client is Map ? (client['fullName'] ?? '').toString() : '';
    final location = (appointment['location'] ?? '').toString();
    final time = _formatTime(appointment['appointmentTime']);

    final when = [
      _formatDate(appointment['appointmentDate']),
      if (time.isNotEmpty) time,
    ].join(' - ');

    final details = [
      if (clientName.isNotEmpty) clientName,
      if (location.isNotEmpty) location,
    ].join(' • ');

    return _InfoTile(
      icon: Icons.event_note_outlined,
      title: (appointment['description'] ?? '').toString(),
      line1: when,
      line2: details,
      onTap: () => widget.onOpenTab(3),
    );
  }

  Widget _reminderTile(Map<String, dynamic> legalCase) {
    final client = legalCase['client'];
    final clientName =
        client is Map ? (client['fullName'] ?? '').toString() : '';
    final court = (legalCase['courtName'] ?? '').toString();
    final number = (legalCase['caseNumber'] ?? '').toString();
    final title = (legalCase['title'] ?? '').toString();

    final details = [
      if (clientName.isNotEmpty) clientName,
      if (court.isNotEmpty) court,
    ].join(' • ');

    return _InfoTile(
      icon: Icons.notifications_active_outlined,
      title: number.isEmpty ? 'جلسة: $title' : 'جلسة قضية $number',
      line1:
          '${_daysText(legalCase['_days'] as int)} • ${_formatDate(legalCase['nextHearingDate'])}',
      line2: details,
      onTap: () => widget.onOpenTab(2),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String line1;
  final String line2;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (line1.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          line1,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      if (line2.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          line2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double radius;

  const _Avatar({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '؟' : String.fromCharCode(trimmed.runes.first);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white24,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.accent,
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.95,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// المزيد (الملف الشخصي والإعدادات وتسجيل الخروج)
// ---------------------------------------------------------------------------

class _MoreTab extends StatelessWidget {
  final String fullName;
  final String email;

  const _MoreTab({required this.fullName, required this.email});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من التطبيق؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // تسجيل الخروج بيمسح "تذكرني"
    await SessionService.clear();
    await LocalCache.clear();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إدارة مكتب المحاماة'),
          content: const Text('الإصدار 1.0.0'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, topPadding + 28, 20, 28),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              children: [
                _Avatar(name: fullName, radius: 38),
                const SizedBox(height: 12),
                Text(
                  fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('الإعدادات'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            fullName: fullName,
                            email: email,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                    ),
                    title: const Text('حول التطبيق'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => _showAbout(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: AppColors.danger,
                    ),
                    title: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}