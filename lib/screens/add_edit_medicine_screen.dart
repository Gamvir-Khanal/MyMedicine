import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../providers/medicine_provider.dart';
import '../utils/constants.dart';

class AddEditMedicineScreen extends StatefulWidget {
  const AddEditMedicineScreen({super.key, this.existing});

  final Medicine? existing;

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _quantityController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _instructionsController;

  String _form = AppConstants.medicineForms.first;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 180));
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _nameController = TextEditingController(text: m?.name ?? '');
    _dosageController = TextEditingController(text: m?.dosage ?? '');
    _quantityController =
        TextEditingController(text: m?.quantity.toString() ?? '');
    _thresholdController =
        TextEditingController(text: (m?.lowStockThreshold ?? 5).toString());
    _instructionsController =
        TextEditingController(text: m?.instructions ?? '');
    if (m != null) {
      _form = m.form;
      _expiryDate = m.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final provider = context.read<MedicineProvider>();
      final quantity = int.parse(_quantityController.text);
      final threshold = int.tryParse(_thresholdController.text) ?? 5;

      if (widget.existing == null) {
        await provider.addMedicine(
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          form: _form,
          quantity: quantity,
          lowStockThreshold: threshold,
          expiryDate: _expiryDate,
          instructions: _instructionsController.text.trim(),
        );
      } else {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          form: _form,
          quantity: quantity,
          lowStockThreshold: threshold,
          expiryDate: _expiryDate,
          instructions: _instructionsController.text.trim(),
        );
        await provider.updateMedicine(updated);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save medicine: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Medicine' : 'Add Medicine')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dosageController,
              decoration:
                  const InputDecoration(labelText: 'Dosage (e.g. 500mg)'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _form,
              decoration: const InputDecoration(labelText: 'Form'),
              items: AppConstants.medicineForms
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) => setState(() => _form = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Enter a number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _thresholdController,
                    decoration: const InputDecoration(labelText: 'Refill at'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expiry date'),
              subtitle: Text(
                  '${_expiryDate.year}-${_expiryDate.month.toString().padLeft(2, '0')}-${_expiryDate.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickExpiryDate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _instructionsController,
              decoration:
                  const InputDecoration(labelText: 'Instructions (optional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEditing ? 'Save Changes' : 'Add Medicine'),
            ),
          ],
        ),
      ),
    );
  }
}
