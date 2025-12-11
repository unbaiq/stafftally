
import 'dart:convert';

UserStaffModel userStaffModelFromJson(String str) => UserStaffModel.fromJson(json.decode(str));

String userStaffModelToJson(UserStaffModel data) => json.encode(data.toJson());

class UserStaffModel {
  final String message;
  final Data data;

  UserStaffModel({
    required this.message,
    required this.data,
  });

  UserStaffModel copyWith({
    String? message,
    Data? data,
  }) =>
      UserStaffModel(
        message: message ?? this.message,
        data: data ?? this.data,
      );

  factory UserStaffModel.fromJson(Map<String, dynamic> json) => UserStaffModel(
    message: json["message"],
    data: Data.fromJson(json["data"]),
  );

  Map<String, dynamic> toJson() => {
    "message": message,
    "data": data.toJson(),
  };
}

class Data {
  final int subadminId;
  final int staffId;
  final String activityName;
  final String description;
  final DateTime startDate;
  final DateTime dueDate;
  final String status;
  final DateTime updatedAt;
  final DateTime createdAt;
  final int id;

  Data({
    required this.subadminId,
    required this.staffId,
    required this.activityName,
    required this.description,
    required this.startDate,
    required this.dueDate,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
    required this.id,
  });

  Data copyWith({
    int? subadminId,
    int? staffId,
    String? activityName,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    String? status,
    DateTime? updatedAt,
    DateTime? createdAt,
    int? id,
  }) =>
      Data(
        subadminId: subadminId ?? this.subadminId,
        staffId: staffId ?? this.staffId,
        activityName: activityName ?? this.activityName,
        description: description ?? this.description,
        startDate: startDate ?? this.startDate,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
        createdAt: createdAt ?? this.createdAt,
        id: id ?? this.id,
      );

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    subadminId: json["subadmin_id"],
    staffId: json["staff_id"],
    activityName: json["activity_name"],
    description: json["description"],
    startDate: DateTime.parse(json["start_date"]),
    dueDate: DateTime.parse(json["due_date"]),
    status: json["status"],
    updatedAt: DateTime.parse(json["updated_at"]),
    createdAt: DateTime.parse(json["created_at"]),
    id: json["id"],
  );

  Map<String, dynamic> toJson() => {
    "subadmin_id": subadminId,
    "staff_id": staffId,
    "activity_name": activityName,
    "description": description,
    "start_date": "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}",
    "due_date": "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}",
    "status": status,
    "updated_at": updatedAt.toIso8601String(),
    "created_at": createdAt.toIso8601String(),
    "id": id,
  };
}
