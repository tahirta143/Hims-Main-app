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
import 'package:hims_app/custum%20widgets/task_management/task_app_bar.dart';
import 'package:hims_app/custum%20widgets/task_management/task_bottom_bar.dart';

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
                        color: TaskColors.medicalAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: TaskColors.medicalAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Administration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TaskColors.slateText)),
                        Text('Manage tasks, projects & people', style: TextStyle(fontSize: 11, color: TaskColors.slateMuted)),
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
              child: Icon(icon, color: TaskColors.medicalAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TaskColors.slateText)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: TaskColors.slateMuted)),
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

    if (!workspace.ready) {
      return Scaffold(
        backgroundColor: TaskColors.bgSurface,
        body: const Center(child: CircularProgressIndicator(color: TaskColors.medicalAccent)),
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
          backgroundColor: TaskColors.bgSurface,
          appBar: TaskAppBar(
            title: 'Task Management',
            scaffoldKey: _scaffoldKey,
          ),
          drawer: TaskWorkspaceDrawer(
            activeTabIndex: _currentIndex,
            unreadCount: unread,
            isAdmin: isAdmin,
            onTabSelected: (index) => setState(() => _currentIndex = index),
          ),
          body: WorkspaceBlockedView(
            blocked: workspace.blocked!,
            onBack: () => _handleBack(context),
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
        backgroundColor: TaskColors.bgSurface,
        appBar: TaskAppBar(
          title: 'Task Management',
          scaffoldKey: _scaffoldKey,
          // action: isAdmin
          //     ? IconButton(
          //         onPressed: _openAdminMenu,
          //         icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 24),
          //       )
          //     : null,
        ),
        drawer: TaskWorkspaceDrawer(
          activeTabIndex: _currentIndex,
          unreadCount: unread,
          isAdmin: isAdmin,
          onTabSelected: (index) => setState(() => _currentIndex = index),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: TaskFluidBottomNavBar(
          currentIndex: _currentIndex,
          unreadCount: unread,
          onItemSelected: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}
