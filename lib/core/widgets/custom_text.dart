import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final bool? softWrap;
  final TextDecoration? decoration;
  final double? letterSpacing;
  final double? wordSpacing;
  final double? height; // Added height for Figma line-height compatibility

  const CustomText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.softWrap,
    this.decoration,
    this.letterSpacing,
    this.wordSpacing,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? const TextStyle();

    return Text(
      text,
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap ?? true,
      style: baseStyle.copyWith(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        decoration: decoration,
        letterSpacing: letterSpacing,
        wordSpacing: wordSpacing,
        height: height,
      ),
    );
  }
}