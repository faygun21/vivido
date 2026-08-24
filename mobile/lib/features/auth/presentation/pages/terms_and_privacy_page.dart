import 'package:flutter/material.dart';

class TermsAndPrivacyPage extends StatelessWidget {
  const TermsAndPrivacyPage({super.key});

  static const Color backgroundColor = Color(0xFFF9F4ED);
  static const Color primaryKiremit = Color(0xFFC0421D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryKiremit),
        title: const Text(
          'Kullanım Koşulları ve Gizlilik',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kullanım Koşulları',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryKiremit,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Bu uygulama (Vivido) üzerinden sunulan hizmetleri kullanarak aşağıdaki koşulları kabul etmiş sayılırsınız. Uygulama içerisindeki harita verileri ve konut bilgileri bilgilendirme amaçlıdır.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Gizlilik Sözleşmesi',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryKiremit,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Kişisel verileriniz (e-posta, ad, soyad vb.) güvenli bir şekilde saklanır ve üçüncü şahıslarla paylaşılmaz. Kayıt olarak veri güvenliği politikamızı onaylamış olursunuz.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
