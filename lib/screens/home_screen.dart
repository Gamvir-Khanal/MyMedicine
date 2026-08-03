import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/medicine_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/medicine_card.dart';
import 'add_edit_medicine_screen.dart';
import 'dose_history_screen.dart';
import 'expiry_screen.dart';
import 'low_stock_screen.dart';
import 'medicine_detail_screen.dart';
import 'medicine_list_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final medicineProvider = context.watch<MedicineProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Medicine"),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            tooltip: themeProvider.isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _push(context, const SettingsScreen()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddEditMedicineScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: () => medicineProvider.loadMedicines(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Text('Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _summaryRow(context, medicineProvider),
            const SizedBox(height: 12),
            const Text('Quick actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _quickActionsGrid(context),
            const SizedBox(height: 12),
            _recentlyAddedSection(context, medicineProvider),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, MedicineProvider provider) {
    return Row(
      children: [
        _summaryCard(
          context,
          'Medicines',
          provider.medicines.length.toString(),
          Icons.medication_outlined,
          AppTheme.primary,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          context,
          'Expiring soon',
          provider.expiringSoonMedicines.length.toString(),
          Icons.event_busy_outlined,
          AppTheme.warning,
        ),
        const SizedBox(width: 12),
        _summaryCard(
          context,
          'Low stock',
          provider.lowStockMedicines.length.toString(),
          Icons.inventory_2_outlined,
          AppTheme.accent,
        ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _quickActionsGrid(BuildContext context) {
    final actions = [
      _QuickAction('All Medicines', Icons.list_alt_outlined,
          () => _push(context, const MedicineListScreen())),
      _QuickAction('Reminders', Icons.alarm_outlined,
          () => _push(context, const RemindersScreen())),
      _QuickAction('Expiry Tracker', Icons.event_busy_outlined,
          () => _push(context, const ExpiryScreen())),
      _QuickAction('Low Stock', Icons.inventory_2_outlined,
          () => _push(context, const LowStockScreen())),
      _QuickAction('Dose History', Icons.calendar_month_outlined,
          () => _push(context, const DoseHistoryScreen())),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.8,
      children: actions
          .map((a) => _actionTile(context, a.label, a.icon, a.onTap))
          .toList(),
    );
  }

  Widget _actionTile(
      BuildContext context, String label, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium?.color)),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.35),
                  size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentlyAddedSection(
      BuildContext context, MedicineProvider provider) {
    final recent = provider.recentlyAddedMedicines();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recently added',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (provider.medicines.length > recent.length)
              TextButton(
                onPressed: () => _push(context, const MedicineListScreen()),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...recent.map((m) => MedicineCard(
              medicine: m,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MedicineDetailScreen(medicine: m)),
              ),
            )),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _QuickAction {
  _QuickAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
