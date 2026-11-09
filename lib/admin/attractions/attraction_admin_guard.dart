import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../attractions/widgets/attraction_widgets.dart';
import '../portal/admin_theme.dart';

/// The caller supplies verified account access. Database rules remain the
/// security boundary; hiding an editor never replaces server authorization.
class AttractionAdminGuard extends StatelessWidget {
  const AttractionAdminGuard({
    super.key,
    required this.access,
    required this.child,
  });
  final ValueListenable<bool> access;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: access,
    builder: (context, allowed, _) => allowed
        ? child
        : Scaffold(
            backgroundColor: AdminTheme.background,
            appBar: AppBar(
              title: const Text('Facility Management'),
              backgroundColor: AdminTheme.background,
            ),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: AttractionMessage(
                icon: Icons.lock_outline,
                title: 'Administrator access required',
                message:
                    'Your account does not have permission to manage park places.',
              ),
            ),
          ),
  );
}
