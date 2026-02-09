import 'package:equatable/equatable.dart';
import 'package:bolo_debate/shared/models/user_model.dart';

enum RoomType { debate, discussion }
enum RoomStatus { scheduled, live, ended }
enum ParticipantSide { a, b, neutral }
enum ParticipantRole { host, speaker, listener }

class Region extends Equatable {
  final String id;
  final String name;
  final String state;

  const Region({
    required this.id,
    required this.name,
    required this.state,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, state];
}

class Category extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String color;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, color];
}

// Supported languages for room discussions
const List<String> supportedLanguages = [
  'English', 'Hindi', 'Tamil', 'Telugu', 'Kannada', 'Malayalam',
  'Bengali', 'Marathi', 'Gujarati', 'Punjabi', 'Odia', 'Assamese',
  'Kashmiri', 'Konkani', 'Manipuri', 'Nepali', 'Sanskrit', 'Urdu',
];

class Room extends Equatable {
  final String id;
  final String title;
  final String? description;
  final User? host;
  final Region region;
  final Category category;
  final RoomType type;
  final String? sideALabel;
  final String? sideBLabel;
  final String language; // Discussion language
  final DateTime scheduledAt;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final int extensionsUsed;
  final RoomStatus status;
  final bool isAiHosted;
  final int participantCount;
  final int sideACount;
  final int sideBCount;

  const Room({
    required this.id,
    required this.title,
    this.description,
    this.host,
    required this.region,
    required this.category,
    required this.type,
    this.sideALabel,
    this.sideBLabel,
    this.language = 'English',
    required this.scheduledAt,
    this.startedAt,
    this.endsAt,
    this.extensionsUsed = 0,
    required this.status,
    this.isAiHosted = false,
    this.participantCount = 0,
    this.sideACount = 0,
    this.sideBCount = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      host: json['host'] != null ? User.fromJson(json['host'] as Map<String, dynamic>) : null,
      region: Region.fromJson(json['region'] as Map<String, dynamic>),
      category: Category.fromJson(json['category'] as Map<String, dynamic>),
      type: json['type'] == 'DEBATE' ? RoomType.debate : RoomType.discussion,
      sideALabel: json['sideALabel'] as String?,
      sideBLabel: json['sideBLabel'] as String?,
      language: json['language'] as String? ?? 'English',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      endsAt: json['endsAt'] != null ? DateTime.parse(json['endsAt'] as String) : null,
      extensionsUsed: json['extensionsUsed'] as int? ?? 0,
      status: _parseStatus(json['status'] as String),
      isAiHosted: json['isAiHosted'] as bool? ?? false,
      participantCount: json['participantCount'] as int? ?? 0,
      sideACount: json['sideACount'] as int? ?? 0,
      sideBCount: json['sideBCount'] as int? ?? 0,
    );
  }

  static RoomStatus _parseStatus(String status) {
    switch (status) {
      case 'SCHEDULED':
        return RoomStatus.scheduled;
      case 'LIVE':
        return RoomStatus.live;
      case 'ENDED':
        return RoomStatus.ended;
      default:
        return RoomStatus.scheduled;
    }
  }

  bool get isDebate => type == RoomType.debate;
  bool get isLive => status == RoomStatus.live;
  bool get isScheduled => status == RoomStatus.scheduled;
  bool get canExtend => extensionsUsed < 3;

  Duration? get timeRemaining {
    if (endsAt == null) return null;
    final remaining = endsAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        host,
        region,
        category,
        type,
        sideALabel,
        sideBLabel,
        language,
        scheduledAt,
        startedAt,
        endsAt,
        extensionsUsed,
        status,
        isAiHosted,
        participantCount,
        sideACount,
        sideBCount,
      ];
}

class RoomParticipant extends Equatable {
  final String id;
  final User user;
  final ParticipantSide side;
  final ParticipantRole role;
  final bool handRaised;
  final bool isMuted;
  final DateTime joinedAt;

  const RoomParticipant({
    required this.id,
    required this.user,
    required this.side,
    required this.role,
    this.handRaised = false,
    this.isMuted = true,
    required this.joinedAt,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) {
    return RoomParticipant(
      id: json['id'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      side: _parseSide(json['side'] as String),
      role: _parseRole(json['role'] as String),
      handRaised: json['handRaised'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? true,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  static ParticipantSide _parseSide(String side) {
    switch (side) {
      case 'A':
        return ParticipantSide.a;
      case 'B':
        return ParticipantSide.b;
      default:
        return ParticipantSide.neutral;
    }
  }

  static ParticipantRole _parseRole(String role) {
    switch (role) {
      case 'HOST':
        return ParticipantRole.host;
      case 'SPEAKER':
        return ParticipantRole.speaker;
      default:
        return ParticipantRole.listener;
    }
  }

  bool get isHost => role == ParticipantRole.host;
  bool get isSpeaker => role == ParticipantRole.speaker;
  bool get isListener => role == ParticipantRole.listener;

  @override
  List<Object?> get props => [id, user, side, role, handRaised, isMuted, joinedAt];
}

class ChatMessage extends Equatable {
  final String id;
  final User user;
  final String content;
  final bool isBot;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.user,
    required this.content,
    this.isBot = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      content: json['content'] as String,
      isBot: json['isBot'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, user, content, isBot, createdAt];
}
