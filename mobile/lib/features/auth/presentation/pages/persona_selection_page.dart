import 'package:flutter/material.dart';

class PersonaSelectionPage extends StatelessWidget {
  const PersonaSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persona Seçimi')),
      body: const Center(
        child: Text('Kayıt başarılı! Şimdi persona seçimi yapılacak...'),
      ),
    );
  }
}
