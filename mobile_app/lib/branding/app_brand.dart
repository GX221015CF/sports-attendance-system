import 'package:flutter/material.dart';

abstract final class AppBrand {
  static const name = '队齐';
  static const description = '运动队签到';
  static const markAsset = 'assets/branding/duiqi.png';
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 54});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size / 4),
    child: Image.asset(
      AppBrand.markAsset,
      width: size,
      height: size,
      semanticLabel: AppBrand.name,
    ),
  );
}
