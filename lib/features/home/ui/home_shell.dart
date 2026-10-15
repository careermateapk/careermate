import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

const _tabs = [
  _Tab('Home', Icons.home_rounded),
  _Tab('Jobs', Icons.work_outline_rounded),
  _Tab('CV', Icons.description_outlined),
  _Tab('Tracker', Icons.view_kanban_outlined),
  _Tab('Prep', Icons.chat_bubble_outline_rounded),
];

/// Bottom navigation on phones, sidebar on wide screens (web/desktop/tablet).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(current: shell.currentIndex, onTap: _go),
          Expanded(child: shell),
        ]),
      );
    }
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [for (var i = 0; i < _tabs.length; i++) _NavItem(tab: _tabs[i], active: i == shell.currentIndex, onTap: () => _go(i))],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.active, required this.onTap});
  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.curve,
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: active ? 14 : 11),
          decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(15)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(tab.icon, size: 21, color: active ? AppColors.navy : const Color(0xFFA9B6D6)),
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.curve,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(tab.label, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 13)),
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppColors.navy,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const BrandLogo(size: 38),
          const SizedBox(width: 10),
          Text(AppConfig.appName, style: AppTheme.display(context, size: 19, color: Colors.white)),
        ]),
        const SizedBox(height: 28),
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: i == current ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTap(i),
                child: SizedBox(
                  height: 46,
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Icon(_tabs[i].icon, size: 20, color: i == current ? AppColors.navy : const Color(0xFFC9D3EA)),
                    const SizedBox(width: 12),
                    Text(_tabs[i].label,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: i == current ? AppColors.navy : const Color(0xFFC9D3EA))),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
