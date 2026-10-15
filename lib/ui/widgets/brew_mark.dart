import 'package:flutter/material.dart';

import '../../brand.dart';

/// Compact Brew wordmark with the original artwork kept uncropped.
class BrewMark extends StatelessWidget {
  const BrewMark({super.key, this.size = 20, this.lit = false, this.color});

  final double size;
  final bool lit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dot = size * 0.24;
    final iconSize = size * 1.35;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: Image.asset(
            'assets/images/brewicon.jpg',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.coffee_rounded,
              size: iconSize,
              color: color ?? scheme.primary,
            ),
          ),
        ),
        SizedBox(width: size * 0.3),
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
          padding: EdgeInsets.only(top: size * 0.08),
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
