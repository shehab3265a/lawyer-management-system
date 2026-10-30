import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../../data/data_repository.dart';
import '../../widgets/offline_banner.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  static String get _baseUrl => '${AppConfig.baseUrl}/clients';

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _fromCache = false;
  DateTime? _cacheTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(dynamic error) {
    if (error is http.ClientException) {
      return 'تعذر الاتصال بالخادم. تأكد أن الـ Backend يعمل.';
    }

    return error.toString().replaceFirst('Exception: ', '');
  }

  bool _blockIfOffline() {
    if (!_fromCache) return false;

    _showMessage(
      'أنت غير متصل بالخادم. الإضافة والتعديل والحذف تحتاج اتصالًا، جرّب بعد عودة الاتصال.',
    );
    return true;
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await DataRepository.getList('clients');

      if (!mounted) return;

      setState(() {
        _fromCache = result.fromCache;
        _cacheTime = result.savedAt;

        _clients = result.items.map((client) {
          return {
            'id': client['id'],
            'name': client['fullName']?.toString() ?? '',
            'email': client['email']?.toString() ?? '',
            'phone': client['phone']?.toString() ?? '',
            'address': client['address']?.toString() ?? '',
            'notes': client['notes']?.toString() ?? '',
          };
        }).toList();

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _errorText(error);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return _clients;

    return _clients.where((client) {
      return (client['name'] ?? '').toString().toLowerCase().contains(query) ||
          (client['email'] ?? '').toString().toLowerCase().contains(query) ||
          (client['phone'] ?? '').toString().contains(query) ||
          (client['address'] ?? '').toString().toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _showAddClientDialog() async {
    if (_blockIfOffline()) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ClientDialog(),
    );

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': result['name'],
              'email': result['email'],
              'phone': result['phone'],
              'address': result['address'],
              'notes': '',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('فشلت إضافة العميل (${response.statusCode})');
      }

      await _loadClients();
      _showMessage('تمت إضافة العميل بنجاح');
    } catch (error) {
      _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showEditClientDialog(
    Map<String, dynamic> client,
  ) async {
    if (_blockIfOffline()) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ClientDialog(client: {
        'name': client['name']?.toString() ?? '',
        'email': client['email']?.toString() ?? '',
        'phone': client['phone']?.toString() ?? '',
        'address': client['address']?.toString() ?? '',
      }),
    );

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/${client['id']}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fullName': result['name'],
              'email': result['email'],
              'phone': result['phone'],
              'address': result['address'],
              'notes': client['notes'] ?? '',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('فشل تعديل العميل (${response.statusCode})');
      }

      await _loadClients();
      _showMessage('تم تعديل بيانات العميل بنجاح');
    } catch (error) {
      _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteClient(
    Map<String, dynamic> client,
  ) async {
    if (_blockIfOffline()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف العميل'),
            content: Text('هل أنت متأكد من حذف ${client['name']}؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/${client['id']}'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 409) {
        throw Exception(
          'لا يمكن حذف العميل لأن لديه قضايا مرتبطة. احذف قضاياه أولًا.',
        );
      }

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('فشل حذف العميل (${response.statusCode})');
      }

      await _loadClients();
      _showMessage('تم حذف العميل بنجاح');
    } catch (error) {
      _showMessage(_errorText(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = _filteredClients;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF173B57),
          foregroundColor: Colors.white,
          title: const Text('إدارة العملاء'),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _loadClients,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث العملاء',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'العملاء',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF173B57),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _isSaving || _isLoading
                                ? null
                                : _showAddClientDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة عميل'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF173B57),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_fromCache) OfflineBanner(savedAt: _cacheTime),
                      Card(
                        color: Colors.white,
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'ابحث عن عميل بالاسم أو البريد أو الهاتف',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 42,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _loadClients,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(60),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Card(
                          color: Colors.white,
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (clients.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            size: 60,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'لا يوجد عملاء',
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                if (constraints.maxWidth < 700) {
                                  return Column(
                                    children: clients.map((client) {
                                      return Card(
                                        key: ValueKey(client['id']),
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                client['name'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              if ((client['email'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                Text(client['email']),
                                              if ((client['email'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                const SizedBox(height: 6),
                                              Text(client['phone'] ?? ''),
                                              if ((client['address'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                const SizedBox(height: 6),
                                              if ((client['address'] ?? '')
                                                  .toString()
                                                  .isNotEmpty)
                                                Text(client['address']),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                spacing: 8,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: _isSaving
                                                        ? null
                                                        : () =>
                                                            _showEditClientDialog(
                                                              client,
                                                            ),
                                                    icon: const Icon(
                                                      Icons.edit_outlined,
                                                    ),
                                                    label:
                                                        const Text('تعديل'),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: _isSaving
                                                        ? null
                                                        : () =>
                                                            _confirmDeleteClient(
                                                              client,
                                                            ),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                    ),
                                                    label: const Text('حذف'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columnSpacing: 30,
                                    headingRowHeight: 55,
                                    dataRowMinHeight: 65,
                                    dataRowMaxHeight: 80,
                                    columns: const [
                                      DataColumn(label: Text('الاسم')),
                                      DataColumn(
                                        label: Text('البريد الإلكتروني'),
                                      ),
                                      DataColumn(label: Text('رقم الهاتف')),
                                      DataColumn(label: Text('العنوان')),
                                      DataColumn(label: Text('الإجراءات')),
                                    ],
                                    rows: clients.map((client) {
                                      return DataRow(
                                        key: ValueKey(client['id']),
                                        cells: [
                                          DataCell(
                                            Text(
                                              client['name'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              (client['email'] ?? '')
                                                      .toString()
                                                      .isEmpty
                                                  ? '—'
                                                  : client['email'],
                                              textDirection: TextDirection.ltr,
                                            ),
                                          ),
                                          DataCell(
                                            Text(client['phone'] ?? ''),
                                          ),
                                          DataCell(
                                            Text(
                                              (client['address'] ?? '')
                                                      .toString()
                                                      .isEmpty
                                                  ? '—'
                                                  : client['address'],
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: _isSaving
                                                      ? null
                                                      : () =>
                                                          _showEditClientDialog(
                                                            client,
                                                          ),
                                                  icon: const Icon(
                                                    Icons.edit_outlined,
                                                  ),
                                                  tooltip: 'تعديل',
                                                ),
                                                IconButton(
                                                  onPressed: _isSaving
                                                      ? null
                                                      : () =>
                                                          _confirmDeleteClient(
                                                            client,
                                                          ),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                  ),
                                                  tooltip: 'حذف',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSaving)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: const LinearProgressIndicator(
                  color: Color(0xFF173B57),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClientDialog extends StatefulWidget {
  final Map<String, String>? client;

  const _ClientDialog({this.client});

  @override
  State<_ClientDialog> createState() => _ClientDialogState();
}

class _ClientDialogState extends State<_ClientDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.client?['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.client?['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.client?['phone'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.client?['address'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(
          _isEditing ? 'تعديل بيانات العميل' : 'إضافة عميل جديد',
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل *',
                      hintText: 'مثال: أحمد محمد علي',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final name = value?.trim() ?? '';

                      if (name.isEmpty) {
                        return 'يرجى إدخال الاسم الكامل';
                      }

                      final parts = name
                          .split(RegExp(r'\s+'))
                          .where((part) => part.isNotEmpty)
                          .toList();

                      if (parts.length < 3) {
                        return 'الاسم يجب أن يكون ثلاثيًا أو أكثر';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';

                      if (email.isNotEmpty &&
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)) {
                        return 'يرجى إدخال بريد إلكتروني صحيح';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف *',
                      hintText: '01XXXXXXXXX',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (!RegExp(r'^01[0-9]{9}$')
                          .hasMatch(value?.trim() ?? '')) {
                        return 'رقم الهاتف يجب أن يكون 11 رقمًا ويبدأ بـ 01';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF173B57),
            ),
            child: Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
          ),
        ],
      ),
    );
  }
}