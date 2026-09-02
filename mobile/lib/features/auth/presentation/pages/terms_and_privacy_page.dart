import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Kullanım koşulları ve gizlilik metni.
///
/// ⚠️ Bu sayfanın İKİ kopyası vardı: biri burada (hiç kullanılmıyordu),
/// biri `register_page.dart`'ın altında (kullanılan). İkisi de aynı metni
/// taşıyordu ama biri güncellenirse diğeri geride kalacaktı. Tek kopya
/// burada; kayıt ekranı bunu içe aktarıyor.
class TermsAndPrivacyPage extends StatelessWidget {
  const TermsAndPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Koşullar ve gizlilik')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xs,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          children: const [
            _Section(
              title: 'Kullanım koşulları',
              body:
                  'Vivido üzerinden sunulan hizmetleri kullanarak bu '
                  'koşulları kabul etmiş sayılırsın. Uygulamadaki harita '
                  'verileri ve konut bilgileri bilgilendirme amaçlıdır.',
            ),
            _Section(
              title: 'Konut verisi',
              body:
                  'Uygulamadaki konut ilanları GERÇEK DEĞİL, sentetik olarak '
                  'üretilmiştir ve arayüzde her yerde bu şekilde '
                  'etiketlenmiştir. Kiralama kararı için kullanılamaz.',
            ),
            _Section(
              title: 'Gizlilik',
              body:
                  'Kişisel verilerin (e-posta, ad, soyad) güvenli biçimde '
                  'saklanır ve üçüncü kişilerle paylaşılmaz. Konum bilgin '
                  'yalnızca izin verdiğinde, harita ve navigasyon amacıyla '
                  'kullanılır; sunucuda saklanmaz.',
            ),
            _Section(
              title: 'Harita verisi',
              body:
                  'Harita verisi © OpenStreetMap katkıcıları — ODbL 1.0 '
                  'lisansıyla kullanılmaktadır.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.h3.copyWith(color: AppColors.accent)),
        const SizedBox(height: 4),
        Text(body, style: AppType.sm.copyWith(height: 1.6)),
      ],
    ),
  );
}
