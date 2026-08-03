import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/medicine_provider.dart';
import '../widgets/medicine_card.dart';
import 'medicine_detail_screen.dart';

class ExpiryScreen extends StatelessWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final expired = provider.expiredMedicines;
    final expiringSoon = provider.expiringSoonMedicines
        .where((m) => !m.isExpired)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Expiry Tracker')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (expired.isEmpty && expiringSoon.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No expired or soon-to-expire medicines.')),
            ),
          if (expired.isNotEmpty) ...[
            const Text('Expired',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...expired.map((m) => MedicineCard(
                  medicine: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MedicineDetailScreen(medicine: m)),
                  ),
                )),
            const SizedBox(height: 20),
          ],
          if (expiringSoon.isNotEmpty) ...[
            const Text('Expiring within 30 days',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...expiringSoon.map((m) => MedicineCard(
                  medicine: m,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MedicineDetailScreen(medicine: m)),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
