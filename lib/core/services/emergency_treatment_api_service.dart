import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../global/global_api.dart';
import 'auth_storage_service.dart';
import '../../models/emergency_model/emergency_treatment_model.dart';

class EmergencyTreatmentApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── GET /emergency-queue ─────────────────────────────────────────────────
  Future<EmergencyQueueResult> fetchEmergencyQueue() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${GlobalApi.baseUrl}/emergency-queue'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyQueueResult(
            success: false, message: 'Session expired. Please log in again.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = (data['data'] ?? []) as List;
          return EmergencyQueueResult(
            success: true,
            queue: list
                .map((e) => EmergencyQueueItemModel.fromJson(
                    e as Map<String, dynamic>))
                .toList(),
          );
        }
      }
      return EmergencyQueueResult(
          success: false, message: 'Failed to load emergency queue.');
    } catch (e) {
      return EmergencyQueueResult(
          success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // ─── GET /emergency-treatments/mr/{mr} ───────────────────────────────────
  Future<EmergencyTreatmentResult> fetchByMR(String mrNumber) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse(
                '${GlobalApi.baseUrl}/emergency-treatments/mr/$mrNumber'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        // Not found — no existing treatment for this MR
        return EmergencyTreatmentResult(success: true, record: null);
      }
      if (response.statusCode == 401) {
        return EmergencyTreatmentResult(
            success: false, message: 'Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return EmergencyTreatmentResult(
            success: true,
            record: EmergencyTreatmentApiModel.fromJson(
                data['data'] as Map<String, dynamic>),
          );
        }
      }
      return EmergencyTreatmentResult(success: true, record: null);
    } catch (e) {
      return EmergencyTreatmentResult(
          success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // ─── POST /emergency-treatments ──────────────────────────────────────────
  Future<EmergencyTreatmentResult> createTreatment(
      Map<String, dynamic> payload) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('${GlobalApi.baseUrl}/emergency-treatments'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyTreatmentResult(
            success: false, message: 'Session expired.');
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final rec = data['data'] != null
              ? EmergencyTreatmentApiModel.fromJson(
                  data['data'] as Map<String, dynamic>)
              : null;
          return EmergencyTreatmentResult(success: true, record: rec);
        }
        return EmergencyTreatmentResult(
            success: false, message: data['message']?.toString() ?? 'Failed.');
      }
      return EmergencyTreatmentResult(
          success: false, message: 'Server error: ${response.statusCode}');
    } catch (e) {
      return EmergencyTreatmentResult(
          success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // ─── PUT /emergency-treatments/{id} ──────────────────────────────────────
  Future<EmergencyTreatmentResult> updateTreatment(
      int id, Map<String, dynamic> payload) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse('${GlobalApi.baseUrl}/emergency-treatments/$id'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyTreatmentResult(
            success: false, message: 'Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return EmergencyTreatmentResult(success: true);
        }
        return EmergencyTreatmentResult(
            success: false, message: data['message']?.toString() ?? 'Failed.');
      }
      return EmergencyTreatmentResult(
          success: false, message: 'Server error: ${response.statusCode}');
    } catch (e) {
      return EmergencyTreatmentResult(
          success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // ─── POST /emergency-billing ──────────────────────────────────────────────
  Future<EmergencyBillingResult> createBill(
      Map<String, dynamic> payload) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('${GlobalApi.baseUrl}/emergency-billing'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return EmergencyBillingResult(
            success: false, message: 'Session expired.');
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EmergencyBillingResult(
          success: data['success'] == true,
          message: data['message']?.toString(),
        );
      }
      return EmergencyBillingResult(
          success: false, message: 'Server error: ${response.statusCode}');
    } catch (e) {
      return EmergencyBillingResult(
          success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // ─── GET /shifts/current ──────────────────────────────────────────────────
  Future<ShiftResult> fetchCurrentShift() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(
            Uri.parse('${GlobalApi.baseUrl}/shifts/current'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return ShiftResult(success: false, message: 'Session expired.');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return ShiftResult(
            success: true,
            shift: ShiftModel.fromJson(data['data'] as Map<String, dynamic>),
          );
        }
      }
      return ShiftResult(
          success: false, message: 'No active shift found. Please open a shift first.');
    } catch (e) {
      return ShiftResult(
          success: false, message: 'Network error: ${e.toString()}');
    }
  }

  // ─── GET /radiology-tests ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchRadiologyTests() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${GlobalApi.baseUrl}/radiology-tests'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final list = data['data'];
          if (list is List) {
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } else if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── GET /lab/tests ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchLabTests() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${GlobalApi.baseUrl}/lab/tests'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final list = data['data'];
          if (list is List) {
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } else if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── GET /medicines ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchMedicines() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('${GlobalApi.baseUrl}/medicines'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final list = data['data'];
          if (list is List) {
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } else if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ─── GET /emergency-billing ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchBilledServices({
    required String patientName,
    required String from,
    required String to,
  }) async {
    try {
      final headers = await _authHeaders();
      final queryParameters = {
        'patient_name': patientName,
        'from': from,
        'to': to,
      };
      final uri = Uri.parse('${GlobalApi.baseUrl}/emergency-billing')
          .replace(queryParameters: queryParameters);
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          final list = data['data'];
          if (list is List) {
            return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } else if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

// ─── Result classes ───────────────────────────────────────────────────────────

class EmergencyQueueResult {
  final bool success;
  final String? message;
  final List<EmergencyQueueItemModel> queue;

  EmergencyQueueResult({
    required this.success,
    this.message,
    List<EmergencyQueueItemModel>? queue,
  }) : queue = queue ?? [];
}

class EmergencyTreatmentResult {
  final bool success;
  final String? message;
  final EmergencyTreatmentApiModel? record;

  EmergencyTreatmentResult({
    required this.success,
    this.message,
    this.record,
  });
}

class EmergencyBillingResult {
  final bool success;
  final String? message;

  EmergencyBillingResult({required this.success, this.message});
}

class ShiftResult {
  final bool success;
  final String? message;
  final ShiftModel? shift;

  ShiftResult({required this.success, this.message, this.shift});
}
