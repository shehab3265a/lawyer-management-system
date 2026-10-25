import 'package:flutter/material.dart';


class DashboardScreen extends StatelessWidget {
  final String fullName;
  final String email;

  const DashboardScreen({
    super.key,
    required this.fullName,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF173B57),
          foregroundColor: Colors.white,
          title: const Text('إدارة مكتب المحاماة'),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const _LoginPlaceholder(),
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
                    'مرحبًا بك، $fullName',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF173B57),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
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
                            value: '—',
                            icon: Icons.people_outline,
                          ),
                          _buildStatCard(
                            width: cardWidth,
                            title: 'القضايا',
                            value: '—',
                            icon: Icons.gavel_outlined,
                          ),
                          _buildStatCard(
                            width: cardWidth,
                            title: 'المواعيد',
                            value: '—',
                            icon: Icons.calendar_month_outlined,
                          ),
                          _buildStatCard(
                            width: cardWidth,
                            title: 'المحامون',
                            value: '—',
                            icon: Icons.account_balance_outlined,
                          ),
                        ],
                      );
                    },
                  ),
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
                        onTap: () {},
                      ),
                      _buildActionCard(
                        title: 'إدارة القضايا',
                        icon: Icons.gavel_outlined,
                        onTap: () {},
                      ),
                      _buildActionCard(
                        title: 'إدارة المواعيد',
                        icon: Icons.calendar_month_outlined,
                        onTap: () {},
                      ),
                      _buildActionCard(
                        title: 'إدارة المحامين',
                        icon: Icons.account_balance_outlined,
                        onTap: () {},
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
              Icon(
                icon,
                size: 30,
                color: const Color(0xFF173B57),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(color: Colors.grey),
              ),
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
                Icon(
                  icon,
                  size: 28,
                  color: const Color(0xFF173B57),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginPlaceholder extends StatelessWidget {
  const _LoginPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('يرجى تسجيل الدخول مرة أخرى'),
      ),
    );
  }
}
