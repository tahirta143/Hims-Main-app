import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../custum widgets/task_management/task_primitives.dart';
import '../../custum widgets/task_management/workspace_blocked_view.dart';
import '../../custum widgets/task_management/task_workspace_drawer.dart';
import '../../providers/task_management/task_workspace_provider.dart';
import 'admin/admin_people_screen.dart';
import 'admin/admin_projects_screen.dart';
import 'admin/admin_reports_screen.dart';
import 'admin/admin_scores_screen.dart';
import 'admin/admin_tasks_screen.dart';
import 'admin/admin_tracking_screen.dart';
import 'tabs/task_board_tab.dart';
import 'tabs/task_chat_list_tab.dart';
import 'tabs/task_dashboard_tab.dart';
import 'tabs/task_progress_tab.dart';
import '../home/home_screen.dart';

const Color _kTeal      = Color(0xFF00B5AD);
const Color _kTealDark  = Color(0xFF0D9488);
const Color _kSlate     = Color(0xFF334155);
const Color _kMuted     = Color(0xFF64748B);
const Color _kBg        = Color(0xFFF8FAFC);

class TaskWorkspaceScreen extends StatefulWidget {
  final int initialTabIndex;
  const TaskWorkspaceScreen({super.key, this.initialTabIndex = 0});
  @override
  State<TaskWorkspaceScreen> createState() => _TaskWorkspaceScreenState();
}

class _TaskWorkspaceScreenState extends State<TaskWorkspaceScreen> {
  late int _currentIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _handleBack(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskWorkspaceProvider>().initializeWorkspace();
    });
  }

  void _openAdminMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _kTeal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: _kTeal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kSlate)),
                        Text('Manage tasks, projects & people', style: TextStyle(fontSize: 11, color: _kMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _adminTile(Icons.assignment_outlined, 'All Tasks', 'Master task list & status',
                  () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTasksScreen())); }),
              _adminTile(Icons.business_rounded, 'Projects', 'Manage project workspaces',
                  () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProjectsScreen())); }),
              _adminTile(Icons.people_outline_rounded, 'People', 'Users, roles & departments',
                  () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPeopleScreen())); }),
              _adminTile(Icons.bar_chart_rounded, 'Appraisals', 'Scores & performance reviews',
                  () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScoresScreen())); }),
              _adminTile(Icons.radar_rounded, 'Reports', 'Analytics & AI suggestions',
                  () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsScreen())); }),
              _adminTile(Icons.security_rounded, 'Tracking', 'Activity & audit logs',
                  () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTrackingScreen())); }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adminTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: const Color(0xFFF0FDFA), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: _kTeal, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kSlate)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: _kMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final isAdmin = workspace.me?.isAdmin ?? false;
    final unread = workspace.unreadCount;
    final topPad = MediaQuery.of(context).padding.top;

    if (!workspace.ready) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: _kBg,
        body: Column(
          children: [
            _buildHeader(context, topPad, workspace, isAdmin, loading: true),
            const Expanded(child: Center(child: CircularProgressIndicator(color: _kTeal))),
          ],
        ),
      );
    }

    if (workspace.isBlocked) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _handleBack(context);
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: _kBg,
          drawer: TaskWorkspaceDrawer(
            activeTabIndex: _currentIndex,
            unreadCount: unread,
            isAdmin: isAdmin,
            onTabSelected: (index) => setState(() => _currentIndex = index),
          ),
          body: Column(
            children: [
              _buildHeader(context, topPad, workspace, isAdmin),
              Expanded(
                child: WorkspaceBlockedView(
                  blocked: workspace.blocked!,
                  onBack: () => _handleBack(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pages = [
      TaskDashboardTab(onOpenBoard: () => setState(() => _currentIndex = 1)),
      const TaskBoardTab(),
      const TaskChatListTab(),
      const TaskProgressTab(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: _kBg,
        drawer: TaskWorkspaceDrawer(
          activeTabIndex: _currentIndex,
          unreadCount: unread,
          isAdmin: isAdmin,
          onTabSelected: (index) => setState(() => _currentIndex = index),
        ),
        body: Column(
          children: [
            _buildHeader(context, topPad, workspace, isAdmin),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(unread),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    double topPad,
    TaskWorkspaceProvider workspace,
    bool isAdmin, {
    bool loading = false,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kTeal, _kTealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(top: topPad + 12, left: 16, right: 16, bottom: 20),
      child: Row(
        children: [
          // Hamburger — opens the drawer
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Task Management', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (!loading && workspace.me != null)
                  Text(
                    '${workspace.me!.name}'
                    '${workspace.me!.departmentName != null ? ' · ${workspace.me!.departmentName}' : ''}',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Back to HIMS button (right side)
          GestureDetector(
            onTap: () => _handleBack(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Back to HIMS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openAdminMenu,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 22),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomNav(int unread) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: _kTeal,
        unselectedItemColor: _kMuted,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.view_kanban_outlined), activeIcon: Icon(Icons.view_kanban_rounded), label: 'Board'),
          BottomNavigationBarItem(icon: _chatIcon(false, unread), activeIcon: _chatIcon(true, unread), label: 'Chat'),
          const BottomNavigationBarItem(icon: Icon(Icons.trending_up_outlined), activeIcon: Icon(Icons.trending_up_rounded), label: 'Progress'),
        ],
      ),
    );
  }

  Widget _chatIcon(bool active, int unread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded),
        if (unread > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}