class InterventionModel {
  final String stressLevel;
  final String action;
  final String level;
  final double confidence;
  final String reasoning;
  final String toastMsg;
  final String toastEmoji;
  final String interventionTip;
  final String breathingTip;
  final String restReminder;
  final String activeApp;
  final bool triggerCall;
  final String? gameId;
  final Map<String, dynamic> auData;
  final DateTime timestamp;
  final List<String> gameOptions;
  final String ctaLabel;

  InterventionModel({
    required this.stressLevel,
    required this.action,
    this.level = 'NONE',
    this.confidence = 0.0,
    this.reasoning = '',
    this.toastMsg = '',
    this.toastEmoji = '🛡️',
    this.interventionTip = '',
    this.breathingTip = '',
    this.restReminder = '',
    this.activeApp = '',
    this.triggerCall = false,
    this.gameId,
    this.auData = const {},
    DateTime? timestamp,
    this.gameOptions = const ['BUBBLE_WRAP', 'BREATHING_TRAINER'],
    this.ctaLabel = 'Take a 60s Break 🛡️',
  }) : timestamp = timestamp ?? DateTime.now();

  factory InterventionModel.fromJson(Map<String, dynamic> json) {
    return InterventionModel(
      stressLevel: json['stress_level'] ?? 'STABLE',
      action: json['action'] ?? 'NONE',
      level: json['level'] ?? 'NONE',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      reasoning: json['reasoning'] ?? '',
      toastMsg: json['toast_msg'] ?? '',
      toastEmoji: json['toast_emoji'] ?? '🛡️',
      interventionTip: json['intervention_tip'] ?? '',
      breathingTip: json['breathing_tip'] ?? 'Breathe in 4s, hold 4s, out 4s.',
      restReminder: json['rest_reminder'] ?? 'Drink some water and look away from the screen.',
      activeApp: json['active_app'] ?? '',
      triggerCall: json['trigger_call'] ?? false,
      gameId: json['game_id'],
      auData: (json['au_data'] as Map<String, dynamic>?) ?? {},
      gameOptions: (json['game_options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['BUBBLE_WRAP', 'BREATHING_TRAINER'],
      ctaLabel: json['cta_label'] ?? 'Take a 60s Break 🛡️',
    );
  }

  bool get isHigh => stressLevel == 'HIGH';
  bool get isElevated => stressLevel == 'ELEVATED';
  bool get isIntervening => action == 'INTERVENE';
}
