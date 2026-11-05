
import 'package:flutter/material.dart';

class VisitorBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const VisitorBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const Color selectedColor = Color(0xFFAD7472);
  static const Color unselectedColor = Color(0xFF888888);

  static const List<String> _labels = [
    'Home',
    'Tickets',
    'Map',
    'Queue',
    'Profile',
  ];

  static const List<String> _icons = [
    'home',
    'tickets',
    'map',
    'queue',
    'profile',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // White navigation background
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFF0E5E0),
                    ),
                  ),
                ),
              ),
            ),

            // Five navigation items
            Positioned.fill(
              child: Row(
                children: List.generate(_labels.length, (index) {
                  final isSelected = selectedIndex == index;

                  final iconPath =
                      'assets/icons/navigation/${_icons[index]}'
                      '${isSelected ? '_selected' : ''}.png';

                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (index == 2)
                            Container(
                              width: 62,
                              height: 62,
                              decoration: const BoxDecoration(
                                color: Color(0xFFAD7472),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/icons/navigation/map.png',
                                width: 34,
                                height: 34,
                                fit: BoxFit.contain,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Image.asset(
                                iconPath,
                                width: 26,
                                height: 26,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                const Icon(
                                  Icons.broken_image_outlined,
                                ),
                              ),
                            ),

                          const SizedBox(height: 6),

                          Text(
                            _labels[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? selectedColor
                                  : unselectedColor,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),

                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
