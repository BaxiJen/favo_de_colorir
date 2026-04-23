enum ConfirmationStatus { pending, confirmed, declined, noResponse }

/// Chamada real feita pela professora.
enum AttendanceStatus { pending, attended, absent, late }

class Presenca {
  final String id;
  final String aulaId;
  final String studentId;
  final ConfirmationStatus confirmation;
  final AttendanceStatus attendanceStatus;
  final bool? attended;
  final bool isMakeup;
  final DateTime? confirmedAt;
  final DateTime createdAt;

  const Presenca({
    required this.id,
    required this.aulaId,
    required this.studentId,
    required this.confirmation,
    required this.attendanceStatus,
    this.attended,
    required this.isMakeup,
    this.confirmedAt,
    required this.createdAt,
  });

  factory Presenca.fromJson(Map<String, dynamic> json) {
    return Presenca(
      id: json['id'] as String,
      aulaId: json['aula_id'] as String,
      studentId: json['student_id'] as String,
      confirmation: _parseConfirmation(json['confirmation'] as String),
      attendanceStatus:
          _parseAttendance(json['attendance_status'] as String? ?? 'pending'),
      attended: json['attended'] as bool?,
      isMakeup: json['is_makeup'] as bool,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aula_id': aulaId,
      'student_id': studentId,
      'confirmation': _confirmationToString(confirmation),
      'attendance_status': attendanceToString(attendanceStatus),
      'attended': attended,
      'is_makeup': isMakeup,
      'confirmed_at': confirmedAt?.toIso8601String(),
    };
  }

  bool get didAttend => attendanceStatus == AttendanceStatus.attended ||
      attendanceStatus == AttendanceStatus.late;

  static ConfirmationStatus _parseConfirmation(String s) {
    return switch (s) {
      'pending' => ConfirmationStatus.pending,
      'confirmed' => ConfirmationStatus.confirmed,
      'declined' => ConfirmationStatus.declined,
      'no_response' => ConfirmationStatus.noResponse,
      _ => ConfirmationStatus.pending,
    };
  }

  static String _confirmationToString(ConfirmationStatus s) {
    return switch (s) {
      ConfirmationStatus.pending => 'pending',
      ConfirmationStatus.confirmed => 'confirmed',
      ConfirmationStatus.declined => 'declined',
      ConfirmationStatus.noResponse => 'no_response',
    };
  }

  static AttendanceStatus _parseAttendance(String s) {
    return switch (s) {
      'pending' => AttendanceStatus.pending,
      'attended' => AttendanceStatus.attended,
      'absent' => AttendanceStatus.absent,
      'late' => AttendanceStatus.late,
      _ => AttendanceStatus.pending,
    };
  }

  static String attendanceToString(AttendanceStatus s) {
    return switch (s) {
      AttendanceStatus.pending => 'pending',
      AttendanceStatus.attended => 'attended',
      AttendanceStatus.absent => 'absent',
      AttendanceStatus.late => 'late',
    };
  }
}
