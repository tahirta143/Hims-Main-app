class TrackedSession {
  final String sessionTokenId;
  final int employeeId;
  final String employeeName;
  final String? employeeCode;
  final String? designation;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceType;
  final String lastSeenAt;
  final String loginAt;
  final bool isCurrent;
  final bool isOnline;
  final int socketConnectionCount;

  TrackedSession({
    required this.sessionTokenId,
    required this.employeeId,
    required this.employeeName,
    this.employeeCode,
    this.designation,
    this.ipAddress,
    this.userAgent,
    this.deviceType,
    required this.lastSeenAt,
    required this.loginAt,
    this.isCurrent = false,
    this.isOnline = false,
    this.socketConnectionCount = 0,
  });

  factory TrackedSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? json['user'] as Map<String, dynamic> : null;

    return TrackedSession(
      sessionTokenId: json['sessionTokenId']?.toString() ?? json['session_token_id']?.toString() ?? json['id']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId']
          : int.tryParse(json['employeeId']?.toString() ?? user?['id']?.toString() ?? '0') ?? 0,
      employeeName: json['employeeName']?.toString() ?? json['employee_name']?.toString() ?? user?['name']?.toString() ?? 'Unknown',
      employeeCode: json['employeeCode']?.toString() ?? json['employee_code']?.toString() ?? user?['employeeCode']?.toString(),
      designation: json['designation']?.toString() ?? user?['designation']?.toString(),
      ipAddress: json['ipAddress']?.toString() ?? json['ip_address']?.toString(),
      userAgent: json['userAgent']?.toString() ?? json['user_agent']?.toString(),
      deviceType: json['deviceType']?.toString() ?? json['device_type']?.toString(),
      lastSeenAt: json['lastSeenAt']?.toString() ?? json['last_seen_at']?.toString() ?? '',
      loginAt: json['loginAt']?.toString() ?? json['login_at'] ?? json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      isCurrent: json['isCurrent'] == true || json['is_current'] == 1,
      isOnline: json['isOnline'] == true || json['is_online'] == 1,
      socketConnectionCount: json['socketConnectionCount'] is int ? json['socketConnectionCount'] : int.tryParse(json['socketConnectionCount']?.toString() ?? '0') ?? 0,
    );
  }
}
