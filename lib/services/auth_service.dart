// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'https://citrusapi-dev.onrender.com/api/v1';
  final storage = const FlutterSecureStorage();

  // Enhanced login with detailed debugging
  Future<void> login(String username, String password) async {
    print('═══════════════════════════════════════');
    print('🔐 STARTING LOGIN PROCESS');
    print('═══════════════════════════════════════');
    print('Base URL: $baseUrl');
    print('Endpoint: /user/login');
    print('Username: $username');
    
    try {
      // Create the request
      final uri = Uri.parse('$baseUrl/user/login');
      print('Full URL: $uri');
      
      final Map<String, String> requestBody = {
        'UserName': username,
        'Password': password,
      };
      
      print('Request Body: $requestBody');
      print('JSON Body: ${jsonEncode(requestBody)}');
      
      // Make the request
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60));

      print('\n═══════════════════════════════════════');
      print('📡 RESPONSE RECEIVED');
      print('═══════════════════════════════════════');
      print('Status Code: ${response.statusCode}');
      print('Response Headers:');
      response.headers.forEach((key, value) {
        print('  $key: $value');
      });
      
      print('Response Body Length: ${response.body.length} bytes');
      
      // Check if response is empty
      if (response.body.isEmpty) {
        print('❌ ERROR: Empty response body');
        print('═══════════════════════════════════════');
        throw Exception('Server returned empty response');
      }
      
      print('Response Body (raw):');
      print('"${response.body}"');
      
      // Check for common HTML error pages
      if (response.body.contains('<!DOCTYPE html>') || 
          response.body.contains('<html>')) {
        print('⚠️ WARNING: Response appears to be HTML page (server error)');
      }

      // Try to parse JSON
      try {
        final data = jsonDecode(response.body);
        print('\n✅ JSON parsed successfully');
        print('Response type: ${data.runtimeType}');
        
        if (data is Map) {
          print('Response keys: ${data.keys.join(', ')}');
          print('Response values:');
          data.forEach((key, value) {
            print('  "$key": ${value is String ? '"$value"' : value}');
          });
        } else {
          print('Response data: $data');
        }
        
        // Handle successful login (status code 200)
        if (response.statusCode == 200) {
          print('\n═══════════════════════════════════════');
          print('🎉 LOGIN SUCCESSFUL - Status 200');
          print('═══════════════════════════════════════');
          
          // Store tokens if available
          if (data is Map) {
            // Try different possible token field names
            final possibleTokenKeys = [
              'accessToken', 'token', 'access_token', 'auth_token', 
              'jwt', 'accessToken', 'AuthToken', 'Authorization'
            ];
            
            String? accessToken;
            for (var key in possibleTokenKeys) {
              if (data[key] != null) {
                accessToken = data[key].toString();
                print('✅ Found access token with key: "$key"');
                break;
              }
            }
            
            if (accessToken != null) {
              await storage.write(key: 'access_token', value: accessToken);
              print('✅ Access token stored securely');
            } else {
              print('⚠️ No access token found in response');
            }
            
            // Look for refresh token
            String? refreshToken;
            final refreshKeys = ['refreshToken', 'refresh_token', 'refresh'];
            for (var key in refreshKeys) {
              if (data[key] != null) {
                refreshToken = data[key].toString();
                print('✅ Found refresh token with key: "$key"');
                break;
              }
            }
            
            if (refreshToken != null) {
              await storage.write(key: 'refresh_token', value: refreshToken);
            }
            
          } else {
            print('⚠️ Response is not a JSON object');
          }
          
          // Store username and login state
          await storage.write(key: 'username', value: username);
          await storage.write(key: 'is_logged_in', value: 'true');
          print('✅ Username stored: $username');
          print('✅ Login state saved');
          
          // Store entire response for debugging
          await storage.write(key: 'last_login_response', value: response.body);
          
          print('\n✅ LOGIN COMPLETE - User authenticated');
          print('═══════════════════════════════════════');
          return;
        }
        
      } catch (e) {
        print('\n❌ JSON PARSE ERROR: $e');
        print('Raw response that failed to parse:');
        print('"${response.body}"');
        
        // Even if JSON parsing fails, check status code
        if (response.statusCode == 200) {
          print('⚠️ JSON parse failed but status is 200 - storing basic login');
          await storage.write(key: 'username', value: username);
          await storage.write(key: 'is_logged_in', value: 'true');
          return;
        }
        
        print('═══════════════════════════════════════');
        throw Exception('Invalid server response: ${response.body}');
      }
      
      // Handle error status codes
      print('\n═══════════════════════════════════════');
      print('❌ LOGIN FAILED - Status ${response.statusCode}');
      print('═══════════════════════════════════════');
      
      switch (response.statusCode) {
        case 400:
          throw Exception('Bad request - invalid parameters');
        case 401:
          throw Exception('Invalid username or password');
        case 403:
          throw Exception('Access forbidden');
        case 404:
          throw Exception('Login endpoint not found (404)');
        case 500:
          if (response.body.isNotEmpty) {
            throw Exception('Server error: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}');
          } else {
            throw Exception('Internal server error (500) - empty response');
          }
        case 502:
        case 503:
        case 504:
          throw Exception('Server is temporarily unavailable (${response.statusCode})');
        default:
          throw Exception('Login failed: Status ${response.statusCode} - ${response.body.length > 50 ? response.body.substring(0, 50) + "..." : response.body}');
      }
      
    } catch (e) {
      print('\n═══════════════════════════════════════');
      print('💥 LOGIN EXCEPTION');
      print('═══════════════════════════════════════');
      print('Error: $e');
      
      // Check error type
      if (e is http.ClientException) {
        print('HTTP Client Exception - network issue');
        throw Exception('Network error: ${e.message}');
      }
      
      if (e.toString().contains('timed out')) {
        print('Request timeout');
        throw Exception('Connection timeout. Server is not responding.');
      }
      
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable')) {
        print('Network/Socket exception');
        throw Exception('Network error. Check your internet connection.');
      }
      
      rethrow;
    }
  }

  // Test connection to API server
  Future<void> testConnection() async {
    print('\n═══════════════════════════════════════');
    print('🔧 TESTING API SERVER CONNECTION');
    print('═══════════════════════════════════════');
    print('Testing endpoint: $baseUrl/place/barangay');
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/place/barangay'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));
      
      print('✅ Connection successful');
      print('Status: ${response.statusCode}');
      print('Response length: ${response.body.length} bytes');
      
      if (response.statusCode == 200) {
        print('✅ Server is responding correctly (200 OK)');
        try {
          final data = jsonDecode(response.body);
          print('✅ Response is valid JSON');
          if (data is List) {
            print('✅ Response is a list with ${data.length} items');
          }
        } catch (e) {
          print('⚠️ Response is not JSON: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}');
        }
      } else {
        print('⚠️ Server responded with ${response.statusCode}');
        print('Response: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}');
      }
    } catch (e) {
      print('❌ Connection failed: $e');
      print('This could mean:');
      print('1. Server is down');
      print('2. Internet connection issue');
      print('3. Wrong URL/endpoint');
      print('4. Firewall blocking the connection');
    }
    
    print('═══════════════════════════════════════');
  }

  // Alternative login method with different parameter variations
  Future<void> tryAlternativeLogin(String username, String password) async {
    print('\n═══════════════════════════════════════');
    print('🔄 TRYING ALTERNATIVE LOGIN METHODS');
    print('═══════════════════════════════════════');
    
    final testCases = [
      {
        'name': 'Original (UserName/Password)',
        'body': {'UserName': username, 'Password': password}
      },
      {
        'name': 'Lowercase (username/password)',
        'body': {'username': username, 'password': password}
      },
      {
        'name': 'Mixed case (userName/password)',
        'body': {'userName': username, 'password': password}
      },
      {
        'name': 'With email field',
        'body': {'email': username, 'password': password}
      },
      {
        'name': 'Different password field name',
        'body': {'UserName': username, 'pass': password}
      },
    ];
    
    for (var testCase in testCases) {
      print('\n🧪 Test: ${testCase['name']}');
      print('Parameters: ${testCase['body']}');
      
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/user/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(testCase['body']),
        ).timeout(const Duration(seconds: 30));
        
        print('Status: ${response.statusCode}');
        
        if (response.body.isNotEmpty) {
          print('Response (first 150 chars):');
          print(response.body.length > 150 ? 
                response.body.substring(0, 150) + "..." : 
                response.body);
          
          if (response.statusCode == 200) {
            print('✅ POSSIBLE SUCCESS with this combination!');
            try {
              final data = jsonDecode(response.body);
              print('Response parsed as: $data');
            } catch (_) {}
            break;
          }
        } else {
          print('Response: [EMPTY]');
        }
      } catch (e) {
        print('Error: $e');
      }
      
      await Future.delayed(const Duration(seconds: 1));
    }
    
    print('═══════════════════════════════════════');
  }

  // Refresh token
  Future<void> refreshToken() async {
    try {
      final refreshToken = await storage.read(key: 'refresh_token');
      
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      print('🔄 Refreshing token...');
      final response = await http.get(
        Uri.parse('$baseUrl/user/me/token/$refreshToken'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      print('Token refresh status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Update tokens
        final accessToken = data['accessToken'] ?? data['token'];
        final newRefreshToken = data['refreshToken'] ?? data['refresh_token'];
        
        if (accessToken != null) {
          await storage.write(key: 'access_token', value: accessToken);
        }
        
        if (newRefreshToken != null) {
          await storage.write(key: 'refresh_token', value: newRefreshToken);
        }
        
        print('✅ Token refreshed successfully');
      } else {
        await logout();
        throw Exception('Session expired. Please login again.');
      }
    } catch (e) {
      print('❌ Token refresh error: $e');
      rethrow;
    }
  }

  // Get access token
  Future<String> getAccessToken() async {
    final token = await storage.read(key: 'access_token');
    
    if (token == null) {
      throw Exception('Not authenticated');
    }
    
    return token;
  }

  // Logout
  Future<void> logout() async {
    try {
      final token = await storage.read(key: 'access_token');
      
      if (token != null) {
        print('🚪 Logging out from server...');
        await http.post(
          Uri.parse('$baseUrl/user/me/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      print('⚠️ Logout API call failed: $e');
    } finally {
      await storage.deleteAll();
      print('✅ Logged out successfully');
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await storage.read(key: 'access_token');
    return token != null;
  }

  // Get stored username
  Future<String?> getUsername() async {
    return await storage.read(key: 'username');
  }

  // Get user data if stored
  Future<Map<String, dynamic>?> getUserData() async {
    final userData = await storage.read(key: 'user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }
}