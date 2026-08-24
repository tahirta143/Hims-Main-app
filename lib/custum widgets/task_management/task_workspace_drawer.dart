import 'package:flutter/material.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/task_management/admin/admin_tasks_screen.dart';
import '../../screens/task_management/admin/admin_projects_screen.dart';
import '../../screens/task_management/admin/admin_people_screen.dart';
import '../../screens/task_management/admin/admin_scores_screen.dart';
import '../../screens/task_management/admin/admin_reports_screen.dart';
import '../../screens/task_management/admin/admin_tracking_screen.dart';
import 'task_primitives.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const Color _kTeal     = Color(0xFF00B5AD);
const Color _kTealDark = Color(0xFF0D9488);
const Color _kSlate    = Color(0xFF334155);
const Color _kMuted    = Color(0xFF64748B);

/// A sidebar drawer for the Task Management workspace that mirrors the React
/// sidebar design:
///
///   ← Back to HIMS          (at the top)
///   ─────────────────────
///   WORKSPACE
///     Dashboard
///     Board
///     Chat       (with unread badge)
///     Progress
///   ─────────────────────
///   ADMINISTRATION         (admin-only)
///     All Tasks
///     Projects
///     People
///     Appraisals
///     Reports
///     Tracking
class TaskWorkspaceDrawer extends StatelessWidget {
  final int activeTabIndex;
  final int unreadCount;
  final bool isAdmin;
  final ValueChanged<int> onTabSelected;

  const TaskWorkspaceDrawer({
    super.key,
    required this.activeTabIndex,
    required this.unreadCount,
    required this.isAdmin,
    required this.onTabSelected,
  });

  void _goBackToHims(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _pushAdmin(BuildContext context, Widget screen) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _selectTab(BuildContext context, int index) {
    Navigator.of(context).pop(); // close drawer
    onTabSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gradient Header ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 16,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kTeal, _kTealDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.task_alt_rounded, color: Colors.white, size: 26),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Task Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Workspace & Administration',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // ── Back to HIMS ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: InkWell(
                      onTap: () => _goBackToHims(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 16, color: _kMuted),
                            const SizedBox(width: 10),
                            Text(
                              'Back to HIMS Dashboard',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _kSlate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Divider(height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
                  ),

            // ── WORKSPACE section ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 4),

            _WorkspaceNavItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              active: activeTabIndex == 0,
              onTap: () => _selectTab(context, 0),
            ),
            _WorkspaceNavItem(
              icon: Icons.view_kanban_rounded,
              label: 'Board',
              active: activeTabIndex == 1,
              onTap: () => _selectTab(context, 1),
            ),
            _WorkspaceNavItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              active: activeTabIndex == 2,
              badgeCount: unreadCount,
              onTap: () => _selectTab(context, 2),
            ),
            _WorkspaceNavItem(
              icon: Icons.trending_up_rounded,
              label: 'Progress',
              active: activeTabIndex == 3,
              onTap: () => _selectTab(context, 3),
            ),

            if (isAdmin) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDF2F7)),
              const SizedBox(height: 8),

              // ── ADMINISTRATION section ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  'ADMINISTRATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              _WorkspaceNavItem(
                icon: Icons.assignment_outlined,
                label: 'All Tasks',
                active: activeTabIndex == 10,
                onTap: () => _pushAdmin(context, const AdminTasksScreen()),
              ),
              _WorkspaceNavItem(
                icon: Icons.business_rounded,
                label: 'Projects',
                active: activeTabIndex == 11,
                onTap: () => _pushAdmin(context, const AdminProjectsScreen()),
              ),
              _WorkspaceNavItem(
                icon: Icons.people_outline_rounded,
                label: 'People',
                active: activeTabIndex == 12,
                onTap: () => _pushAdmin(context, const AdminPeopleScreen()),
              ),
              _WorkspaceNavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Appraisals',
                active: activeTabIndex == 13,
                onTap: () => _pushAdmin(context, const AdminScoresScreen()),
              ),
              _WorkspaceNavItem(
                icon: Icons.radar_rounded,
                label: 'Reports',
                active: activeTabIndex == 14,
                onTap: () => _pushAdmin(context, const AdminReportsScreen()),
              ),
              _WorkspaceNavItem(
                icon: Icons.security_rounded,
                label: 'Tracking',
                active: activeTabIndex == 15,
                onTap: () => _pushAdmin(context, const AdminTrackingScreen()),
              ),
                ],
              ]),
            ),
          ),

          // ── Footer branding ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 8),
                Text(
                  'v1.0.0 Stable',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Internal nav item ────────────────────────────────────────────────────────
class _WorkspaceNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badgeCount;
  final VoidCallback onTap;

  const _WorkspaceNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: active ? _kTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active ? [
              BoxShadow(
                color: _kTeal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? Colors.white : _kMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? Colors.white : _kSlate,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withOpacity(0.2) : const Color(0xFFE11D48),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}