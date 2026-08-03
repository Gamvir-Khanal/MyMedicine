import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/medicine_provider.dart';
import '../widgets/medicine_card.dart';
import 'medicine_detail_screen.dart';

class LowStockScreen extends StatelessWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final lowStock = provider.lowStockMedicines;

    return Scaffold(
      appBar: AppBar(title: const Text('Low Stock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (lowStock.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: Text('No medicines are running low.')),
            ),
          if (lowStock.isNotEmpty) ...[
            const Text('Running low',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...lowStock.map((m) => MedicineCard(
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
