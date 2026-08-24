import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_management/task_workspace_provider.dart';
import '../../screens/home/home_screen.dart';
import 'task_primitives.dart';

class TaskAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool showDrawerTrigger;

  const TaskAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.scaffoldKey,
    this.showDrawerTrigger = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  void _handleBack(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<TaskWorkspaceProvider>();
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [TaskColors.medicalAccent, TaskColors.medicalAccentDark],
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
          // Hamburger or Back button
          if (showDrawerTrigger && scaffoldKey != null)
            GestureDetector(
              onTap: () => scaffoldKey!.currentState?.openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
              ),
            )
          else
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
              ),
            ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (workspace.me != null)
                  Text(
                    '${workspace.me!.name}${workspace.me!.departmentName != null ? ' · ${workspace.me!.departmentName}' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          if (action != null) ...[
            action!,
            const SizedBox(width: 8),
          ],

          // Back to HIMS button
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
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
