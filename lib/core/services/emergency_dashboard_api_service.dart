import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../global/global_api.dart';
import '../services/auth_storage_service.dart';
import '../../models/emergency_model/emergency_dashboard_model.dart';

class EmergencyDashboardApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── GET /emergency-queue ─────────────────────────────────────────────────
  Future<EmergencyDashboardResult<List<EmergencyQueuePatientModel>>>
      fetchEmergencyQueue() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${GlobalApi.baseUrl}/emergency-queue'),
              headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['data'] as List? ?? [])
              .map((e) => EmergencyQueuePatientModel.fromJson(
                  e as Map<String, dynamic>))
              .toList();
          return EmergencyDashboardResult.success(list);
        }
      }
      return EmergencyDashboardResult.error('Failed to load emergency queue.');
    } catch (e) {
      return EmergencyDashboardResult.error('Network error: $e');
    }
  }

  // ─── GET /bed-setup/beds?type_name=Emergency ──────────────────────────────
  // Matches React: bedSetupService → api.get('/bed-setup/beds', { params: { type_name: typeName } })
  Future<EmergencyDashboardResult<EmergencyDashboardData>>
      fetchEmergencyBeds() async {
    try {
      final headers = await _authHeaders();
      final uri = Uri.parse('${GlobalApi.baseUrl}/bed-setup/beds')
          .replace(queryParameters: {'type_name': 'Emergency'});
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return EmergencyDashboardResult.success(
              EmergencyDashboardData.fromJson(
                  data['data'] as Map<String, dynamic>));
        }
      }
      return EmergencyDashboardResult.error('Failed to load beds.');
    } catch (e) {
      return EmergencyDashboardResult.error('Network error: $e');
    }
  }

  // ─── GET /emergency-billing/active ───────────────────────────────────────
  // Matches React: emergencyBillingService → api.get('/emergency-billing/active', { params })
  Future<EmergencyDashboardResult<List<EmergencyServiceLogModel>>>
      fetchActiveServiceLogs({String? mrFilter}) async {
    try {
      final headers = await _authHeaders();
      final queryParams = <String, String>{};
      if (mrFilter != null && mrFilter.isNotEmpty) {
        queryParams['patient_mr_number'] = mrFilter;
      }
      final uri =
          Uri.parse('${GlobalApi.baseUrl}/emergency-billing/active')
              .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['data'] as List? ?? [])
              .map((e) => EmergencyServiceLogModel.fromJson(
                  e as Map<String, dynamic>))
              .toList();
          return EmergencyDashboardResult.success(list);
        }
      }
      return EmergencyDashboardResult.error('Failed to load service logs.');
    } catch (e) {
      return EmergencyDashboardResult.error('Network error: $e');
    }
  }

  // ─── POST /bed-setup/allot ────────────────────────────────────────────────
  // Matches React: bedSetupService → api.post('/bed-setup/allot', payload)
  Future<EmergencyDashboardResult<Map<String, dynamic>>> allotBed(
      Map<String, dynamic> payload) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('${GlobalApi.baseUrl}/bed-setup/allot'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return EmergencyDashboardResult.success(
              (data['data'] as Map<String, dynamic>?) ?? {});
        }
        return EmergencyDashboardResult.error(
            data['message']?.toString() ?? 'Failed to allot bed.');
      }
      return EmergencyDashboardResult.error(
          'Server error: ${response.statusCode}');
    } catch (e) {
      return EmergencyDashboardResult.error('Network error: $e');
    }
  }

  // ─── DELETE /bed-setup/allot/{allotmentId} ────────────────────────────────
  // Matches React: bedSetupService → api.delete('/bed-setup/allot/${allotmentId}')
  Future<EmergencyDashboardResult<bool>> releaseBed(int allotmentId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('${GlobalApi.baseUrl}/bed-setup/allot/$allotmentId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return EmergencyDashboardResult.success(true);
        }
        return EmergencyDashboardResult.error(
            data['message']?.toString() ?? 'Failed to release bed.');
      }
      return EmergencyDashboardResult.error(
          'Server error: ${response.statusCode}');
    } catch (e) {
      return EmergencyDashboardResult.error('Network error: $e');
    }
  }

  // ─── GET /emergency-doctor-calls/active ──────────────────────────────────
  Future<EmergencyDashboardResult<List<ActiveDoctorCallModel>>>
      fetchActiveDoctorCalls() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
              Uri.parse(
                  '${GlobalApi.baseUrl}/emergency-doctor-calls/active'),
              headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['data'] as List? ?? [])
              .map((e) => ActiveDoctorCallModel.fromJson(
                  e as Map<String, dynamic>))
              .toList();
          return EmergencyDashboardResult.success(list);
        }
      }
      return EmergencyDashboardResult.success([]);
    } catch (e) {
      return EmergencyDashboardResult.success([]);
    }
  }

  // ─── PUT /emergency-doctor-calls/{id}/end ────────────────────────────────
  // Matches React: emergencyDoctorCallService → api.put('/emergency-doctor-calls/${callId}/end')
  Future<EmergencyDashboardResult<Map<String, dynamic>>> endDoctorCall(
      int callId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse(
                '${GlobalApi.baseUrl}/emergency-doctor-calls/$callId/end'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyDashboardResult.error('Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return EmergencyDashboardResult.success(
              (data['data'] as Map<String, dynamic>?) ?? {});
        }
        return EmergencyDashboardResult.error(
            data['message']?.toString() ?? 'Failed.');
      }
      return EmergencyDashboardResult.error(
          'Server error: ${response.statusCode}');
    } catch (e) {
      return EmergencyDashboardResult.error('Network error: $e');
    }
  }
}

// ─── Result Wrapper ───────────────────────────────────────────────────────────

class EmergencyDashboardResult<T> {
  final bool success;
  final T? data;
  final String? message;

  const EmergencyDashboardResult._({
    required this.success,
    this.data,
    this.message,
  });

  factory EmergencyDashboardResult.success(T data) =>
      EmergencyDashboardResult._(success: true, data: data);

  factory EmergencyDashboardResult.error(String message) =>
      EmergencyDashboardResult._(success: false, message: message);
}
