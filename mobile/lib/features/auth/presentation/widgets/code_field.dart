import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 6 haneli doğrulama kodu alanı.
///
/// Tek alan, altı ayrı kutu değil: altı kutulu tasarım güzel görünür ama
/// yapıştırma, geri silme, otomatik doldurma ve ekran okuyucu davranışının
/// hepsini elle yazmayı gerektirir. Tek alan + `oneTimeCode` ipucu ile
/// klavye kodu kendisi önerebiliyor.
class CodeField extends StatelessWidget {
  const CodeField({
    required this.controller,
    required this.label,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      textAlign: TextAlign.center,
      maxLength: 6,
      // Yapıştırılan "123 456" 7 karakter; maxLength tek başına yetmez.
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: 10,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        hintText: '000000',
      ),
      onFieldSubmitted: onSubmitted,
      validator: (value) {
        if ((value ?? '').length != 6) return 'Kod 6 haneli olmalı.';
        return null;
      },
    );
  }
}
