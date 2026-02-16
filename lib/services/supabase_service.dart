import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ----------------------------------------------------------------
  // 1. FETCH HISTORY
  // ----------------------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchEvacuees({bool? isCheckedIn}) async {
    try {
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
  // 3. TRACK CHECK-IN (Updated with isOutsideEc)
  // ----------------------------------------------------------------
  // [Inside SupabaseService class]

  Future<void> trackEvacueeCheckIn({
    required String profileId,
    required String fullName,
    required String evacuationCenterId,
    required String evacuationCenterName,
    String? age,
    String? sex,
    String? barangay,
    String? proofImage, 
    String? household,  
    
    // Vulnerabilities
    required bool isPregnant,
    required bool isLactating,
    required bool isChildHeaded,
    required bool isSingleHeaded,
    required bool isSoloParent,
    required bool isPwd,
    required bool isIp,
    required bool is4Ps,
    required bool isLgbt, // 🏳️‍🌈 NEW PARAMETER

    // Location Status
    required bool isOutsideEc, 
  }) async {
    try {
      if (household != null && household.isNotEmpty) {
        await _ensureFamilyExists(household, barangay);
      }

      await _supabase.from('evacuee_details').insert({
        'profile_id': profileId,
        'full_name': fullName,
        'evacuation_center_id': evacuationCenterId,
        'evacuation_center_name': evacuationCenterName,
        'age': int.tryParse(age ?? '0'),
        'sex': sex, 
        'barangay': barangay,
        'household': household, 
        'proof_image': proofImage, 
        
        // Vulnerabilities
        'is_pregnant': isPregnant,
        'is_lactating': isLactating,
        'is_child_headed': isChildHeaded,
        'is_single_headed': isSingleHeaded,
        'is_solo_parent': isSoloParent,
        'is_pwd': isPwd,
        'is_ip': isIp,
        'is_4ps': is4Ps,
        'is_lgbt': isLgbt, // 🏳️‍🌈 SAVE TO DB

        // Location
        'is_outside_ec': isOutsideEc,
        
        'is_checked_in': true,
        'check_in_time': DateTime.now().toUtc().toIso8601String(),
      });
      
      print('✅ Check-in successful: $fullName (LGBT: $isLgbt)');
    } catch (e) {
      print("⚠️ Supabase Check-In Error: $e");
      throw e; 
    }
  }

  Future<void> _ensureFamilyExists(String householdId, String? barangay) async {
    try {
      final existingFamily = await _supabase
          .from('family')
          .select()
          .eq('household', householdId)
          .maybeSingle();

      if (existingFamily == null) {
        await _supabase.from('family').insert({
          'household': householdId,
          'barangay': barangay,
          'isActive': true,
          'memberCount': 0, 
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await _supabase
            .from('family')
            .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('household', householdId);
      }
    } catch (e) {
      print('⚠️ Family record error (non-critical): $e');
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
    } catch (e) {
      print("⚠️ Supabase Check-Out Error: $e");
      throw e;
    }
  }
}