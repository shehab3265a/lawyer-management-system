import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../login/login_screen.dart';
import '../settings/settings_screen.dart';
import '../clients/clients_screen.dart';
import '../cases/cases_screen.dart';
import '../appointments/appointments_screen.dart';

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
  static const String _baseUrl = 'http://localhost:8080/api';
  static const Color _primaryColor = Color(0xFF173B57);

  bool _isLoading = true;
  String? _error;

  int _clientsCount = 0;
  int _casesCount = 0;
  int _activeCasesCount = 0;
  int _upcomingCount = 0;

  List<Map<String, dynamic>> _upcomingAppointments = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/clients')),
        http.get(Uri.parse('$_baseUrl/cases')),
        http.get(Uri.parse('$_baseUrl/appointments')),
      ]).timeout(const Duration(seconds: 15));

      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception('Failed to load dashboard data');
        }
      }

      final clients = jsonDecode(utf8.decode(responses[0].bodyBytes)) as List;
      final cases = (jsonDecode(utf8.decode(responses[1].bodyBytes)) as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final appointments =
          (jsonDecode(utf8.decode(responses[2].bodyBytes)) as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      // القضايا الجارية = أي قضية حالتها مش CLOSED
      final activeCases = cases
          .where((c) => c['status']?.toString().toUpperCase() != 'CLOSED')
          .length;

      // المواعيد القادمة = حالتها SCHEDULED وتاريخها اليوم أو بعده
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final upcoming = appointments.where((a) {
        final status = a['status']?.toString().toUpperCase();
        final date = a['appointmentDate']?.toString() ?? '';
        return status == 'SCHEDULED' && date.compareTo(today) >= 0;
      }).toList();

      upcoming.sort((a, b) {
        final first = '${a['appointmentDate'] ?? ''} ${a['appointmentTime'] ?? ''}';
        final second = '${b['appointmentDate'] ?? ''} ${b['appointmentTime'] ?? ''}';
        return first.compareTo(second);
      });

      // ربط كل موعد ببيانات القضية الكاملة (فيها اسم العميل)
      final casesById = {
        for (final c in cases) (c['id'] as num).toInt(): c,
      };

      final upcomingWithCase = upcoming.map((a) {
        final legalCase = a['legalCase'];
        final caseId = legalCase is Map ? (legalCase['id'] as num?)?.toInt() : null;

        return {
          ...a,
          'fullCase': caseId != null ? casesById[caseId] : null,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _clientsCount = clients.length;
        _casesCount = cases.length;
        _activeCasesCount = activeCases;
        _upcomingCount = upcoming.length;
        _upcomingAppointments = upcomingWithCase.take(5).toList();
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

  // يفتح شاشة، وبعد الرجوع منها يحدّث الأرقام
  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (mounted) _loadStats();
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: const Text('إدارة مكتب المحاماة'),
          actions: [
            IconButton(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      fullName: widget.fullName,
                      email: widget.email,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'الإعدادات',
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحبًا بك، ${widget.fullName}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'نظرة عامة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadStats,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 700
                          ? 4
                          : constraints.maxWidth >= 450
                              ? 2
                              : 1;

                      final cardWidth =
                          (constraints.maxWidth - (columns - 1) * 16) /
                              columns;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildStatCard(
                            width: cardWidth,
                            title: 'العملاء',
                            value: _statValue(_clientsCount),
                            icon: Icons.people_outline,
                          ),
                          _buildStatCard(
                            width: cardWidth,
                            title: 'إجمالي القضايا',
                            value: _statValue(_casesCount),
                            icon: Icons.gavel_outlined,
                          ),
                          _buildStatCard(
                            width: cardWidth,
                            title: 'القضايا الجارية',
                            value: _statValue(_activeCasesCount),
                            icon: Icons.folder_open_outlined,
                          ),
                          _buildStatCard(
                            width: cardWidth,
                            title: 'المواعيد القادمة',
                            value: _statValue(_upcomingCount),
                            icon: Icons.calendar_month_outlined,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'المواعيد القادمة',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildUpcomingAppointments(),
                  const SizedBox(height: 32),
                  const Text(
                    'الوصول السريع',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildActionCard(
                        title: 'إدارة العملاء',
                        icon: Icons.people_outline,
                        onTap: () => _openScreen(const ClientsScreen()),
                      ),
                      _buildActionCard(
                        title: 'إدارة القضايا',
                        icon: Icons.gavel_outlined,
                        onTap: () => _openScreen(
                          CasesScreen(lawyerId: widget.lawyerId),
                        ),
                      ),
                      _buildActionCard(
                        title: 'إدارة المواعيد',
                        icon: Icons.calendar_month_outlined,
                        onTap: () => _openScreen(const AppointmentsScreen()),
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

  Widget _buildUpcomingAppointments() {
    if (_isLoading) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_upcomingAppointments.isEmpty) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('لا توجد مواعيد قادمة')),
        ),
      );
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      child: Column(
        children: [
          for (var i = 0; i < _upcomingAppointments.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _buildUpcomingTile(_upcomingAppointments[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingTile(Map<String, dynamic> appointment) {
    final fullCase = appointment['fullCase'];
    final client = fullCase is Map ? fullCase['client'] : null;
    final clientName =
        client is Map ? (client['fullName'] ?? '').toString() : '';
    final caseNumber =
        fullCase is Map ? (fullCase['caseNumber'] ?? '').toString() : '';

    final details = [
      if (clientName.isNotEmpty) clientName,
      if (caseNumber.isNotEmpty) 'قضية $caseNumber',
    ].join(' • ');

    final time = _formatTime(appointment['appointmentTime']);

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE7EEF3),
        child: Icon(Icons.event_note_outlined, color: _primaryColor),
      ),
      title: Text(
        (appointment['description'] ?? '').toString(),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: details.isEmpty ? null : Text(details),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(appointment['appointmentDate']),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (time.isNotEmpty)
            Text(time, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        color: Colors.white,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: _primaryColor),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 240,
      child: Card(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 28, color: _primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}