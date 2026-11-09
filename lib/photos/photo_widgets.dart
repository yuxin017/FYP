import 'dart:convert';
import 'package:flutter/material.dart';
import '../visitor/widgets/visitor_bottom_nav.dart';
import '../visitor/visitor_main_page.dart';
import 'photo_repository.dart';
import 'photo_session_scope.dart';

const photoRose = Color(0xFFAD7472),
    photoInk = Color(0xFF18252F),
    photoBackground = Color(0xFFFCF7F5),
    photoBorder = Color(0xFFEADBD7);

class PhotoFrame extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final String helpTitle, helpText;
  final bool busy;
  final int selectedIndex;
  const PhotoFrame({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.helpTitle = 'Your park memories',
    this.helpText =
        'Set up optional face matching or enter the photographer’s photo code to find your photos. Preview and edit your favorites, then choose digital copies, printed photos or a bundle. Purchased digital photos can be downloaded from Photo Purchase History. Printed orders include a collection pass for the photo kiosk.',
    this.busy = false,
    this.selectedIndex = 4,
  });
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: photoRose,
        primary: photoRose,
        surface: Colors.white,
      ),
    ),
    child: ColoredBox(
      color: photoBackground,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: PopScope(
            canPop: !busy,
            child: Scaffold(
              backgroundColor: photoBackground,
              appBar: AppBar(
                backgroundColor: photoBackground,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                leading: BackButton(
                  color: photoRose,
                  onPressed: busy
                      ? null
                      : () async {
                          if (Navigator.canPop(context)) {
                            await Navigator.maybePop(context);
                          } else {
                            await PhotoSessionScope.of(context)?.finish(null);
                          }
                        },
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: photoInk,
                  ),
                ),
                actions: actions.isNotEmpty
                    ? actions
                    : [
                        IconButton(
                          tooltip: '$title help',
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(helpTitle),
                              content: Text(helpText),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          ),
                          icon: const Icon(
                            Icons.help_outline,
                            color: photoRose,
                          ),
                        ),
                      ],
              ),
              body: body,
              bottomNavigationBar: PhotoSessionScope.of(context) != null
                  ? SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : () =>
                                    PhotoSessionScope.of(context)!.finish(null),
                          icon: const Icon(Icons.logout),
                          label: const Text('End My Kiosk Session'),
                        ),
                      ),
                    )
                  : VisitorBottomNav(
                      selectedIndex: selectedIndex,
                      onTap: busy
                          ? (_) {}
                          : (index) {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                              VisitorMainPage.goTo(context, index);
                            },
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PhotoPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const PhotoPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: photoBorder.withValues(alpha: .65)),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 12,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class PhotoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined, busy;
  final IconData? icon;
  const PhotoButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.outlined = false,
    this.busy = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 21),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return outlined
        ? OutlinedButton(
            style: style,
            onPressed: busy ? null : onPressed,
            child: child,
          )
        : FilledButton(
            style: style,
            onPressed: busy ? null : onPressed,
            child: child,
          );
  }
}

class PhotoImage extends StatelessWidget {
  final String encoded;
  final double? width, height;
  final BoxFit fit;
  final double radius;
  const PhotoImage(
    this.encoded, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius = 12,
  });
  @override
  Widget build(BuildContext context) {
    Widget image;
    try {
      image = Image.memory(
        base64Decode(encoded),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, error, stack) => missing(),
      );
    } catch (_) {
      image = missing();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }

  Widget missing() => Container(
    width: width,
    height: height ?? 120,
    color: const Color(0xFFF0E7E3),
    child: const Icon(Icons.image_outlined, size: 35, color: photoRose),
  );
}

class PhotoTile extends StatelessWidget {
  final ParkPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  const PhotoTile({
    super.key,
    required this.photo,
    required this.onTap,
    this.onFavorite,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: PhotoPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoImage(photo.preview, radius: 12),
                if (onFavorite != null)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: IconButton.filledTonal(
                      tooltip: 'Favorite photo',
                      onPressed: onFavorite,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .9),
                        minimumSize: const Size(30, 30),
                        padding: const EdgeInsets.all(5),
                      ),
                      icon: Icon(
                        photo.data['favorite'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: photoRose,
                        size: 19,
                      ),
                    ),
                  ),
                if (photo.confidence != null)
                  Positioned(
                    right: 7,
                    bottom: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${photo.confidence}% match',
                        style: const TextStyle(
                          fontSize: 9,
                          color: photoRose,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.place.isEmpty ? photo.title : photo.place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: photoInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  photo.takenAt == null
                      ? 'Park memories'
                      : '${photo.takenAt!.toLocal().hour.toString().padLeft(2, '0')}:${photo.takenAt!.toLocal().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
