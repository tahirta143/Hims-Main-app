import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_session_model.dart';
import '../../../core/services/task_management/task_api_service.dart';

class AdminTrackingScreen extends StatefulWidget {
  const AdminTrackingScreen({super.key});

  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  final TaskApiService _api = TaskApiService();
  List<TrackedSession> _sessions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _loading = true);
    final res = await _api.fetchTrackedSessions();
    if (res.success && res.data != null) {
      _sessions = res.data!;
    }
    setState(() => _loading = false);
  }

  Future<void> _terminateSession(String sessionId) async {
    final res = await _api.terminateSession(sessionId);
    if (res.success) {
      setState(() => _sessions.removeWhere((s) => s.sessionTokenId == sessionId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session terminated')),
        );
      }
    }
  }

  Future<void> _terminateAll(int employeeId) async {
    final res = await _api.terminateAllForEmployee(employeeId);
    if (res.success) {
      setState(() => _sessions.removeWhere((s) => s.employeeId == employeeId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All sessions terminated for employee')),
        );
      }
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '—';
    try {
      final d = DateTime.parse(dateStr).toLocal();
      return DateFormat('d MMM, h:mm a').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text('Staff Presence & Tracking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TaskColors.slateText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh_rounded, color: TaskColors.slateMuted),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
          : _sessions.isEmpty
              ? const EmptyStateWidget(icon: Icons.security_rounded, title: 'No active sessions', hint: 'Staff active sessions will be tracked here.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final s = _sessions[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TaskColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvatarWidget(name: s.employeeName, id: s.employeeId, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                                    if (s.isCurrent) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                                        child: const Text('YOU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${s.designation ?? 'Staff'} · IP: ${s.ipAddress ?? '—'}',
                                  style: const TextStyle(fontSize: 10, color: TaskColors.slateMuted),
                                ),
                                if (s.deviceType != null || s.userAgent != null)
                                  Text(
                                    s.deviceType ?? s.userAgent ?? '',
                                    style: const TextStyle(fontSize: 10, color: TaskColors.slateLight),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Text('Last seen: ${_formatDate(s.lastSeenAt)}', style: const TextStyle(fontSize: 9, color: TaskColors.slateLight)),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 16, color: TaskColors.slateLight),
                            onSelected: (val) {
                              if (val == 'single') {
                                _terminateSession(s.sessionTokenId);
                              } else if (val == 'all') {
                                _terminateAll(s.employeeId);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'single',
                                child: Text('End this session', style: TextStyle(fontSize: 12, color: Color(0xFFE11D48))),
                              ),
                              const PopupMenuItem(
                                value: 'all',
                                child: Text('End all sessions for staff', style: TextStyle(fontSize: 12, color: Color(0xFFE11D48))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
