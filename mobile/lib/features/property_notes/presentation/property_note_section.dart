import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/page_parts.dart';
import '../domain/property_note.dart';

/// Konut detayındaki "Kişisel notum" bölümü — web `PropertyDetailPanel`
/// içindeki `property-note-section`'ın karşılığı.
///
/// Üç durum: not yok (ekle daveti), okuma, düzenleme. Silme İKİ adımlı:
/// tek dokunuşla silinebilen bir not, yanlışlıkla kaybedilebilir bir şey.
class PropertyNoteSection extends StatefulWidget {
  const PropertyNoteSection({
    required this.propertyId,
    required this.gateway,
    super.key,
  });

  final String propertyId;
  final PropertyNoteGateway gateway;

  @override
  State<PropertyNoteSection> createState() => _PropertyNoteSectionState();
}

class _PropertyNoteSectionState extends State<PropertyNoteSection> {
  final _draft = TextEditingController();

  PropertyNote? _note;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  bool _confirmDelete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final note = await widget.gateway.getNote(widget.propertyId);
      if (mounted) setState(() => _note = note);
    } on PropertyNoteFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final value = _draft.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.gateway.saveNote(widget.propertyId, value);
      if (!mounted) return;
      setState(() {
        _note = saved;
        _editing = false;
      });
      showAppSnack(context, 'Notun kaydedildi.', tone: SnackTone.success);
    } on PropertyNoteFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.gateway.deleteNote(widget.propertyId);
      if (!mounted) return;
      setState(() {
        _note = PropertyNote(propertyId: widget.propertyId);
        _confirmDelete = false;
      });
    } on PropertyNoteFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _beginEdit() {
    _draft.text = _note?.note ?? '';
    setState(() {
      _editing = true;
      _confirmDelete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('KİŞİSEL NOTUM', style: AppType.micro),
            const SizedBox(width: 6),
            // Gizlilik notu görünür yerde: kullanıcı buraya bir şey
            // yazmadan önce kimin göreceğini bilmeli.
            Icon(Icons.lock_outline, size: 12, color: AppColors.inkMuted),
            const SizedBox(width: 3),
            Text(
              'yalnızca sen görürsün',
              style: AppType.muted(AppType.micro).copyWith(letterSpacing: 0),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.easeOut,
          alignment: Alignment.topCenter,
          child: _buildBody(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 15, color: AppColors.bad),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _error!,
                  style: AppType.xs.copyWith(color: AppColors.bad),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Tekrar dene')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Container(
        key: const ValueKey('loading'),
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      );
    }

    if (_editing) return _buildEditor();
    if (_note?.isEmpty ?? true) return _buildAddPrompt();
    return _buildReader();
  }

  Widget _buildAddPrompt() => OutlinedButton.icon(
    key: const ValueKey('add'),
    onPressed: _beginEdit,
    icon: const Icon(Icons.edit_note, size: 20),
    label: const Text('Not ekle'),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(46),
      foregroundColor: AppColors.inkMuted,
      side: BorderSide(color: AppColors.border),
    ),
  );

  Widget _buildReader() => Container(
    key: const ValueKey('read'),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
      4,
    ),
    decoration: BoxDecoration(
      // Kağıt hissi: kullanıcının kendi yazdığı metin, sistemin ürettiği
      // içerikten (beyaz kartlar) farklı bir zeminde duruyor.
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.accentEdge.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_note!.note!, style: AppType.sm.copyWith(height: 1.5)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_confirmDelete) ...[
              Text(
                'Silinsin mi?',
                style: AppType.muted(AppType.xs),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.bad),
                child: const Text('Evet, sil'),
              ),
              TextButton(
                onPressed:
                    _saving ? null : () => setState(() => _confirmDelete = false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                ),
                child: const Text('Vazgeç'),
              ),
            ] else ...[
              TextButton(onPressed: _beginEdit, child: const Text('Düzenle')),
              TextButton(
                onPressed: () => setState(() => _confirmDelete = true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.inkMuted,
                ),
                child: const Text('Sil'),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _buildEditor() => Column(
    key: const ValueKey('edit'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _draft,
        enabled: !_saving,
        autofocus: true,
        maxLines: 4,
        maxLength: maxPropertyNoteLength,
        // Sayaç yalnızca sınıra YAKLAŞINCA: her zaman görünen bir
        // "0/1000", kısa bir not yazan kullanıcıya uzun yazması
        // gerektiğini ima ediyor.
        buildCounter:
            (_, {required currentLength, required isFocused, maxLength}) =>
                currentLength < (maxLength ?? 0) * 0.8
                    ? null
                    : Text(
                      '$currentLength / $maxLength',
                      style: AppType.muted(AppType.micro),
                    ),
        decoration: const InputDecoration(
          hintText: 'Bu ev hakkında kendine bir not bırak…',
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: AppSpacing.xs),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => setState(() => _editing = false),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
            child: const Text('Vazgeç'),
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(
            onPressed: _saving || _draft.text.trim().isEmpty ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child:
                _saving
                    ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Kaydet'),
          ),
        ],
      ),
    ],
  );
}
