import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? hintText;
  final TextStyle? hintStyle;
  final TextStyle? style;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool? filled;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final bool? autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const CustomTextField({
    super.key,
    this.controller,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.maxLines = 1,
    this.hintText,
    this.hintStyle,
    this.style,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.focusNode,
    this.filled,
    this.fillColor,
    this.contentPadding,
    this.enabledBorder,
    this.focusedBorder,
    this.autofocus = false,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: autofocus ?? false,
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      focusNode: focusNode,
      style: style,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: filled,
        fillColor: fillColor,
        contentPadding: contentPadding,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        counterText: '',
      ),
    );
  }
}
