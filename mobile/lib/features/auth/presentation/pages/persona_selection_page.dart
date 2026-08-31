import 'package:flutter/material.dart';

// --- Veri Modeli ---
class PersonaOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  PersonaOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });
}

// --- Ana Ekran ---
class PersonaSelectionScreen extends StatefulWidget {
  const PersonaSelectionScreen({super.key});

  @override
  State<PersonaSelectionScreen> createState() => _PersonaSelectionScreenState();
}

class _PersonaSelectionScreenState extends State<PersonaSelectionScreen> {
  String? _selectedPersonaId = 'remote_worker'; // Görseldeki gibi varsayılan seçili

  final List<PersonaOption> _personas = [
    PersonaOption(
      id: 'student',
      title: 'Öğrenci',
      description: 'Ulaşım, üniversite ve sosyal yaşam öncelikli',
      icon: Icons.school_outlined,
    ),
    PersonaOption(
      id: 'remote_worker',
      title: 'Uzaktan Çalışan',
      description: 'Sakin çevre, günlük ihtiyaçlar ve sosyal alanlar öncelikli',
      icon: Icons.laptop_mac,
    ),
    PersonaOption(
      id: 'family',
      title: 'Çocuklu Aile',
      description: 'Eğitim, sağlık, parklar ve güvenli yaşam alanları öncelikli',
      icon: Icons.family_restroom,
    ),
    PersonaOption(
      id: 'retiree',
      title: 'Emekli',
      description: 'Sağlık, günlük ihtiyaçlar ve sakin yaşam öncelikli',
      icon: Icons.nature_people_outlined,
    ),
  ];

  // Renk Paleti (Görselden referansla)
  final Color _bgColor = const Color(0xFFFAF7F2);
  final Color _brandColor = const Color(0xFFC76A36);
  final Color _textColor = const Color(0xFF4A443F);
  final Color _cardBgColor = const Color(0xFFF3EFE9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _brandColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Seni biraz tanıyalım',
          style: TextStyle(
            color: _brandColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yaşam tarzına en yakın profili seç. Tercihlerini daha sonra değiştirebilirsin.',
                      style: TextStyle(
                        color: _textColor.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Persona Kartları
                    ..._personas.map((persona) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _PersonaCard(
                            persona: persona,
                            isSelected: _selectedPersonaId == persona.id,
                            brandColor: _brandColor,
                            cardBgColor: _cardBgColor,
                            textColor: _textColor,
                            onTap: () {
                              setState(() {
                                _selectedPersonaId = persona.id;
                              });
                            },
                          ),
                        )),
                    
                    const SizedBox(height: 16),
                    
                    // Özelleştirme Ayracı
                    Row(
                      children: [
                        Expanded(child: Divider(color: _brandColor.withOpacity(0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'Kendim Özelleştireceğim',
                            style: TextStyle(
                              color: _brandColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: _brandColor.withOpacity(0.3))),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Alt Butonlar
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: _bgColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Geri',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Seçilen ID'yi (_selectedPersonaId) kaydet ve sonraki ekrana geç
                      debugPrint('Seçilen Persona: $_selectedPersonaId');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Devam Et',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Özel Kart Widget'ı ---
class _PersonaCard extends StatelessWidget {
  final PersonaOption persona;
  final bool isSelected;
  final Color brandColor;
  final Color cardBgColor;
  final Color textColor;
  final VoidCallback onTap;

  const _PersonaCard({
    required this.persona,
    required this.isSelected,
    required this.brandColor,
    required this.cardBgColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: isSelected ? brandColor.withOpacity(0.05) : cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? brandColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İkon Kutusu
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? brandColor.withOpacity(0.2) 
                        : Colors.black.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    persona.icon,
                    color: isSelected ? brandColor : textColor.withOpacity(0.7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Metinler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.title,
                        style: TextStyle(
                          color: isSelected ? brandColor : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        persona.description,
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Sağ üstteki tik işareti
          if (isSelected)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: brandColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}