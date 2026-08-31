import '../../routes/domain/route_models.dart';

enum ManeuverIconKind {
  straight,
  left,
  right,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  uTurn,
  merge,
  ramp,
  roundabout,
  arrive,
}

class ManeuverInstruction {
  const ManeuverInstruction({required this.text, required this.icon});

  final String text;
  final ManeuverIconKind icon;
}

ManeuverInstruction maneuverInstruction(
  RouteManeuver maneuver, {
  required String roadName,
  required bool isLastStep,
}) {
  final modifier = maneuver.modifier;
  final road = roadName.trim();
  return switch (maneuver.type) {
    'depart' => const ManeuverInstruction(
      text: 'Yola çık',
      icon: ManeuverIconKind.straight,
    ),
    'arrive' => const ManeuverInstruction(
      text: 'Konuta ulaştın',
      icon: ManeuverIconKind.arrive,
    ),
    'turn' => _turn(modifier),
    'continue' when modifier == 'straight' => const ManeuverInstruction(
      text: 'Düz devam et',
      icon: ManeuverIconKind.straight,
    ),
    'continue' => _directional('Devam et', modifier),
    'new name' => ManeuverInstruction(
      text: road.isEmpty ? 'Devam et' : '$road üzerinde devam et',
      icon: ManeuverIconKind.straight,
    ),
    'merge' => _directional('Şeride geç', modifier, merge: true),
    'on ramp' => const ManeuverInstruction(
      text: 'Bağlantı yoluna gir',
      icon: ManeuverIconKind.ramp,
    ),
    'off ramp' => const ManeuverInstruction(
      text: 'Çıkışa gir',
      icon: ManeuverIconKind.ramp,
    ),
    'fork' => ManeuverInstruction(
      text:
          modifier?.contains('left') == true
              ? 'Yol ayrımında solu izle'
              : 'Yol ayrımında sağı izle',
      icon:
          modifier?.contains('left') == true
              ? ManeuverIconKind.left
              : ManeuverIconKind.right,
    ),
    'end of road' => ManeuverInstruction(
      text:
          modifier?.contains('left') == true
              ? 'Yolun sonunda sola dön'
              : 'Yolun sonunda sağa dön',
      icon:
          modifier?.contains('left') == true
              ? ManeuverIconKind.left
              : ManeuverIconKind.right,
    ),
    'roundabout' ||
    'rotary' ||
    'roundabout turn' ||
    'exit roundabout' => ManeuverInstruction(
      text:
          maneuver.exit == null
              ? 'Kavşağa gir'
              : 'Kavşaktan ${maneuver.exit}. çıkışı kullan',
      icon: ManeuverIconKind.roundabout,
    ),
    'notification' => ManeuverInstruction(
      text: road.isEmpty ? 'Devam et' : '$road üzerinde devam et',
      icon: ManeuverIconKind.straight,
    ),
    _ => ManeuverInstruction(
      text:
          isLastStep
              ? 'Konuta yaklaş'
              : road.isEmpty
              ? 'Devam et'
              : '$road üzerinde devam et',
      icon: ManeuverIconKind.straight,
    ),
  };
}

String maneuverText(RouteStep step, {bool isLastStep = false}) =>
    maneuverInstruction(
      step.maneuver,
      roadName: step.name,
      isLastStep: isLastStep,
    ).text;

ManeuverInstruction _turn(String? modifier) => switch (modifier) {
  'left' => const ManeuverInstruction(
    text: 'Sola dön',
    icon: ManeuverIconKind.left,
  ),
  'right' => const ManeuverInstruction(
    text: 'Sağa dön',
    icon: ManeuverIconKind.right,
  ),
  'slight left' => const ManeuverInstruction(
    text: 'Hafif sola dön',
    icon: ManeuverIconKind.slightLeft,
  ),
  'slight right' => const ManeuverInstruction(
    text: 'Hafif sağa dön',
    icon: ManeuverIconKind.slightRight,
  ),
  'sharp left' => const ManeuverInstruction(
    text: 'Keskin sola dön',
    icon: ManeuverIconKind.sharpLeft,
  ),
  'sharp right' => const ManeuverInstruction(
    text: 'Keskin sağa dön',
    icon: ManeuverIconKind.sharpRight,
  ),
  'uturn' => const ManeuverInstruction(
    text: 'U dönüşü yap',
    icon: ManeuverIconKind.uTurn,
  ),
  'straight' => const ManeuverInstruction(
    text: 'Düz devam et',
    icon: ManeuverIconKind.straight,
  ),
  _ => const ManeuverInstruction(
    text: 'Dönüşe hazırlan',
    icon: ManeuverIconKind.straight,
  ),
};

ManeuverInstruction _directional(
  String fallback,
  String? modifier, {
  bool merge = false,
}) {
  if (modifier?.contains('left') == true) {
    return ManeuverInstruction(
      text: merge ? 'Sol şeride geç' : 'Soldan devam et',
      icon: merge ? ManeuverIconKind.merge : ManeuverIconKind.left,
    );
  }
  if (modifier?.contains('right') == true) {
    return ManeuverInstruction(
      text: merge ? 'Sağ şeride geç' : 'Sağdan devam et',
      icon: merge ? ManeuverIconKind.merge : ManeuverIconKind.right,
    );
  }
  return ManeuverInstruction(
    text: fallback,
    icon: merge ? ManeuverIconKind.merge : ManeuverIconKind.straight,
  );
}
