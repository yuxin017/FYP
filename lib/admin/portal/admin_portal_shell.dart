import 'package:flutter/material.dart';

import 'admin_theme.dart';

enum AdminPortalSection {
  attractions('Park Facilities', Icons.place_outlined),
  reservations('Reservations', Icons.event_note_outlined);

  const AdminPortalSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AdminPortalShell extends StatelessWidget {
  const AdminPortalShell({
    super.key,
    required this.child,
    required this.accountName,
    required this.onSignOut,
    required this.onRefreshAccess,
    required this.section,
    required this.onSelectSection,
  });
  final Widget child;
  final String accountName;
  final VoidCallback onSignOut;
  final VoidCallback onRefreshAccess;
  final AdminPortalSection section;
  final ValueChanged<AdminPortalSection> onSelectSection;

  Widget _sidebar({VoidCallback? closeDrawer}) => Container(
    width: 240,
    decoration: const BoxDecoration(
      color: Color(0xFFFFFAF8),
      border: Border(right: BorderSide(color: AdminTheme.border)),
    ),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Image.asset(
              'assets/images/Theme_Park_Main_Logo.png',
              width: 150,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 10, 24, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PARK OPERATIONS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.4,
                  color: AdminTheme.muted,
                ),
              ),
            ),
          ),
          for (final item in AdminPortalSection.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Material(
                color: item == section ? AdminTheme.rose : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  dense: true,
                  selected: item == section,
                  selectedColor: Colors.white,
                  leading: Icon(item.icon, size: 21),
                  title: Text(item.label),
                  onTap: () {
                    closeDrawer?.call();
                    onSelectSection(item);
                  },
                ),
              ),
            ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, size: 20),
            title: const Text('Sign out'),
            onTap: onSignOut,
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 11, color: AdminTheme.muted),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100;
      return Scaffold(
        drawer: wide
            ? null
            : Drawer(
                child: Builder(
                  builder: (context) =>
                      _sidebar(closeDrawer: Scaffold.of(context).closeDrawer),
                ),
              ),
        body: Row(
          children: [
            if (wide) _sidebar(),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 72,
                    padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AdminTheme.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Open navigation',
                              icon: const Icon(Icons.menu),
                              onPressed: () =>
                                  Scaffold.of(context).openDrawer(),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            'Park operations / ${section.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AdminTheme.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        PopupMenuButton<String>(
                          tooltip: 'Account options',
                          onSelected: (value) => value == 'sign-out'
                              ? onSignOut()
                              : onRefreshAccess(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'refresh',
                              child: Text('Refresh account access'),
                            ),
                            PopupMenuItem(
                              value: 'sign-out',
                              child: Text('Sign out'),
                            ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AdminTheme.rose,
                                child: Text(
                                  accountName.trim().isEmpty
                                      ? 'A'
                                      : accountName.trim()[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (constraints.maxWidth >= 600) ...[
                                const SizedBox(width: 12),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 210,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        accountName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Text(
                                        'Administrator',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AdminTheme.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down, size: 18),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
