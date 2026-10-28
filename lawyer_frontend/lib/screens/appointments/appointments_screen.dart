import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// القيم المسموحة في الداتا بيز (chk_appointments_status):
// SCHEDULED / COMPLETED / CANCELLED
String _statusToArabic(dynamic status) {
  switch (status?.toString().toUpperCase()) {
    case 'COMPLETED':
      return 'تم';
    case 'CANCELLED':
      return 'ملغي';
    case 'SCHEDULED':
    default:
      return 'مجدول';
  }
}

String _statusToApi(String status) {
  switch (status) {
    case 'تم':
      return 'COMPLETED';
    case 'ملغي':
      return 'CANCELLED';
    case 'مجدول':
    default:
      return 'SCHEDULED';
  }
}

String _formatDate(dynamic value) {
  if (value == null) return '';
  final parts = value.toString().split('T').first.split('-');
  if (parts.length != 3) return value.toString();
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

// يحول "14:30:00" إلى "02:30 مساءً"
String _formatTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return '—';
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

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  static const String _baseUrl = 'http://localhost:8080/api';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _cases = [];

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$_baseUrl/appointments')),
        http.get(Uri.parse('$_baseUrl/cases')),
      ]).timeout(const Duration(seconds: 15));

      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw Exception('تعذر تحميل المواعيد أو القضايا');
      }

      final appointmentsData =
          jsonDecode(utf8.decode(responses[0].bodyBytes)) as List;
      final casesData = jsonDecode(utf8.decode(responses[1].bodyBytes)) as List;

      final appointments = appointmentsData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      // ترتيب حسب التاريخ ثم الوقت
      appointments.sort((a, b) {
        final first = '${a['appointmentDate'] ?? ''} ${a['appointmentTime'] ?? ''}';
        final second = '${b['appointmentDate'] ?? ''} ${b['appointmentTime'] ?? ''}';
        return first.compareTo(second);
      });

      if (!mounted) return;

      setState(() {
        _appointments = appointments;
        _cases = casesData
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'تعذر الاتصال بالخادم. تأكد من تشغيل الـ Backend.';
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // بيانات القضية كاملة (فيها العميل) من قائمة القضايا المحملة
  Map<String, dynamic>? _caseFor(Map<String, dynamic> appointment) {
    final legalCase = appointment['legalCase'];
    if (legalCase is! Map) return null;

    final id = (legalCase['id'] as num?)?.toInt();

    for (final item in _cases) {
      if ((item['id'] as num?)?.toInt() == id) return item;
    }

    return Map<String, dynamic>.from(legalCase);
  }

  String _clientName(Map<String, dynamic> appointment) {
    final client = _caseFor(appointment)?['client'];
    if (client is Map) return (client['fullName'] ?? '').toString();
    return '';
  }

  String _caseLabel(Map<String, dynamic> appointment) {
    final legalCase = _caseFor(appointment);
    if (legalCase == null) return '';

    final number = (legalCase['caseNumber'] ?? '').toString();
    final title = (legalCase['title'] ?? '').toString();

    if (number.isEmpty) return title;
    return '$number - $title';
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _appointments;

    return _appointments.where((appointment) {
      final values = [
        _clientName(appointment),
        _caseLabel(appointment),
        appointment['description'],
        appointment['location'],
        _statusToArabic(appointment['status']),
        _formatDate(appointment['appointmentDate']),
      ];

      return values.any(
        (value) => (value ?? '').toString().toLowerCase().contains(query),
      );
    }).toList();
  }

  Future<void> _showAppointmentDialog({
    Map<String, dynamic>? existingAppointment,
  }) async {
    if (_cases.isEmpty) {
      _showMessage('أضف قضية أولًا قبل تسجيل موعد', isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _AppointmentFormDialog(
        cases: _cases,
        existingAppointment: existingAppointment,
      ),
    );

    if (!mounted || result == null) return;

    final isEditing = existingAppointment != null;
    final caseId = result['caseId'] as int;
    result.remove('caseId');

    try {
      final uri = Uri.parse(
        isEditing
            ? '$_baseUrl/appointments/${existingAppointment['id']}'
            : '$_baseUrl/appointments',
      ).replace(queryParameters: {'caseId': caseId.toString()});

      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode(result);

      final response = isEditing
          ? await http
                .put(uri, headers: headers, body: body)
                .timeout(const Duration(seconds: 15))
          : await http
                .post(uri, headers: headers, body: body)
                .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadData();
        _showMessage(
          isEditing ? 'تم تعديل الموعد بنجاح' : 'تمت إضافة الموعد بنجاح',
        );
      } else {
        _showMessage(
          'فشل حفظ الموعد (${response.statusCode}): ${response.body}',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage('تعذر الاتصال بالخادم أثناء حفظ الموعد', isError: true);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف الموعد'),
          content: Text(
            'هل تريد حذف موعد "${appointment['description'] ?? ''}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/appointments/${appointment['id']}'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 204 || response.statusCode == 200) {
        await _loadData();
        _showMessage('تم حذف الموعد');
      } else {
        _showMessage(
          'فشل حذف الموعد (${response.statusCode}): ${response.body}',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage('تعذر الاتصال بالخادم أثناء حذف الموعد', isError: true);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'تم':
        return Colors.green;
      case 'ملغي':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildStatus(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> appointment) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () =>
              _showAppointmentDialog(existingAppointment: appointment),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'تعديل الموعد',
        ),
        IconButton(
          onPressed: () => _confirmDelete(appointment),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'حذف الموعد',
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final location = (appointment['location'] ?? '').toString();

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.event_note_outlined,
                  color: Color(0xFF173B57),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (appointment['description'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildActions(appointment),
              ],
            ),
            const SizedBox(height: 10),
            Text('العميل: ${_clientName(appointment)}'),
            const SizedBox(height: 6),
            Text('القضية: ${_caseLabel(appointment)}'),
            const SizedBox(height: 6),
            Text('التاريخ: ${_formatDate(appointment['appointmentDate'])}'),
            const SizedBox(height: 6),
            Text('الوقت: ${_formatTime(appointment['appointmentTime'])}'),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('المكان: $location'),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _buildStatus(_statusToArabic(appointment['status'])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> appointments) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('العميل')),
          DataColumn(label: Text('القضية')),
          DataColumn(label: Text('موضوع الموعد')),
          DataColumn(label: Text('التاريخ')),
          DataColumn(label: Text('الوقت')),
          DataColumn(label: Text('المكان')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('إجراءات')),
        ],
        rows: appointments.map((appointment) {
          return DataRow(
            cells: [
              DataCell(Text(_clientName(appointment))),
              DataCell(Text(_caseLabel(appointment))),
              DataCell(Text((appointment['description'] ?? '').toString())),
              DataCell(Text(_formatDate(appointment['appointmentDate']))),
              DataCell(Text(_formatTime(appointment['appointmentTime']))),
              DataCell(Text((appointment['location'] ?? '').toString())),
              DataCell(
                _buildStatus(_statusToArabic(appointment['status'])),
              ),
              DataCell(_buildActions(appointment)),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _filteredAppointments;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المواعيد'),
          backgroundColor: const Color(0xFF173B57),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAppointmentDialog(),
          backgroundColor: const Color(0xFF173B57),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة موعد'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'المواعيد',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF173B57),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'تابع مواعيد العملاء والجلسات والاستشارات القانونية.',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText:
                                'ابحث باسم العميل أو القضية أو موضوع الموعد أو الحالة',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (appointments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('لا توجد مواعيد مطابقة للبحث'),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 750) {
                                return Column(
                                  children: appointments
                                      .map(_buildAppointmentCard)
                                      .toList(),
                                );
                              }

                              return Card(
                                color: Colors.white,
                                clipBehavior: Clip.antiAlias,
                                child: _buildTable(appointments),
                              );
                            },
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _AppointmentFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> cases;
  final Map<String, dynamic>? existingAppointment;

  const _AppointmentFormDialog({
    required this.cases,
    required this.existingAppointment,
  });

  @override
  State<_AppointmentFormDialog> createState() =>
      _AppointmentFormDialogState();
}

class _AppointmentFormDialogState extends State<_AppointmentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descriptionController;
  late final TextEditingController _timeController;
  late final TextEditingController _locationController;

  late DateTime _selectedDate;
  late String _selectedPeriod;
  late String _selectedStatus;
  int? _selectedCaseId;

  bool get _isEditing => widget.existingAppointment != null;

  @override
  void initState() {
    super.initState();

    final item = widget.existingAppointment;

    _descriptionController = TextEditingController(
      text: item?['description']?.toString() ?? '',
    );
    _locationController = TextEditingController(
      text: item?['location']?.toString() ?? '',
    );

    _selectedDate =
        DateTime.tryParse(item?['appointmentDate']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 1));

    _selectedStatus = _statusToArabic(item?['status']);

    // تحويل الوقت المحفوظ (24 ساعة) إلى 12 ساعة + صباحًا/مساءً
    String timeText = '';
    String period = 'صباحًا';

    final savedTime = item?['appointmentTime']?.toString();
    if (savedTime != null && savedTime.contains(':')) {
      final parts = savedTime.split(':');
      final hour24 = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour24 != null && minute != null) {
        period = hour24 >= 12 ? 'مساءً' : 'صباحًا';
        final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
        timeText = '$hour12:${minute.toString().padLeft(2, '0')}';
      }
    }

    _timeController = TextEditingController(text: timeText);
    _selectedPeriod = period;

    final legalCase = item?['legalCase'];
    _selectedCaseId = legalCase is Map
        ? (legalCase['id'] as num?)?.toInt()
        : null;

    final caseIds = widget.cases
        .map((c) => (c['id'] as num).toInt())
        .toList();

    if (_selectedCaseId == null || !caseIds.contains(_selectedCaseId)) {
      _selectedCaseId = caseIds.isNotEmpty ? caseIds.first : null;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _timeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _caseTitle(Map<String, dynamic> legalCase) {
    final number = (legalCase['caseNumber'] ?? '').toString();
    final title = (legalCase['title'] ?? '').toString();
    final client = legalCase['client'];
    final clientName = client is Map ? (client['fullName'] ?? '').toString() : '';

    final base = number.isEmpty ? title : '$number - $title';
    return clientName.isEmpty ? base : '$base ($clientName)';
  }

  String? _validateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اكتب وقت الموعد';
    }

    final match = RegExp(r'^(\d{1,2})(?::(\d{1,2}))?$').firstMatch(value.trim());

    if (match == null) {
      return 'اكتب الوقت مثل 10 أو 10:30';
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return 'الساعة من 1 إلى 12 والدقائق من 00 إلى 59';
    }

    return null;
  }

  // يرجع الوقت بصيغة 24 ساعة "HH:mm" للباك اند
  String _timeFor24h() {
    final match = RegExp(
      r'^(\d{1,2})(?::(\d{1,2}))?$',
    ).firstMatch(_timeController.text.trim())!;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');

    if (_selectedPeriod == 'مساءً' && hour < 12) {
      hour += 12;
    } else if (_selectedPeriod == 'صباحًا' && hour == 12) {
      hour = 0;
    }

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _dateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _displayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختر تاريخ الموعد',
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCaseId == null) return;

    final location = _locationController.text.trim();

    Navigator.of(context, rootNavigator: true).pop({
      'caseId': _selectedCaseId,
      'description': _descriptionController.text.trim(),
      'appointmentDate': _dateForApi(_selectedDate),
      'appointmentTime': _timeFor24h(),
      'location': location.isEmpty ? null : location,
      'status': _statusToApi(_selectedStatus),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isEditing ? 'تعديل الموعد' : 'إضافة موعد جديد'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCaseId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'القضية',
                      prefixIcon: Icon(Icons.gavel_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.cases.map((legalCase) {
                      return DropdownMenuItem<int>(
                        value: (legalCase['id'] as num).toInt(),
                        child: Text(
                          _caseTitle(legalCase),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCaseId = value);
                    },
                    validator: (value) => value == null ? 'اختر القضية' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'موضوع الموعد',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'اكتب موضوع الموعد';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الموعد',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_displayDate(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _timeController,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'الوقت',
                            hintText: '10 أو 10:30',
                            prefixIcon: Icon(Icons.access_time),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateTime,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 115,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedPeriod,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'الفترة',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'صباحًا',
                              child: Text('صباحًا'),
                            ),
                            DropdownMenuItem(
                              value: 'مساءً',
                              child: Text('مساءً'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedPeriod = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _locationController,
                    maxLength: 255,
                    decoration: const InputDecoration(
                      labelText: 'المكان (اختياري)',
                      prefixIcon: Icon(Icons.place_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'حالة الموعد',
                      prefixIcon: Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'مجدول', child: Text('مجدول')),
                      DropdownMenuItem(value: 'تم', child: Text('تم')),
                      DropdownMenuItem(value: 'ملغي', child: Text('ملغي')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedStatus = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
          ),
        ],
      ),
    );
  }
}