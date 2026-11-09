import 'dart:math' as math;
import 'package:flutter/material.dart';

const rewardRose = Color(0xFFAD7472);
const rewardInk = Color(0xFF10222E);
const rewardMuted = Color(0xFF67717A);
const rewardBorder = Color(0xFFF0DCD6);
const rewardBackground = Color(0xFFFCF7F4);

IconData rewardIcon(String category) => switch (category) {
  'dining' => Icons.restaurant_outlined,
  'photo' => Icons.photo_camera_outlined,
  'ticket' => Icons.confirmation_number_outlined,
  _ => Icons.shopping_bag_outlined,
};

class RewardsBackground extends StatelessWidget {
  final Widget child;
  const RewardsBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: rewardBackground)),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 350,
        child: IgnorePointer(
          child: Opacity(
            opacity: .26,
            child: Image.asset(
              'assets/images/Background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                rewardBackground.withValues(alpha: .25),
                rewardBackground.withValues(alpha: .9),
                rewardBackground,
              ],
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class RewardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const RewardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: rewardBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0E654C47),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class RewardCircle extends StatelessWidget {
  final String category;
  final double size;
  const RewardCircle(this.category, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) =>
      ['dining', 'shopping', 'photo'].contains(category)
      ? SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/images/rewards/$category.png',
            fit: BoxFit.contain,
          ),
        )
      : Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFFF8ECE7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            rewardIcon(category),
            color: rewardRose,
            size: size * .55,
          ),
        );
}

class RewardStatus extends StatelessWidget {
  final String status;
  const RewardStatus(this.status, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      border: Border.all(
        color: status == 'Available' ? rewardRose : rewardMuted,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      status,
      style: TextStyle(
        fontSize: 11,
        color: status == 'Available' ? rewardRose : rewardMuted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class RewardButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  const RewardButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.outlined = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    width: double.infinity,
    child: outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: rewardRose,
              side: const BorderSide(color: rewardRose),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(label),
          )
        : FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: rewardRose,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE1CDCA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(label),
          ),
  );
}

class RewardTabs extends StatelessWidget {
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool segmented;
  const RewardTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.segmented = false,
  });
  @override
  Widget build(BuildContext context) {
    final items = labels
        .map(
          (label) => Padding(
            padding: EdgeInsets.only(right: segmented ? 0 : 10),
            child: Semantics(
              selected: label == selected,
              child: TextButton(
                onPressed: () => onChanged(label),
                style: TextButton.styleFrom(
                  foregroundColor: label == selected ? Colors.white : rewardInk,
                  backgroundColor: label == selected
                      ? rewardRose
                      : (segmented ? Colors.transparent : Colors.white),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 19,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(segmented ? 8 : 30),
                    side: BorderSide(
                      color: segmented || label == selected
                          ? Colors.transparent
                          : rewardRose,
                    ),
                  ),
                ),
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ),
        )
        .toList();
    return segmented
        ? Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: rewardBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: items.map((item) => Expanded(child: item)).toList(),
            ),
          )
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: items),
          );
  }
}

class CouponSurface extends StatelessWidget {
  final Widget child;
  const CouponSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CouponPainter(),
    child: ClipPath(
      clipper: _CouponClipper(),
      child: ColoredBox(
        color: Colors.white,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

Path _couponPath(Size size) {
  var path = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
    );
  for (double y = 18; y < size.height - 12; y += 15) {
    for (final x in [0.0, size.width]) {
      path = Path.combine(
        PathOperation.difference,
        path,
        Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: 2)),
      );
    }
  }
  for (final y in [0.0, size.height]) {
    path = Path.combine(
      PathOperation.difference,
      path,
      Path()..addOval(
        Rect.fromCircle(center: Offset(size.width * .68, y), radius: 7),
      ),
    );
  }
  return path;
}

class _CouponClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _couponPath(size);
  @override
  bool shouldReclip(_CouponClipper oldClipper) => false;
}

class _CouponPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    _couponPath(size),
    Paint()
      ..color = rewardBorder
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke,
  );
  @override
  bool shouldRepaint(_CouponPainter oldDelegate) => false;
}

class RewardDashes extends StatelessWidget {
  final bool vertical;
  const RewardDashes({super.key, this.vertical = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: vertical ? const Size(1, 112) : const Size(double.infinity, 1),
    painter: _Dashes(vertical),
  );
}

class _Dashes extends CustomPainter {
  final bool vertical;
  const _Dashes(this.vertical);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = rewardBorder
      ..strokeWidth = 1;
    final length = vertical ? size.height : size.width;
    for (double n = 0; n < length; n += 8) {
      canvas.drawLine(
        vertical ? Offset(0, n) : Offset(n, 0),
        vertical
            ? Offset(0, math.min(n + 4, length))
            : Offset(math.min(n + 4, length), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Dashes oldDelegate) => oldDelegate.vertical != vertical;
}
