class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'] as Map<String, dynamic>;
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      expiresIn: (tokens['expiresIn'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'tokens': {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresIn': expiresIn,
    },
  };
}

class Persona {
  const Persona({
    required this.code,
    required this.displayNameTr,
    required this.descriptionTr,
    this.icon,
  });

  final String code;
  final String displayNameTr;
  final String descriptionTr;
  final String? icon;

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
    code: json['code'] as String,
    displayNameTr: json['displayNameTr'] as String,
    descriptionTr: json['descriptionTr'] as String,
    icon: json['icon'] as String?,
  );
}

class Anchor {
  const Anchor({
    required this.id,
    required this.label,
    required this.lat,
    required this.lon,
    required this.mode,
    required this.priority,
  });

  final String id;
  final String label;
  final double lat;
  final double lon;
  final String mode;
  final int priority;

  factory Anchor.fromJson(Map<String, dynamic> json) => Anchor(
    id: json['id'] as String,
    label: json['label'] as String,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    mode: json['mode'] as String,
    priority: (json['priority'] as num).toInt(),
  );

  Anchor copyWith({int? priority}) => Anchor(
    id: id,
    label: label,
    lat: lat,
    lon: lon,
    mode: mode,
    priority: priority ?? this.priority,
  );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.personaCode,
    required this.monthlyBudget,
    required this.anchors,
  });

  final String id;
  final String personaCode;
  final double? monthlyBudget;
  final List<Anchor> anchors;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    personaCode: json['personaCode'] as String,
    monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble(),
    anchors:
        (json['anchors'] as List<dynamic>? ?? const [])
            .map((item) => Anchor.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority)),
  );

  UserProfile copyWith({
    String? personaCode,
    double? monthlyBudget,
    bool clearBudget = false,
    List<Anchor>? anchors,
  }) => UserProfile(
    id: id,
    personaCode: personaCode ?? this.personaCode,
    monthlyBudget: clearBudget ? null : monthlyBudget ?? this.monthlyBudget,
    anchors: anchors ?? this.anchors,
  );
}
