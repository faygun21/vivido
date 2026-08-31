import 'package:flutter/material.dart';

import '../../../properties/presentation/property_format.dart';
import '../../domain/maneuver_text.dart';

class ManeuverBanner extends StatelessWidget {
  const ManeuverBanner({
    required this.instruction,
    required this.distanceM,
    this.roadName,
    super.key,
  });

  final ManeuverInstruction? instruction;
  final double? distanceM;
  final String? roadName;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 6,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(_icon(instruction?.icon), size: 29),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction?.text ?? 'Konum bekleniyor…',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (roadName?.trim().isNotEmpty == true)
                  Text(roadName!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(
            distanceM == null ? '—' : formatDistance(distanceM!.round()),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

IconData _icon(ManeuverIconKind? kind) => switch (kind) {
  ManeuverIconKind.left => Icons.turn_left,
  ManeuverIconKind.right => Icons.turn_right,
  ManeuverIconKind.slightLeft => Icons.turn_slight_left,
  ManeuverIconKind.slightRight => Icons.turn_slight_right,
  ManeuverIconKind.sharpLeft => Icons.turn_sharp_left,
  ManeuverIconKind.sharpRight => Icons.turn_sharp_right,
  ManeuverIconKind.uTurn => Icons.u_turn_left,
  ManeuverIconKind.merge => Icons.merge,
  ManeuverIconKind.ramp => Icons.ramp_right,
  ManeuverIconKind.roundabout => Icons.roundabout_right,
  ManeuverIconKind.arrive => Icons.flag,
  _ => Icons.straight,
};
