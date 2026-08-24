class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.emailVerified = true,
  });

  final String id;
  final String email;
  final String? displayName;

  /// E-posta doğrulandı mı (K-09).
  ///
  /// Alan yoksa `true` varsayılıyor: oturum ancak doğrulanmış bir hesap
  /// için (ya da doğrulama kapalıyken) veriliyor. `false` varsaymak,
  /// güncellenmemiş bir backend'e bağlanan istemcide her kullanıcıyı
  /// "doğrulanmamış" gösterirdi.
  final bool emailVerified;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String?,
    emailVerified: json['emailVerified'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'emailVerified': emailVerified,
  };
}

/// `POST /auth/register` sonucu — K-09.
///
/// Doğrulama zorunluyken (varsayılan) sunucu 202 döner ve token VERMEZ;
/// kapalıyken 201 + oturum döner. `sealed` olduğu için `switch` her iki
/// dalı da ele almaya zorlar — yeni bir dal eklenirse derleyici yakalar.
sealed class RegisterOutcome {
  const RegisterOutcome();
}

class RegisterAuthenticated extends RegisterOutcome {
  const RegisterAuthenticated(this.session);

  final AuthSession session;
}

class RegisterVerificationRequired extends RegisterOutcome {
  const RegisterVerificationRequired({
    required this.email,
    required this.expiresInMinutes,
    required this.message,
  });

  final String email;
  final int expiresInMinutes;
  final String message;

  factory RegisterVerificationRequired.fromJson(Map<String, dynamic> json) {
    final email = json['email'] as String? ?? '';
    final minutes = (json['expiresInMinutes'] as num?)?.toInt() ?? 15;
    return RegisterVerificationRequired(
      email: email,
      expiresInMinutes: minutes,
      message:
          json['message'] as String? ??
          '$email adresine 6 haneli bir doğrulama kodu gönderdik.',
    );
  }
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

class PersonaCategoryWeight {
  const PersonaCategoryWeight({
    required this.categoryCode,
    required this.weight,
  });

  final String categoryCode;
  final double weight;

  factory PersonaCategoryWeight.fromJson(Map<String, dynamic> json) =>
      PersonaCategoryWeight(
        categoryCode: json['categoryCode'] as String,
        weight: (json['weight'] as num).toDouble(),
      );
}

class Persona {
  const Persona({
    required this.code,
    required this.displayNameTr,
    required this.descriptionTr,
    this.icon,
    this.categoryWeights = const [],
  });

  final String code;
  final String displayNameTr;
  final String descriptionTr;
  final String? icon;
  final List<PersonaCategoryWeight> categoryWeights;

  factory Persona.fromJson(Map<String, dynamic> json) => Persona(
    code: json['code'] as String,
    displayNameTr: json['displayNameTr'] as String,
    descriptionTr: json['descriptionTr'] as String,
    icon: json['icon'] as String?,
    categoryWeights: (json['categoryWeights'] as List<dynamic>? ?? const [])
        .map(
          (item) =>
              PersonaCategoryWeight.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false),
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
    required this.minMonthlyBudget,
    required this.maxMonthlyBudget,
    required this.anchors,
    this.firstName = '',
    this.lastName = '',
    this.categoryOrder = const [],
  });

  final String id;
  final String firstName;
  final String lastName;
  final String personaCode;
  final double? minMonthlyBudget;
  final double? maxMonthlyBudget;
  final List<String> categoryOrder;
  final List<Anchor> anchors;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    personaCode: json['personaCode'] as String,
    minMonthlyBudget: (json['minMonthlyBudget'] as num?)?.toDouble(),
    maxMonthlyBudget: (json['maxMonthlyBudget'] as num?)?.toDouble(),
    categoryOrder: (json['categoryOrder'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList(growable: false),
    anchors:
        (json['anchors'] as List<dynamic>? ?? const [])
            .map((item) => Anchor.fromJson(item as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority)),
  );

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? personaCode,
    double? minMonthlyBudget,
    double? maxMonthlyBudget,
    bool clearBudgets = false,
    List<String>? categoryOrder,
    List<Anchor>? anchors,
  }) => UserProfile(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    personaCode: personaCode ?? this.personaCode,
    minMonthlyBudget:
        clearBudgets ? null : minMonthlyBudget ?? this.minMonthlyBudget,
    maxMonthlyBudget:
        clearBudgets ? null : maxMonthlyBudget ?? this.maxMonthlyBudget,
    categoryOrder: categoryOrder ?? this.categoryOrder,
    anchors: anchors ?? this.anchors,
  );
}
