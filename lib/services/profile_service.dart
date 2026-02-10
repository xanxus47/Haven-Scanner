// lib/services/profile_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/profile_model.dart';
import '../models/evacuation_center_model.dart';

class ProfileService {
  static const String baseUrl = 'https://citrusapi-dev.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  // 🆕 4P's HOUSEHOLD TRACKING (STATIC!)
  static Set<String> _fourPsHouseholds = {};
  static bool _fourPsLoaded = false;

  // ----------------------------------------------------------------
  // 1. HELPER: Extract ID
  // ----------------------------------------------------------------
  String? extractProfileId(String qrData) {
    final data = qrData.trim();
    try {
      final jsonData = jsonDecode(data);
      if (jsonData is Map) {
        if (jsonData.containsKey('profile_id')) return jsonData['profile_id'].toString();
        if (jsonData.containsKey('id')) return jsonData['id'].toString();
      }
    } catch (_) {}
    
    if (data.contains('/profile/')) {
      return data.split('/profile/').last.split('/').first.split('?').first;
    }
    
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    if (uuidRegex.hasMatch(data)) return data;

    return data; 
  }

  // ----------------------------------------------------------------
  // 2. HELPER: Authenticated Request (Auto-Retry Logic)
  // ----------------------------------------------------------------
  Future<http.Response> _authenticatedRequest(String method, String endpoint, {Object? body}) async {
    String token = await _authService.getAccessToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache'
    };

    http.Response response;

    // Perform Initial Request
    try {
      if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: body);
      } else {
        response = await http.get(uri, headers: headers);
      }
    } catch (e) {
      // Return a fake 500 response on network error so the app doesn't crash
      return http.Response('Network Error', 500);
    }

    // 🔄 AUTO-REFRESH LOGIC (FIXED)
    if (response.statusCode == 401) {
      print('⚠️ Token expired (401). Attempting to refresh...');

      try {
        // ✨ THE FIX: Explicitly call refresh before getting the token again
        await _authService.refreshToken(); 
        
        // Now get the NEW token
        token = await _authService.getAccessToken();
        headers['Authorization'] = 'Bearer $token';
        
        print('✅ Token refreshed. Retrying request...');

        if (method == 'POST') {
          response = await http.post(uri, headers: headers, body: body);
        } else {
          response = await http.get(uri, headers: headers);
        }
      } catch (e) {
        print('❌ Token Refresh Failed: $e');
        // If refresh fails, we return the original 401 response
        // This will trigger the "Session expired" message downstream
      }
    }

    return response;
  }

  // ----------------------------------------------------------------
  // 3. GET PROFILE (Fixed Error Handling)
  // ----------------------------------------------------------------
  Future<Map<String, dynamic>> getProfileDetails(String profileId) async {
    try {
      final response = await _authenticatedRequest('GET', '/profile/$profileId');

      if (response.statusCode == 200) {
        return {'success': true, 'data': Profile.fromJson(jsonDecode(response.body))};
      } 
      // 🛑 SPECIFIC ERRORS
      else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Profile not found in database'};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired. Please re-login.'};
      }
      
      return {'success': false, 'message': 'Server Error (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ----------------------------------------------------------------
  // 4. CHECK STATUS
  // ----------------------------------------------------------------
  Future<Map<String, dynamic>> getEvacueeStatus(String profileId) async {
    try {
      final response = await _authenticatedRequest('GET', '/profile/$profileId/evacuation');

      if (response.statusCode == 404) {
        return {'success': true, 'isCheckedIn': false};
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool isCheckedIn = false;

        if (data is List) {
          for (var item in data) {
            if (_isActiveRecord(item)) { isCheckedIn = true; break; }
          }
        } else if (data is Map) {
          if (_isActiveRecord(data)) isCheckedIn = true;
        }

        return {'success': true, 'isCheckedIn': isCheckedIn, 'data': data};
      }
      
      if (response.statusCode == 401) return {'success': false, 'message': 'Session expired'};
      
      return {'success': false, 'message': 'Status check failed (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  bool _isActiveRecord(dynamic item) {
    if (item == null || item is! Map) return false;
    if (item['isActive'] == false) return false;
    
    final dates = [item['dateCheckedOut'], item['checkOutDate'], item['endDateTime'], item['dateDeleted']];
    for (var date in dates) {
      if (date != null && date.toString().isNotEmpty) return false;
    }
    return true;
  }

  // ----------------------------------------------------------------
  // 5. CHECK IN
  // ----------------------------------------------------------------
  Future<Map<String, dynamic>> checkInEvacuee(String profileId, String centerId) async {
    try {
      final body = jsonEncode({'evacuationCenter': centerId});
      final response = await _authenticatedRequest('POST', '/profile/$profileId/evacuation/check-in', body: body);

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Check-in Successful'};
      } else if (response.statusCode == 409) {
        return {'success': false, 'message': 'Already checked in!'};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired'};
      }
      
      return {'success': false, 'message': data?['message'] ?? 'Check-in failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ----------------------------------------------------------------
  // 6. CHECK OUT
  // ----------------------------------------------------------------
  Future<Map<String, dynamic>> checkOutEvacuee(String profileId) async {
    try {
      final response = await _authenticatedRequest('POST', '/profile/$profileId/evacuation/check-out', body: jsonEncode({})); 

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        return {'success': true, 'message': 'Check-out Successful'};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Session expired'};
      }
      
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : null;
      return {'success': false, 'message': data?['message'] ?? 'Check-out failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ----------------------------------------------------------------
  // 7. GET CENTERS
  // ----------------------------------------------------------------
  Future<Map<String, dynamic>> getEvacuationCenters() async {
    try {
      final response = await _authenticatedRequest('GET', '/evacuation?page=1&numPerPage=50');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] is List) {
          final list = (data['result'] as List)
            .map((e) => EvacuationCenter.fromJson(e))
            .where((c) => c.isActivated && c.evacuationStatus == '03')
            .toList();
          return {'success': true, 'data': list};
        }
      }
      return {'success': true, 'data': <EvacuationCenter>[]};
    } catch (_) {
      return {'success': true, 'data': <EvacuationCenter>[]};
    }
  }

  // ----------------------------------------------------------------
  // 8. LOAD 4P's HOUSEHOLDS
  // ----------------------------------------------------------------
  Future<void> load4PsHouseholds() async {
    if (_fourPsLoaded) {
      print('✅ 4Ps households already loaded (${_fourPsHouseholds.length} total)');
      return;
    }

    try {
      print('🔄 Loading 4Ps households from API...');
      
      final response = await _authenticatedRequest('GET', '/profile?is4P=true');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List profiles = data['result'] ?? [];
        
        _fourPsHouseholds.clear();
        
        for (var profile in profiles) {
          final household = profile['household'];
          if (household != null && household.toString().isNotEmpty) {
            _fourPsHouseholds.add(household.toString());
          }
        }
        
        _fourPsLoaded = true;
        print('✅ Loaded ${_fourPsHouseholds.length} 4Ps households');
      } else {
        print('⚠️ Failed to load 4Ps households: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading 4Ps households: $e');
    }
  }

  bool isHousehold4Ps(String? householdId) {
    if (householdId == null || householdId.isEmpty) return false;
    return _fourPsHouseholds.contains(householdId);
  }

  int get fourPsHouseholdCount => _fourPsHouseholds.length;
  bool get fourPsDataLoaded => _fourPsLoaded;
}