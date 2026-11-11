import 'package:flutter/material.dart';

class NevesAppIcon extends StatelessWidget {
  final double size;

  const NevesAppIcon({
    super.key,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    final s = size / 512.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 448 * s,
            height: 448 * s,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8FAFC),
                  Color(0xFFE2E8F0),
                ],
              ),
              borderRadius: BorderRadius.circular(104 * s),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12 * s,
                  offset: Offset(0, 4 * s),
                ),
              ],
            ),
          ),
          Container(
            width: 296 * s,
            height: 296 * s,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF10B981),
                  Color(0xFF047857),
                ],
              ),
              borderRadius: BorderRadius.circular(64 * s),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.28),
                  blurRadius: 20 * s,
                  offset: Offset(0, 14 * s),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 56 * s,
                  left: 44 * s,
                  right: 44 * s,
                  child: Container(
                    height: 36 * s,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA7F3D0).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14 * s),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 48 * s,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 132 * s,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
