import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/medicine_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../widgets/medicine_card.dart';
import 'add_edit_medicine_screen.dart';
import 'dose_history_screen.dart';
import 'expiry_screen.dart';
import 'login_screen.dart';
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
        leading: StreamBuilder<User?>(
          stream: AuthService.instance.authStateChanges,
          builder: (context, snapshot) {
            final user = snapshot.data;
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: GestureDetector(
                onTap: () => _showProfileSheet(context),
                child: _buildAvatar(user),
              ),
            );
          },
        ),
        leadingWidth: 56,
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

  /// Builds the circular avatar for the AppBar.
  Widget _buildAvatar(User? user) {
    if (user != null) {
      // Google photo available
      if (user.photoURL != null && user.photoURL!.isNotEmpty) {
        return CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(user.photoURL!),
          backgroundColor: AppTheme.primary.withOpacity(0.15),
        );
      }
      // Email / name login — show initial
      final name = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email ?? '');
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.primary.withOpacity(0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }
    // Guest / not signed in
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey.withOpacity(0.2),
      child: Icon(Icons.person_outline_rounded,
          color: Colors.grey.shade500, size: 20),
    );
  }

  /// Shows the profile bottom-sheet with account info and sign-in/out actions.
  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StreamBuilder<User?>(
          stream: AuthService.instance.authStateChanges,
          builder: (context, snapshot) {
            final user = snapshot.data;

            if (user != null) {
              final displayName = user.displayName?.isNotEmpty == true
                  ? user.displayName!
                  : (user.email ?? 'MyMedicine User');

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 40, height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Avatar
                      _buildAvatar(user),
                      const SizedBox(height: 12),
                      Text(displayName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (user.email != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(user.email!,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                        ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.logout_rounded,
                            color: AppTheme.danger),
                        title: const Text('Sign Out',
                            style: TextStyle(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.w600)),
                        onTap: () async {
                          // Show dialog BEFORE popping the sheet so the
                          // context remains valid throughout.
                          final confirmed = await showDialog<bool>(
                            context: sheetCtx,
                            builder: (dialogCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                              title: const Text('Sign Out'),
                              content: const Text(
                                  'Are you sure you want to sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogCtx).pop(true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.danger),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            if (sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop(); // close sheet
                            }
                            await AuthService.instance.signOut();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            }

            // Guest state
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey.withOpacity(0.15),
                      child: Icon(Icons.person_outline_rounded,
                          color: Colors.grey.shade400, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text('Not signed in',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Sign in to sync and back up your medicines',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
                        },
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign In / Register'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickAction {
  _QuickAction(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}
