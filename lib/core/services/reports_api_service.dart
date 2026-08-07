import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../global/global_api.dart';
import 'auth_storage_service.dart';

class ReportsApiService {
  final AuthStorageService _storage = AuthStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(String path, [Map<String, String>? params]) {
    final cleanParams = <String, String>{};
    if (params != null) {
      params.forEach((k, v) {
        if (v.trim().isNotEmpty && v != 'all' && v != 'All') {
          cleanParams[k] = v.trim();
        }
      });
    }
    final urlStr = '${GlobalApi.baseUrl}$path';
    if (cleanParams.isEmpty) {
      return Uri.parse(urlStr);
    }
    return Uri.parse(urlStr).replace(queryParameters: cleanParams);
  }

  // ─── 1. Expenses Report (GET /expenses) ──────────────────────────
  Future<List<dynamic>> fetchExpensesReport({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? shift,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/expenses', {
        if (search != null) 'search': search,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (shift != null) 'shift_type': shift,
      });

      debugPrint('Fetching expenses report: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null && data['data'] is List) {
          return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      debugPrint('Expenses report error status: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error fetching expenses report: $e');
      return [];
    }
  }

  // ─── 2. Lab Report (GET /reports/lab-report) ─────────────────────
  Future<List<dynamic>> fetchLabReport({
    String? search,
    String? dateFrom,
    String? dateTo,
    String? shift,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/reports/lab-report', {
        if (search != null) 'search': search,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (shift != null) 'shift': shift,
      });

      debugPrint('Fetching lab report: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null && data['data'] is List) {
          return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      debugPrint('Lab report error status: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error fetching lab report: $e');
      return [];
    }
  }

  // ─── 3. Shares Report (GET /reports/shares) ──────────────────────
  Future<Map<String, dynamic>?> fetchSharesReport({
    String? personType,
    String? serviceType,
    String? q,
    String? department,
  }) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/reports/shares', {
        if (personType != null) 'personType': personType,
        if (serviceType != null) 'serviceType': serviceType,
        if (q != null) 'q': q,
        if (department != null) 'department': department,
      });

      debugPrint('Fetching shares report: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      debugPrint('Shares report error status: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error fetching shares report: $e');
      return null;
    }
  }

  // ─── 4. Shift Report Data ──────────────────────────────────────────
  Future<List<dynamic>> fetchAvailableShiftsForDate(String dateStr) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/opd-patient-data', {'shift_date': dateStr});

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['data'] is List) {
          return data['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching available shifts: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchShiftOpdData(dynamic shiftId) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/opd-patient-data/shift/$shiftId');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['data'] is List) {
          return data['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shift OPD data: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchShiftExpensesData(dynamic shiftId, {String? shiftDate, String? shiftType}) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/expenses/shift/$shiftId', {
        if (shiftDate != null) 'shift_date': shiftDate,
        if (shiftType != null) 'shift_type': shiftType,
      });

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['data'] is List) {
          return data['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shift expenses: $e');
      return [];
    }
  }

  Future<List<dynamic>> fetchShiftEmergencyBills(dynamic shiftId) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/emergency-billing/shift/$shiftId');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['data'] is List) {
          return data['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shift emergency bills: $e');
      return [];
    }
  }

  // ─── 5. Monthly Report ────────────────────────────────────────────
  Future<List<dynamic>> fetchMonthlySummary(String year, String month) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/reports/monthly-summary', {'year': year, 'month': month});
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true && data['report'] is List) {
          return data['report'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching monthly summary: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchMonthlyDetailed(String year, String month) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/reports/monthly-detailed', {'year': year, 'month': month});
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching monthly detailed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchMonthlyCalendar(String year, String month) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/reports/monthly-calendar', {'year': year, 'month': month});
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching monthly calendar: $e');
      return null;
    }
  }

  // ─── 6. Yearly Report (GET /reports/yearly-breakdown) ──────────────
  Future<Map<String, dynamic>?> fetchYearlyBreakdown(String year) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/reports/yearly-breakdown', {'year': year});
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          return data as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching yearly breakdown: $e');
      return null;
    }
  }

  // ─── 7. OPD Patient Data (GET /opd-patient-data) ────────────────────
  Future<List<dynamic>> fetchOpdPatientData(String startDate, String endDate) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/opd-patient-data', {
        'startDate': startDate,
        'endDate': endDate,
      });

      debugPrint('Fetching OPD patient data: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null && data['data'] is List) {
          return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      debugPrint('OPD report error status: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error fetching OPD report: $e');
      return [];
    }
  }

  // ─── 8. Emergency Billing Data (GET /emergency-billing/date-range) ─
  Future<List<dynamic>> fetchEmergencyBillsData(String startDate, String endDate) async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/emergency-billing/date-range', {
        'startDate': startDate,
        'endDate': endDate,
      });

      debugPrint('Fetching Emergency bills data: $uri');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null && data['data'] is List) {
          return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      debugPrint('Emergency report error status: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error fetching Emergency report: $e');
      return [];
    }
  }

  // ─── 9. Payroll Attendance Data (GET https://api.payroll.afaqhims.com/api/attendance) ──
  Future<List<dynamic>> fetchPayrollAttendanceData({
    String? departmentId,
    String? employeeId,
    String? shiftId,
  }) async {
    try {
      final params = <String, String>{};
      if (departmentId != null && departmentId.isNotEmpty) params['department_id'] = departmentId;
      if (employeeId != null && employeeId.isNotEmpty) params['employee_id'] = employeeId;
      if (shiftId != null && shiftId.isNotEmpty) params['duty_shift_id'] = shiftId;

      final uri = Uri.parse('https://api.payroll.afaqhims.com/api/attendance').replace(queryParameters: params.isNotEmpty ? params : null);
      debugPrint('Fetching Payroll Attendance: $uri');

      final response = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          if (data['attendance'] is List) return data['attendance'] as List<dynamic>;
          if (data['data'] is List) return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      debugPrint('Payroll attendance error status: ${response.statusCode} - ${response.body}');
      return [];
    } catch (e) {
      debugPrint('Error fetching Payroll attendance: $e');
      return [];
    }
  }

  // ─── 10. Departments Lookup (GET /departments) ─────────────────────
  Future<List<dynamic>> fetchDepartments() async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/departments');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          if (data['departments'] is List) return data['departments'] as List<dynamic>;
          if (data['data'] is List) return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching departments: $e');
      return [];
    }
  }

  // ─── 11. Employees Lookup (GET /employees) ─────────────────────────
  Future<List<dynamic>> fetchEmployees() async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/employees');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          if (data['employees'] is List) return data['employees'] as List<dynamic>;
          if (data['data'] is List) return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      return [];
    }
  }

  // ─── 12. Shifts Lookup (GET /shifts) ───────────────────────────────
  Future<List<dynamic>> fetchShifts() async {
    try {
      final headers = await _authHeaders();
      final uri = _buildUri('/shifts');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          if (data['shifts'] is List) return data['shifts'] as List<dynamic>;
          if (data['data'] is List) return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching shifts: $e');
      return [];
    }
  }
}

