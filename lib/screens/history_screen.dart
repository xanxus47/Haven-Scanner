import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/supabase_service.dart';
import '/screens/evacuee_details_screen.dart'; 

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _activeEvacuees = [];
  List<Map<String, dynamic>> _pastEvacuees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final active = await _supabaseService.fetchEvacuees(isCheckedIn: true);
    final past = await _supabaseService.fetchEvacuees(isCheckedIn: false);

    if (mounted) {
      setState(() {
        _activeEvacuees = active;
        _pastEvacuees = past;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRecord(int id, bool isActiveList) async {
    // Optimistic update for UI speed
    setState(() {
      if (isActiveList) {
        _activeEvacuees.removeWhere((item) => item['id'] == id);
      } else {
        _pastEvacuees.removeWhere((item) => item['id'] == id);
      }
    });

    try {
      await _supabaseService.deleteEvacuee(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Record deleted"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: Colors.grey[900],
          )
        );
      }
    } catch (e) {
      // Revert if failed (simplified for brevity, usually you'd reload)
      if (mounted) _loadData(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting record"), backgroundColor: Colors.red));
    }
  }

  // ----------------------------------------------------------------
  // 🗑️ SLEEK DELETE DIALOG
  // ----------------------------------------------------------------
  Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, size: 32, color: Colors.red.shade400),
              ),
              const SizedBox(height: 20),
              const Text(
                "Delete Record?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "This action cannot be undone. Are you sure you want to remove this evacuee history?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false), // 👈 CANCEL
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: Colors.grey[700],
                        backgroundColor: Colors.grey[100],
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true), // 👈 CONFIRM
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.red.shade400,
                        elevation: 0,
                      ),
                      child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Evacuee Records', 
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.refresh, color: Colors.blue, size: 20),
            ),
            onPressed: _loadData,
          ),
          const SizedBox(width: 16),
        ],
        // 👇 UPDATED: Clean, modern tabs (No more blocky slide)
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],       // Color of active text
          unselectedLabelColor: Colors.grey,  // Color of inactive text
          indicatorColor: Colors.blue[700],   // The sleek underline
          indicatorWeight: 3,                 // Thickness of the line
          indicatorSize: TabBarIndicatorSize.tab, // Line stretches full width
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(text: 'Active (${_activeEvacuees.length})'),
            Tab(text: 'History (${_pastEvacuees.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue.shade600))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_activeEvacuees, isActive: true),
                _buildList(_pastEvacuees, isActive: false),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> data, {required bool isActive}) {
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No records found", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final id = item['id']; 
        final name = item['full_name'] ?? 'Unknown';
        final timeIn = _formatDate(item['check_in_time']);
        final timeOut = _formatDate(item['check_out_time']);

        // Only allow delete swipe on History items (optional logic, can be changed)
        // Or you can allow swipe on both. Currently set to allow on History.
        // Change logic inside direction to allow both if needed.
        return Dismissible(
          key: Key(id.toString()),
          direction: isActive ? DismissDirection.none : DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await _showDeleteConfirmDialog(context);
          },
          onDismissed: (direction) => _deleteRecord(id, isActive),
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EvacueeDetailsScreen(evacuee: item)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isActive ? Icons.person_rounded : Icons.history_rounded,
                          color: isActive ? Colors.green.shade600 : Colors.grey.shade500,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Text(
                                  isActive ? "In: $timeIn" : "Out: $timeOut",
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '--';
    try {
      return DateFormat('MMM d, h:mm a').format(DateTime.parse(dateStr).toLocal());
    } catch (_) { return dateStr; }
  }
}