// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'check_in_screen.dart';
import 'check_out_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? userName;
  final VoidCallback onSignOut;
  final bool isEmbedded; // New flag

  const HomeScreen({
    super.key,
    required this.userName,
    required this.onSignOut,
    this.isEmbedded = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Modern Color Palette
  final Color _primaryColor = const Color(0xFF2563EB); // Royal Blue
  final Color _checkInColor = const Color(0xFF10B981); // Emerald Green
  final Color _checkOutColor = const Color(0xFFF59E0B); // Amber/Orange

  void _navigateToCheckIn() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckInScreen(userName: widget.userName, onSignOut: widget.onSignOut)));
  }

  void _navigateToCheckOut() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CheckOutScreen(userName: widget.userName, onSignOut: widget.onSignOut)));
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.power_settings_new_rounded, size: 32, color: Colors.red.shade600),
              ),
              const SizedBox(height: 20),
              const Text('Sign Out', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('End current session?', style: TextStyle(color: Colors.black54, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () { Navigator.pop(context); widget.onSignOut(); },
                      child: const Text('Logout', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MDRRMO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400)),
                    Text('Scanner', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade900)),
                  ],
                ),
                IconButton(
                  onPressed: _showLogoutConfirmation,
                  icon: Icon(Icons.logout_rounded, color: Colors.blueGrey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: TextStyle(color: Colors.blue.shade100, fontSize: 14)),
                      Text(widget.userName ?? 'Admin', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Text('ACTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade400, letterSpacing: 1.2)),
            const SizedBox(height: 16),

            // Buttons (Short Version)
            Column(
              children: [
                _buildActionCard('Check In', 'Scan QR to admit', Icons.login_rounded, _checkInColor, _navigateToCheckIn),
                const SizedBox(height: 16),
                _buildActionCard('Check Out', 'Scan QR to release', Icons.logout_rounded, _checkOutColor, _navigateToCheckOut),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) return content;
    return Scaffold(backgroundColor: const Color(0xFFF8FAFC), body: content);
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 120,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueGrey.shade50),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(sub, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade400)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: Colors.blueGrey.shade200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}