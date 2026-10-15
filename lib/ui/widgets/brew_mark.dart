import 'package:flutter/material.dart';

import '../../brand.dart';

/// Brew's uploaded brand artwork and wordmark.
class BrewMark extends StatelessWidget {
  const BrewMark({super.key, this.size = 20, this.lit = false, this.color});

  final double size;
  final bool lit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = size * 0.26;
    final iconSize = size * 1.25;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.asset(
            'brewicon.jpg',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.coffee_rounded,
              size: iconSize,
              color: color ?? scheme.primary,
            ),
          ),
        ),
        SizedBox(width: size * 0.32),
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
