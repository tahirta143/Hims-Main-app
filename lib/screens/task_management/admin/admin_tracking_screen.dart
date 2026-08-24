import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../custum widgets/task_management/task_app_bar.dart';
import '../../../custum widgets/task_management/task_bottom_bar.dart';
import '../../../custum widgets/task_management/task_workspace_drawer.dart';
import '../../../custum widgets/task_management/task_primitives.dart';
import '../../../models/task_management/task_session_model.dart';
import '../../../core/services/task_management/task_api_service.dart';
import '../../../providers/task_management/task_workspace_provider.dart';
import '../task_workspace_screen.dart';

class AdminTrackingScreen extends StatefulWidget {
  const AdminTrackingScreen({super.key});

  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TaskApiService _api = TaskApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<TrackedSession> _sessions = [];
  bool _loading = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    final res = await _api.fetchTrackedSessions();
    if (res.success && res.data != null) {
      setState(() => _sessions = res.data!);
    }
    if (!quiet) setState(() => _loading = false);
  }

  void _onBottomNavItemBar(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TaskWorkspaceScreen(initialTabIndex: index)),
      (route) => false,
    );
  }

  String _getRelativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(date);
      
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '—';
    }
  }

  String _getDeviceOf(String? ua) {
    if (ua == null || ua.isEmpty) return 'Unknown device';
    final uaLower = ua.toLowerCase();
    
    String os = 'Unknown';
    if (uaLower.contains('windows')) os = 'Windows';
    else if (uaLower.contains('android')) os = 'Android';
    else if (uaLower.contains('iphone') || uaLower.contains('ipad') || uaLower.contains('ios')) os = 'iOS';
    else if (uaLower.contains('mac os')) os = 'macOS';
    else if (uaLower.contains('linux')) os = 'Linux';

    String browser = '';
    if (uaLower.contains('edg/')) browser = 'Edge';
    else if (uaLower.contains('chrome/')) browser = 'Chrome';
    else if (uaLower.contains('firefox/')) browser = 'Firefox';
    else if (uaLower.contains('safari/')) browser = 'Safari';

    return browser.isNotEmpty ? '$browser · $os' : os;
  }

  Future<void> _terminateSession(TrackedSession s) async {
    setState(() => _busyId = s.sessionTokenId);
    final res = await _api.terminateSession(s.sessionTokenId);
    if (res.success) {
      setState(() => _sessions.removeWhere((item) => item.sessionTokenId == s.sessionTokenId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ended ${s.employeeName}\'s session')));
    }
    setState(() => _busyId = null);
  }

  Future<void> _terminateAll(TrackedSession s) async {
    setState(() => _busyId = 'all-${s.employeeId}');
    final res = await _api.terminateAllForEmployee(s.employeeId);
    if (res.success) {
      setState(() => _sessions.removeWhere((item) => item.employeeId == s.employeeId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ended all sessions for ${s.employeeName}')));
    }
    setState(() => _busyId = null);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    
    final query = _searchController.text.trim().toLowerCase();
    final visible = _sessions.where((s) {
      if (query.isEmpty) return true;
      return s.employeeName.toLowerCase().contains(query) ||
             (s.employeeCode?.toLowerCase().contains(query) ?? false) ||
             (s.designation?.toLowerCase().contains(query) ?? false) ||
             (s.ipAddress?.toLowerCase().contains(query) ?? false);
    }).toList();

    final onlineCount = _sessions.where((s) => s.isOnline).length;
    final uniquePeopleCount = _sessions.map((s) => s.employeeId).toSet().length;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: TaskAppBar(
        title: 'Session Tracking',
        subtitle: 'ADMINISTRATION',
        scaffoldKey: _scaffoldKey,
        action: IconButton(
          onPressed: () => _loadSessions(),
          icon: Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
        ),
      ),
      drawer: TaskWorkspaceDrawer(
        activeTabIndex: 15,
        unreadCount: workspace.unreadCount,
        isAdmin: true,
        onTabSelected: _onBottomNavItemBar,
      ),
      body: Column(
        children: [
          // Stats Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: StatTileWidget(label: 'SESSIONS', value: '${_sessions.length}', icon: Icons.monitor_rounded, accentColor: TaskColors.slateText, bgColor: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: StatTileWidget(label: 'ONLINE NOW', value: '$onlineCount', icon: Icons.circle, accentColor: const Color(0xFF10B981), bgColor: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: StatTileWidget(label: 'PEOPLE', value: '$uniquePeopleCount', icon: Icons.people_rounded, accentColor: TaskColors.medicalAccent, bgColor: Colors.white)),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TaskColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search by name, code, department or IP…',
                  hintStyle: TextStyle(fontSize: 12, color: TaskColors.slateLight),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: TaskColors.slateLight),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Session List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent))
                : visible.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.security_rounded,
                        title: 'Nobody is connected',
                        hint: 'Sessions appear here while staff have Task Management open.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadSessions(quiet: true),
                        color: TaskColors.medicalAccent,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final s = visible[idx];
                            final isBusy = _busyId == s.sessionTokenId;
                            final isAllBusy = _busyId == 'all-${s.employeeId}';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: TaskColors.border),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        children: [
                                          AvatarWidget(name: s.employeeName, id: s.employeeId, size: 38),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 11,
                                              height: 11,
                                              decoration: BoxDecoration(
                                                color: s.isOnline ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s.employeeName,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TaskColors.slateText),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (s.isCurrent) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(6)),
                                                    child: const Text('YOU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: TaskColors.medicalAccent)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '${s.designation ?? 'Staff'}${s.employeeCode != null ? ' · ${s.employeeCode}' : ''}',
                                              style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            s.ipAddress ?? '—',
                                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: TaskColors.slateMuted),
                                          ),
                                          if (s.socketConnectionCount > 1)
                                            Text(
                                              '${s.socketConnectionCount} tabs',
                                              style: const TextStyle(fontSize: 9, color: TaskColors.medicalAccent, fontWeight: FontWeight.w600),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(height: 1, color: TaskColors.borderLight),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _infoRow(Icons.devices_rounded, _getDeviceOf(s.userAgent)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Expanded(child: _infoRow(Icons.login_rounded, 'Login: ${_getRelativeTime(s.loginAt)}')),
                                                Expanded(child: _infoRow(Icons.visibility_rounded, 'Seen: ${_getRelativeTime(s.lastSeenAt)}')),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Action Buttons
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _actionBtn(
                                            label: 'End all',
                                            color: TaskColors.slateMuted,
                                            loading: isAllBusy,
                                            onTap: () => _terminateAll(s),
                                          ),
                                          const SizedBox(width: 6),
                                          _actionBtn(
                                            label: 'End',
                                            color: const Color(0xFFE11D48),
                                            isPrimary: true,
                                            loading: isBusy,
                                            onTap: () => _terminateSession(s),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: TaskFluidBottomNavBar(
        currentIndex: -1,
        unreadCount: workspace.unreadCount,
        onItemSelected: _onBottomNavItemBar,
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: TaskColors.slateLight),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 10, color: TaskColors.slateMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool loading = false,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.transparent,
          border: isPrimary ? null : Border.all(color: TaskColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
          : Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : color,
              ),
            ),
      ),
    );
  }
}
