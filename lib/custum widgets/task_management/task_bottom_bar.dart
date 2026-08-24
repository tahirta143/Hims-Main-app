import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'task_primitives.dart';

class TaskFluidBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final int unreadCount;
  final Function(int) onItemSelected;

  const TaskFluidBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.unreadCount = 0,
  });

  @override
  State<TaskFluidBottomNavBar> createState() => _TaskFluidBottomNavBarState();
}

class _TaskFluidBottomNavBarState extends State<TaskFluidBottomNavBar>
    with TickerProviderStateMixin {
  static const Color _primary = TaskColors.medicalAccent;
  static const Color _primaryDark = TaskColors.medicalAccentDark;

  final List<_TaskNavItemDef> _items = [
    const _TaskNavItemDef(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    const _TaskNavItemDef(icon: Icons.view_kanban_rounded, label: 'Board'),
    const _TaskNavItemDef(icon: Icons.chat_bubble_rounded, label: 'Chat'),
    const _TaskNavItemDef(icon: Icons.trending_up_rounded, label: 'Progress'),
  ];

  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnims;
  AnimationController? _slideController;
  Animation<double>? _slideAnim;
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex.clamp(0, _items.length - 1);
    _initAnimations(widget.currentIndex.clamp(0, _items.length - 1));
  }

  @override
  void didUpdateWidget(TaskFluidBottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _animateSelectionChange(old.currentIndex);
    }
  }

  void _animateSelectionChange(int oldIndex) {
    final newIndex = widget.currentIndex.clamp(0, _items.length - 1);
    final safeOldIndex = oldIndex.clamp(0, _items.length - 1);

    if (safeOldIndex < _controllers.length) _controllers[safeOldIndex].reverse();
    if (newIndex < _controllers.length) _controllers[newIndex].forward();

    _prevIndex = safeOldIndex;

    _slideController?.stop();
    _slideController?.reset();
    _slideController?.forward();
  }

  void _initAnimations(int initialIndex) {
    _controllers = List.generate(
      _items.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );
    _scaleAnims = _controllers
        .map(
          (c) => Tween<double>(begin: 1.0, end: 1.12).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOutBack),
          ),
        )
        .toList();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic,
    );

    if (initialIndex < _controllers.length) {
      _controllers[initialIndex].forward();
    }
    _slideController!.value = 1.0;
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _slideController?.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.lightImpact();
    widget.onItemSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double itemWidth = width / _items.length;
    const double barHeight = 68.0;
    const double floatOffset = 18.0;
    const double circleSize = 44.0;

    return AnimatedBuilder(
      animation: _slideAnim!,
      builder: (_, _) {
        final double fromX = _prevIndex * itemWidth + itemWidth / 2;
        final double toX = widget.currentIndex.clamp(0, _items.length - 1) * itemWidth + itemWidth / 2;
        final double notchX = fromX + (toX - fromX) * _slideAnim!.value;

        return Container(
          color: Colors.transparent,
          height: barHeight + floatOffset + 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBar(notchX, itemWidth, barHeight, width),
              ),
              Positioned(
                left: notchX - circleSize / 2,
                top: 0,
                child: _buildFloatingCircle(circleSize),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBar(double notchX, double itemWidth, double barHeight, double width) {
    return ClipPath(
      clipper: _TaskNavClipper(notchCenterX: notchX),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: List.generate(
                _items.length,
                (i) => _buildItem(i, itemWidth),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCircle(double size) {
    final idx = widget.currentIndex.clamp(0, _items.length - 1);
    return AnimatedBuilder(
      animation: _controllers[idx],
      builder: (_, _) {
        return ScaleTransition(
          scale: _scaleAnims[idx],
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primary, _primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: _buildIcon(idx, Colors.white, 20),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(int index, double itemWidth) {
    final item = _items[index];
    final isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => _onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isSelected ? 0.0 : 1.0,
              child: _buildIcon(index, Colors.grey.shade400, 22),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primary : Colors.grey.shade400,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(int index, Color color, double size) {
    final icon = _items[index].icon;
    if (index == 2 && widget.unreadCount > 0) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color, size: size),
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Text(
                widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return Icon(icon, color: color, size: size);
  }
}

class _TaskNavClipper extends CustomClipper<Path> {
  final double notchCenterX;
  const _TaskNavClipper({required this.notchCenterX});

  @override
  Path getClip(Size size) {
    const double notchRadius = 32.0;
    const double notchDepth = 20.0;
    const double spread = 44.0;
    const double topRadius = 18.0;

    final cx = notchCenterX;
    final path = Path();
    path.moveTo(0, topRadius);
    path.quadraticBezierTo(0, 0, topRadius, 0);
    path.lineTo(cx - spread, 0);
    path.cubicTo(cx - spread + 10, 0, cx - notchRadius, notchDepth, cx, notchDepth);
    path.cubicTo(cx + notchRadius, notchDepth, cx + spread - 10, 0, cx + spread, 0);
    path.lineTo(size.width - topRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, topRadius);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_TaskNavClipper old) => old.notchCenterX != notchCenterX;
}

class _TaskNavItemDef {
  final IconData icon;
  final String label;
  const _TaskNavItemDef({required this.icon, required this.label});
}
