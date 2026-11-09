import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'admin_models.dart';

const adminRose = Color(0xFFC97679),
    adminDark = Color(0xFF18252F),
    adminMuted = Color(0xFF7A8089),
    adminBorder = Color(0xFFEAE3E1),
    adminBackground = Color(0xFFFFFCFB);

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: adminBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 9,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class AdminButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  const AdminButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return SizedBox(
      height: 42,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: adminRose,
                side: const BorderSide(color: adminRose),
                shape: shape,
                textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 13),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: adminRose,
                foregroundColor: Colors.white,
                shape: shape,
                textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: child,
            ),
    );
  }
}

class AdminStat extends StatelessWidget {
  final String label, value, caption;
  final IconData icon;
  final Color color;
  const AdminStat(
    this.label,
    this.value,
    this.caption,
    this.icon, {
    super.key,
    this.color = adminRose,
  });
  @override
  Widget build(BuildContext context) => AdminCard(
    child: Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .09),
          ),
          child: Icon(icon, color: color, size: 29),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: adminMuted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: const TextStyle(fontSize: 11, color: adminMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AdminStats extends StatelessWidget {
  final List<Widget> children;
  const AdminStats({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final child in children)
          SizedBox(
            width:
                (c.maxWidth -
                    16 *
                        ((c.maxWidth >= 1000
                                ? 4
                                : c.maxWidth >= 620
                                ? 2
                                : 1) -
                            1)) /
                (c.maxWidth >= 1000
                    ? 4
                    : c.maxWidth >= 620
                    ? 2
                    : 1),
            child: child,
          ),
      ],
    ),
  );
}

class AdminBadge extends StatelessWidget {
  final String label;
  final String? tone;
  const AdminBadge(this.label, {super.key, this.tone});
  @override
  Widget build(BuildContext context) {
    final key = (tone ?? label).toLowerCase();
    final color =
        ['active', 'normal', 'confirmed', 'accepted', 'valid'].contains(key)
        ? const Color(0xFF278D52)
        : ['suspended', 'archived', 'high', 'used', 'expired'].contains(key)
        ? const Color(0xFFD4545D)
        : ['gold', 'review', 'watchlisted', 'pending'].contains(key)
        ? const Color(0xFFCC8B27)
        : adminMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AdminAvatar extends StatelessWidget {
  final String name, photo;
  final double radius;
  const AdminAvatar(this.name, {super.key, this.photo = '', this.radius = 20});
  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    try {
      if (photo.isNotEmpty) image = MemoryImage(base64Decode(photo));
    } catch (_) {
      image = null;
    }
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFF4E3E0),
      foregroundColor: adminRose,
      backgroundImage: image,
      child: image == null
          ? Text(
              initials,
              style: TextStyle(
                fontSize: radius * .65,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

class AdminHeading extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const AdminHeading(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 560
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(subtitle, style: const TextStyle(color: adminMuted)),
              if (action != null) ...[const SizedBox(height: 14), action!],
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      style: const TextStyle(color: adminMuted, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ?action,
            ],
          ),
  );
}

class AdminSelect extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final double width;
  const AdminSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 150,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
    ),
  );
}

class AdminEmpty extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const AdminEmpty(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 42, color: adminRose),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: adminMuted, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}

class AdminTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double minWidth;
  final int? sortColumnIndex;
  final bool sortAscending;
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 1050,
    this.sortColumnIndex,
    this.sortAscending = true,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: c.maxWidth > minWidth ? c.maxWidth : minWidth,
        ),
        child: DataTable(
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          showCheckboxColumn: false,
          columnSpacing: 20,
          horizontalMargin: 16,
          headingRowHeight: 48,
          dataRowMinHeight: 72,
          dataRowMaxHeight: 82,
          headingTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: adminDark,
          ),
          dataTextStyle: const TextStyle(fontSize: 12, color: adminDark),
          dividerThickness: .5,
          columns: columns,
          rows: rows,
        ),
      ),
    ),
  );
}

Future<void> exportAdminCsv(
  BuildContext context,
  String file,
  List<String> headers,
  List<List<Object?>> rows,
) async {
  try {
    await FilePicker.saveFile(
      fileName: file,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csvContent(headers, rows))),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to export this file. Please try again.'),
        ),
      );
    }
  }
}
