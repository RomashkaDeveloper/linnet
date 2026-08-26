import 'user.dart';

enum CallType { audio, video }

enum CallStatus { ringing, ongoing, ended, missed, declined }

CallType callTypeFromString(String s) =>
    s == 'video' ? CallType.video : CallType.audio;

CallStatus callStatusFromString(String s) => CallStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => CallStatus.ended,
    );

class CallOut {
  final String id;
  final String chatId;
  final String callerId;
  final String calleeId;
  final CallType callType;
  final CallStatus status;
  final UserPublic? caller;
  final UserPublic? callee;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  CallOut({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.calleeId,
    required this.callType,
    required this.status,
    this.caller,
    this.callee,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
  });

  factory CallOut.fromJson(Map<String, dynamic> json) => CallOut(
        id: json['id'].toString(),
        chatId: json['chat_id'].toString(),
        callerId: (json['caller_id'] ?? '').toString(),
        calleeId: (json['callee_id'] ?? '').toString(),
        callType: callTypeFromString(json['call_type'] as String? ?? 'audio'),
        status: callStatusFromString(json['status'] as String? ?? 'ended'),
        caller: json['caller'] != null
            ? UserPublic.fromJson(json['caller'] as Map<String, dynamic>)
            : null,
        callee: json['callee'] != null
            ? UserPublic.fromJson(json['callee'] as Map<String, dynamic>)
            : null,
        startedAt: DateTime.tryParse(json['created_at'] as String? ?? json['started_at'] as String? ?? '') ?? DateTime.now(),
        answeredAt: json['answered_at'] != null ? DateTime.tryParse(json['answered_at'] as String) : null,
        endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'] as String) : null,
      );

  Duration? get duration {
    if (answeredAt == null) return null;
    final end = endedAt ?? DateTime.now();
    return end.difference(answeredAt!);
  }
}