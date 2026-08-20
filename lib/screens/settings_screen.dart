import 'package:flutter/material.dart';

import '../services/app_settings_service.dart';
import '../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _savingContact = false;

  bool _escalationEnabled = true;
  int _escalationInterval = 5;
  int _escalationMaxCount = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final contact = await _settings.getEmergencyContact();
    final enabled = await _settings.isEscalationEnabled();
    final interval = await _settings.getEscalationIntervalMinutes();
    final maxCount = await _settings.getEscalationMaxCount();

    if (!mounted) return;
    setState(() {
      _nameController.text = contact?.name ?? '';
      _phoneController.text = contact?.phoneNumber ?? '';
      _escalationEnabled = enabled;
      _escalationInterval = interval;
      _escalationMaxCount = maxCount;
      _loading = false;
    });
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _savingContact = true);
    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      if (name.isEmpty && phone.isEmpty) {
        await _settings.clearEmergencyContact();
      } else {
        await _settings.setEmergencyContact(
          EmergencyContact(name: name, phoneNumber: phone),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency contact saved')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _savingContact = false);
    }
  }

  Future<void> _clearContact() async {
    await _settings.clearEmergencyContact();
    if (!mounted) return;
    setState(() {
      _nameController.clear();
      _phoneController.clear();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Emergency Contact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Shown on the alarm screen.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Soni Khanal',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      validator: (v) {
                        final phone = _phoneController.text.trim();
                        if (phone.isNotEmpty &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Required if a phone number is set';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'e.g. +91 9876543210',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final name = _nameController.text.trim();
                        if (name.isNotEmpty &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Required if a name is set';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _savingContact ? null : _saveContact,
                            child: _savingContact
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _clearContact,
                          child: const Text('Clear',
                              style: TextStyle(color: AppTheme.danger)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Escalating Reminders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Keep re-alerting with follow-up notifications if a dose '
            'reminder is never answered.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enabled'),
                  value: _escalationEnabled,
                  activeColor: AppTheme.primary,
                  onChanged: (v) {
                    setState(() => _escalationEnabled = v);
                    _settings.setEscalationEnabled(v);
                  },
                ),
                if (_escalationEnabled) ...[
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Repeat every'),
                    trailing: DropdownButton<int>(
                      value: _escalationInterval,
                      items: const [5, 10, 15, 20]
                          .map((m) =>
                              DropdownMenuItem(value: m, child: Text('$m min')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _escalationInterval = v);
                        _settings.setEscalationIntervalMinutes(v);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Maximum follow-ups'),
                    trailing: DropdownButton<int>(
                      value: _escalationMaxCount,
                      items: const [1, 2, 3, 4, 5]
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text('$c')))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _escalationMaxCount = v);
                        _settings.setEscalationMaxCount(v);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
