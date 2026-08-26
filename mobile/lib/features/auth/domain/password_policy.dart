const strongPasswordRequirements =
    'En az 8 karakter; büyük harf, küçük harf, rakam ve özel karakter.';

bool isStrongPassword(String password) {
  return missingPasswordRequirements(password).isEmpty;
}

String? validateStrongPassword(String? password) {
  final missing = missingPasswordRequirements(password ?? '');
  if (missing.isEmpty) return null;
  if (missing.length == 1) return 'Parolada ${missing.single} eksik.';
  return 'Parolada şunlar eksik: ${missing.join(', ')}.';
}

List<String> missingPasswordRequirements(String password) {
  return [
    if (password.length < 8) 'en az 8 karakter',
    if (!RegExp('[A-Z]').hasMatch(password)) 'büyük harf',
    if (!RegExp('[a-z]').hasMatch(password)) 'küçük harf',
    if (!RegExp(r'\d').hasMatch(password)) 'rakam',
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password))
      'özel karakter (!, @, # gibi)',
  ];
}
