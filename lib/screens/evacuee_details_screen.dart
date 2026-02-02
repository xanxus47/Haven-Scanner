import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EvacueeDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> evacuee;

  const EvacueeDetailsScreen({super.key, required this.evacuee});

  @override
  Widget build(BuildContext context) {
    final String fullName = evacuee['full_name'] ?? 'Unknown';
    final String id = evacuee['profile_id'] ?? 'N/A';
    final String barangay = evacuee['barangay'] ?? 'N/A';
    final String age = evacuee['age']?.toString() ?? 'N/A';
    final String sex = evacuee['sex'] ?? 'N/A';
    final String center = evacuee['evacuation_center_name'] ?? 'N/A';
    final String? proofImage = evacuee['proof_image']; // The Photo URL

    String timeStr = 'Unknown';
    if (evacuee['check_in_time'] != null) {
        timeStr = DateFormat('MMM dd, yyyy • h:mm a').format(DateTime.parse(evacuee['check_in_time']).toLocal());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Details"), backgroundColor: const Color(0xFF2563EB)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📸 PROOF IMAGE
            Container(
              width: double.infinity,
              height: 350,
              color: Colors.grey.shade200,
              child: proofImage != null && proofImage.isNotEmpty
                  ? Image.network(proofImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildNoImage())
                  : _buildNoImage(),
            ),

            // 📝 DETAILS
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Chip(label: Text("ID: $id"), backgroundColor: Colors.blue.shade50, labelStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  
                  const Divider(height: 30),
                  
                  _row(Icons.location_on, "Evacuation Center", center),
                  _row(Icons.home, "Barangay", barangay),
                  _row(Icons.person, "Demographics", "$age years old • $sex"),
                  _row(Icons.access_time, "Check-in Time", timeStr),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImage() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_not_supported, size: 50, color: Colors.grey.shade400), const SizedBox(height: 10), Text("No Photo Proof", style: TextStyle(color: Colors.grey.shade500))]);
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.grey.shade600, size: 22),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }
}