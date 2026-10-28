import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CasesScreen extends StatefulWidget {
  final int lawyerId;

  const CasesScreen({super.key, required this.lawyerId});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
static const String _baseUrl = 'http://localhost:8080/api';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _cases = [];
  List<Map<String, dynamic>> _clients = [];

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
        http.get(Uri.parse('$_baseUrl/cases')),
        http.get(Uri.parse('$_baseUrl/clients')),
      ]).timeout(const Duration(seconds: 15));

      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw Exception('تعذر تحميل القضايا أو العملاء');
      }

      final casesData = jsonDecode(responses[0].body) as List;
      final clientsData = jsonDecode(responses[1].body) as List;

      if (!mounted) return;

      setState(() {
        _cases = casesData
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        _clients = clientsData
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

  String _statusToArabic(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'OPEN':
        return 'جديدة';
      case 'IN_PROGRESS':
        return 'قيد النظر';
      case 'ON_HOLD':
        return 'مؤجلة';
      case 'CLOSED':
        return 'منتهية';
      default:
        return status?.toString() ?? 'جديدة';
    }
  }

  String _dateValue(dynamic value) {
    if (value == null) return '';
    return value.toString().split('T').first;
  }

  String _clientName(Map<String, dynamic> legalCase) {
    final client = legalCase['client'];

    if (client is Map) {
      return (client['fullName'] ?? '').toString();
    }

    return '';
  }

  List<Map<String, dynamic>> get _filteredCases {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _cases;

    return _cases.where((item) {
      final values = [
        item['caseNumber'],
        item['title'],
        _clientName(item),
        item['courtName'],
        _dateValue(item['nextHearingDate']),
        _statusToArabic(item['status']),
      ];

      return values.any(
        (value) => value.toString().toLowerCase().contains(query),
      );
    }).toList();
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

  Future<void> _showCaseDialog({Map<String, dynamic>? existingCase}) async {
    if (_clients.isEmpty) {
      _showMessage('أضف عميلًا أولًا قبل تسجيل قضية', isError: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (_) =>
          _CaseFormDialog(clients: _clients, existingCase: existingCase),
    );

    if (!mounted || result == null) return;

    final isEditing = existingCase != null;
    final caseNumber = result['caseNumber'] as String;

    final duplicate = _cases.any((item) {
      return item['caseNumber'] == caseNumber &&
          item['id'] != existingCase?['id'];
    });

    if (duplicate) {
      _showMessage('رقم القضية موجود بالفعل', isError: true);
      return;
    }

    final clientId = result['clientId'] as int;
    result.remove('clientId');

    try {
      final uri = isEditing
          ? Uri.parse('$_baseUrl/cases/${existingCase['id']}').replace(
              queryParameters: {
                'clientId': clientId.toString(),
                'lawyerId': widget.lawyerId.toString(),
              },
            )
          : Uri.parse('$_baseUrl/cases').replace(
              queryParameters: {
                'clientId': clientId.toString(),
                'lawyerId': widget.lawyerId.toString(),
              },
            );

      final response = isEditing
          ? await http
                .put(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(result),
                )
                .timeout(const Duration(seconds: 15))
          : await http
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode(result),
                )
                .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadData();
        _showMessage(
          isEditing ? 'تم تعديل القضية بنجاح' : 'تمت إضافة القضية بنجاح',
        );
      } else if (response.statusCode == 409) {
        _showMessage('رقم القضية مستخدم بالفعل', isError: true);
      } else {
        _showMessage(
          'فشل حفظ القضية (${response.statusCode}): ${response.body}',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage('تعذر الاتصال بالخادم أثناء حفظ القضية', isError: true);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> legalCase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف القضية'),
          content: Text(
            'هل أنت متأكد من حذف القضية ${legalCase['caseNumber']}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/cases/${legalCase['id']}'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 204 || response.statusCode == 200) {
        await _loadData();
        _showMessage('تم حذف القضية');
      } else {
        _showMessage(
          'فشل حذف القضية (${response.statusCode}): ${response.body}',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage('تعذر الاتصال بالخادم أثناء حذف القضية', isError: true);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'قيد النظر':
        return Colors.blue;
      case 'مؤجلة':
        return Colors.orange;
      case 'منتهية':
        return Colors.green;
      default:
        return const Color(0xFF173B57);
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
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> legalCase) {
    final status = _statusToArabic(legalCase['status']);

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
                  Icons.gavel_outlined,
                  color: Color(0xFF173B57),
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (legalCase['title'] ?? '').toString(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showCaseDialog(existingCase: legalCase),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'تعديل القضية',
                ),
                IconButton(
                  onPressed: () => _confirmDelete(legalCase),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'حذف القضية',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('رقم القضية: ${legalCase['caseNumber'] ?? ''}'),
            const SizedBox(height: 6),
            Text('العميل: ${_clientName(legalCase)}'),
            const SizedBox(height: 6),
            Text('المحكمة: ${legalCase['courtName'] ?? ''}'),
            const SizedBox(height: 6),
            Text('تاريخ الجلسة: ${_dateValue(legalCase['nextHearingDate'])}'),
            const SizedBox(height: 12),
            _buildStatus(status),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> cases) {
    return Card(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('رقم القضية')),
            DataColumn(label: Text('عنوان القضية')),
            DataColumn(label: Text('العميل')),
            DataColumn(label: Text('المحكمة')),
            DataColumn(label: Text('تاريخ الجلسة')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الإجراءات')),
          ],
          rows: cases.map((legalCase) {
            return DataRow(
              cells: [
                DataCell(Text('${legalCase['caseNumber'] ?? ''}')),
                DataCell(Text('${legalCase['title'] ?? ''}')),
                DataCell(Text(_clientName(legalCase))),
                DataCell(Text('${legalCase['courtName'] ?? ''}')),
                DataCell(Text(_dateValue(legalCase['nextHearingDate']))),
                DataCell(_buildStatus(_statusToArabic(legalCase['status']))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () =>
                            _showCaseDialog(existingCase: legalCase),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'تعديل القضية',
                      ),
                      IconButton(
                        onPressed: () => _confirmDelete(legalCase),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'حذف القضية',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCases = _filteredCases;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF173B57),
          foregroundColor: Colors.white,
          title: const Text('إدارة القضايا'),
          actions: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCaseDialog(),
          backgroundColor: const Color(0xFF173B57),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة قضية'),
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
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'القضايا',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF173B57),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'عرض وإدارة القضايا المسجلة في مكتب المحاماة',
                          style: TextStyle(color: Colors.grey, fontSize: 15),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ابحث برقم القضية أو العنوان أو العميل أو المحكمة',
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (filteredCases.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('لا توجد قضايا مطابقة للبحث'),
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth >= 800) {
                                return _buildDesktopTable(filteredCases);
                              }

                              return Column(
                                children: filteredCases
                                    .map(_buildCaseCard)
                                    .toList(),
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

class _CaseFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> clients;
  final Map<String, dynamic>? existingCase;

  const _CaseFormDialog({required this.clients, required this.existingCase});

  @override
  State<_CaseFormDialog> createState() => _CaseFormDialogState();
}

class _CaseFormDialogState extends State<_CaseFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _numberController;
  late final TextEditingController _titleController;
  late final TextEditingController _courtController;
  late final TextEditingController _dateController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  late String _selectedStatus;
  int? _selectedClientId;

  bool get _isEditing => widget.existingCase != null;

  @override
  void initState() {
    super.initState();

    final item = widget.existingCase;

    _numberController = TextEditingController(
      text: item?['caseNumber']?.toString() ?? '',
    );
    _titleController = TextEditingController(
      text: item?['title']?.toString() ?? '',
    );
    _courtController = TextEditingController(
      text: item?['courtName']?.toString() ?? '',
    );
    _dateController = TextEditingController(
      text: item?['nextHearingDate']?.toString().split('T').first ?? '',
    );
    _descriptionController = TextEditingController(
      text: item?['description']?.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: item?['notes']?.toString() ?? '',
    );

    _selectedStatus = _statusToArabic(item?['status']);

    final client = item?['client'];
    _selectedClientId = client is Map ? (client['id'] as num?)?.toInt() : null;

    if (_selectedClientId == null && widget.clients.isNotEmpty) {
      _selectedClientId = (widget.clients.first['id'] as num?)?.toInt();
    }
  }

  String _statusToArabic(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'OPEN':
        return 'جديدة';
      case 'IN_PROGRESS':
        return 'قيد النظر';
      case 'ON_HOLD':
        return 'مؤجلة';
      case 'CLOSED':
        return 'منتهية';
      default:
        return 'جديدة';
    }
  }

  String _statusToApi(String status) {
    switch (status) {
      case 'قيد النظر':
        return 'IN_PROGRESS';
      case 'مؤجلة':
        return 'ON_HOLD';
      case 'منتهية':
        return 'CLOSED';
      default:
        return 'OPEN';
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _titleController.dispose();
    _courtController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'هذا الحقل مطلوب';
        }

        return null;
      },
    );
  }

  Future<void> _selectDate() async {
    final initialDate = DateTime.tryParse(_dateController.text);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted || pickedDate == null) return;

    _dateController.text =
        '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedClientId == null) return;

    Navigator.of(context, rootNavigator: true).pop({
      'caseNumber': _numberController.text.trim(),
      'title': _titleController.text.trim(),
      'courtName': _courtController.text.trim(),
      'nextHearingDate': _dateController.text.trim(),
      'status': _statusToApi(_selectedStatus),
      'description': _descriptionController.text.trim(),
      'notes': _notesController.text.trim(),
      'clientId': _selectedClientId,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(_isEditing ? 'تعديل القضية' : 'إضافة قضية جديدة'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInput(
                    controller: _numberController,
                    label: 'رقم القضية',
                    icon: Icons.numbers,
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    controller: _titleController,
                    label: 'عنوان القضية',
                    icon: Icons.gavel_outlined,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedClientId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'العميل',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    items: widget.clients.map((client) {
                      final id = (client['id'] as num).toInt();

                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          (client['fullName'] ?? '').toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClientId = value;
                      });
                    },
                    validator: (value) => value == null ? 'اختر العميل' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    controller: _courtController,
                    label: 'اسم المحكمة',
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _selectDate,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الجلسة',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'اختر تاريخ الجلسة';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'حالة القضية',
                      prefixIcon: Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'جديدة', child: Text('جديدة')),
                      DropdownMenuItem(
                        value: 'قيد النظر',
                        child: Text('قيد النظر'),
                      ),
                      DropdownMenuItem(value: 'مؤجلة', child: Text('مؤجلة')),
                      DropdownMenuItem(value: 'منتهية', child: Text('منتهية')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    controller: _descriptionController,
                    label: 'وصف القضية',
                    icon: Icons.description_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildInput(
                    controller: _notesController,
                    label: 'ملاحظات',
                    icon: Icons.notes_outlined,
                    maxLines: 2,
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
          ElevatedButton(
            onPressed: _save,
            child: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة القضية'),
          ),
        ],
      ),
    );
  }
}