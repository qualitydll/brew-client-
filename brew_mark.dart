import 'package:flutter/material.dart';

import '../../brand.dart';

/// The "brew." wordmark. The dot lights up while connected.
class BrewMark extends StatelessWidget {
  const BrewMark({super.key, this.size = 20, this.lit = false, this.color});

  final double size;
  final bool lit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = size * 0.26;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          kAppName,
          style: TextStyle(
            fontFamily: kBrandFont,
            fontFamilyFallback: kBrandFallback,
            fontWeight: FontWeight.w700,
            fontSize: size,
            height: 1,
            letterSpacing: -0.6,
            color: color ?? scheme.onSurface,
          ),
        ),
        SizedBox(width: size * 0.06),
        Padding(
          padding: EdgeInsets.only(bottom: size * 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.55),
              boxShadow: [
                if (lit)
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.6),
                    blurRadius: dot * 1.6,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
