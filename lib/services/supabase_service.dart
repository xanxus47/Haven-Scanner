import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ----------------------------------------------------------------
  // 1. FETCH HISTORY (Includes Proof Image)
  // ----------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchEvacuees({bool? isCheckedIn}) async {
    try {
      // ✅ Explicitly fetching 'proof_image' along with other data
      var query = _supabase.from('evacuee_details').select('*, proof_image');
      
      if (isCheckedIn != null) {
        query = query.eq('is_checked_in', isCheckedIn);
      }
      final response = await query.order('check_in_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('⚠️ Error fetching history: $e');
      return [];
    }
  }

  // ----------------------------------------------------------------
  // 2. DELETE RECORD
  // ----------------------------------------------------------------
  Future<void> deleteEvacuee(int id) async {
    try {
      final record = await _supabase.from('evacuee_details').select().eq('id', id).maybeSingle();
      if (record == null) return; 

      await _supabase.from('evacuee_details').delete().eq('id', id);

      // Manually decrement stats (since we only have triggers for Insert/Update)
      await _decrementStatsAfterDelete(
        centerId: record['evacuation_center_id'],
        wasActive: record['is_checked_in'] == true,
      );
    } catch (e) {
      print("⚠️ Error deleting record: $e");
      throw e;
    }
  }

  Future<void> _decrementStatsAfterDelete({required String centerId, required bool wasActive}) async {
    try {
      final res = await _supabase.from('evacuation_stats').select().eq('evacuation_center_id', centerId).maybeSingle();
      if (res != null) {
        int currentActive = res['active_evacuees'] ?? 0;
        int currentCheckouts = res['total_checkouts'] ?? 0;

        if (wasActive) {
          currentActive = (currentActive > 0) ? currentActive - 1 : 0;
        } else {
          currentCheckouts = (currentCheckouts > 0) ? currentCheckouts - 1 : 0;
        }

        await _supabase.from('evacuation_stats').update({
          'active_evacuees': currentActive,
          'total_checkouts': currentCheckouts,
        }).eq('evacuation_center_id', centerId);
      }
    } catch (e) {
      print('⚠️ Stats Decrement Error: $e');
    }
  }

  // ----------------------------------------------------------------
  // 3. TRACK CHECK-IN (Saves Photo URL)
  // ----------------------------------------------------------------
  Future<void> trackEvacueeCheckIn({
    required String profileId,
    required String fullName,
    required String evacuationCenterId,
    required String evacuationCenterName,
    String? age,
    String? sex,
    String? barangay,
    String? disablity,
    String? proofImage, // 📸 Accepts the photo URL
  }) async {
    try {
      await _supabase.from('evacuee_details').insert({
        'profile_id': profileId,
        'full_name': fullName,
        'evacuation_center_id': evacuationCenterId,
        'evacuation_center_name': evacuationCenterName,
        'age': int.tryParse(age ?? '0'),
        'sex': sex,
        'barangay': barangay,
        'disability': disablity,
        'proof_image': proofImage, // ✅ Saved to database
        'is_checked_in': true,
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      });
      // Note: Stats are automatically updated by your SQL Trigger
    } catch (e) {
      print("⚠️ Supabase Check-In Error: $e");
      throw e; 
    }
  }

  // ----------------------------------------------------------------
  // 4. TRACK CHECK-OUT
  // ----------------------------------------------------------------
  Future<void> trackEvacueeCheckOut({required String profileId}) async {
    try {
      await _supabase.from('evacuee_details').update({
            'is_checked_in': false,
            'check_out_time': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('profile_id', profileId).eq('is_checked_in', true);
       // Note: Stats are automatically updated by your SQL Trigger
    } catch (e) {
      print("⚠️ Supabase Check-Out Error: $e");
      throw e;
    }
  }
}