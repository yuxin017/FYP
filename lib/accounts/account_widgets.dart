import 'package:flutter/material.dart';
import '../visitor/widgets/rewards_widgets.dart';
import '../visitor/widgets/visitor_bottom_nav.dart';
import '../visitor/visitor_main_page.dart';
import '../support/support_page.dart';

class AccountScaffold extends StatefulWidget {
  final String title;
  final Widget child;
  final bool dirty, busy, bottomNav, showHeaderTitle;
  const AccountScaffold({
    super.key,
    required this.title,
    required this.child,
    this.dirty = false,
    this.busy = false,
    this.bottomNav = true,
    this.showHeaderTitle = true,
  });
  @override
  State<AccountScaffold> createState() => _AccountScaffoldState();
}

class _AccountScaffoldState extends State<AccountScaffold> {
  bool allowed = false;
  Future<void> leave(VoidCallback action) async {
    if (widget.busy) return;
    if (widget.dirty && !allowed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => allowed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowed || (!widget.dirty && !widget.busy),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave(() => Navigator.pop(context));
    },
    child: ColoredBox(
      color: rewardBackground,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Scaffold(
            backgroundColor: rewardBackground,
            body: RewardsBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: widget.busy
                                ? null
                                : () =>
                                      leave(() => Navigator.maybePop(context)),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 19,
                              color: rewardRose,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.showHeaderTitle ? widget.title : '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: rewardInk,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Account help',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportPage(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.help_outline,
                              color: rewardRose,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        key: ValueKey(widget.title),
                        container: true,
                        explicitChildNodes: true,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: widget.bottomNav
                ? VisitorBottomNav(
                    selectedIndex: 4,
                    onTap: (index) => leave(() {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      VisitorMainPage.goTo(context, index);
                    }),
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

Widget accountHeading(String value) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(
    value,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: rewardInk,
    ),
  ),
);
Widget accountDescription(String value) => Text(
  value,
  style: const TextStyle(fontSize: 13, color: rewardMuted, height: 1.5),
);
Widget accountFailure(String? value) => value == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          value,
          style: const TextStyle(color: Color(0xFFAD444B), height: 1.4),
        ),
      );
InputDecoration accountInput(String hint, {Widget? suffix}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFF999495), fontSize: 14),
  suffixIcon: suffix,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFDCD7D4)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFDCD7D4)),
  ),
);

class AccountRow extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? badge;
  final VoidCallback? onTap;
  final bool danger;
  const AccountRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.badge,
    this.onTap,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 31,
            color: danger ? Colors.red.shade700 : rewardRose,
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: danger ? Colors.red.shade700 : rewardInk,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: rewardMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: rewardRose),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(fontSize: 10, color: rewardRose),
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: rewardRose),
          ],
        ],
      ),
    ),
  );
}

class AccountPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool underlined;
  const AccountPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.underlined = false,
  });
  @override
  State<AccountPasswordField> createState() => _AccountPasswordFieldState();
}

class _AccountPasswordFieldState extends State<AccountPasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: hidden,
    enableSuggestions: false,
    autocorrect: false,
    validator: widget.validator,
    decoration:
        accountInput(
          widget.label,
          suffix: IconButton(
            tooltip: hidden ? 'Show ${widget.label}' : 'Hide ${widget.label}',
            onPressed: () => setState(() => hidden = !hidden),
            icon: Icon(
              hidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: rewardRose,
            ),
          ),
        ).copyWith(
          filled: !widget.underlined,
          prefixIcon: widget.underlined ? const Icon(Icons.lock_outline) : null,
          border: widget.underlined ? const UnderlineInputBorder() : null,
          enabledBorder: widget.underlined
              ? const UnderlineInputBorder(
                  borderSide: BorderSide(color: rewardRose),
                )
              : null,
        ),
  );
}
