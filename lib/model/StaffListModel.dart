
import 'dart:convert';

List<TaksModel> taksModelFromJson(String str) => List<TaksModel>.from(json.decode(str).map((x) => TaksModel.fromJson(x)));

String taksModelToJson(List<TaksModel> data) => json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

class TaksModel {
  final int id;
  final int subadminId;
  final int staffId;
  final String activityName;
  final String description;
  final String status;
  final dynamic remark;
  final DateTime startDate;
  final DateTime dueDate;
  final dynamic completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaksModel({
    required this.id,
    required this.subadminId,
    required this.staffId,
    required this.activityName,
    required this.description,
    required this.status,
    required this.remark,
    required this.startDate,
    required this.dueDate,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaksModel.fromJson(Map<String, dynamic> json) => TaksModel(
    id: json["id"],
    subadminId: json["subadmin_id"],
    staffId: json["staff_id"],
    activityName: json["activity_name"],
    description: json["description"],
    status: json["status"],
    remark: json["remark"],
    startDate: DateTime.parse(json["start_date"]),
    dueDate: DateTime.parse(json["due_date"]),
    completedAt: json["completed_at"],
    createdAt: DateTime.parse(json["created_at"]),
    updatedAt: DateTime.parse(json["updated_at"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "subadmin_id": subadminId,
    "staff_id": staffId,
    "activity_name": activityName,
    "description": description,
    "status": status,
    "remark": remark,
    "start_date": startDate.toIso8601String(),
    "due_date": dueDate.toIso8601String(),
    "completed_at": completedAt,
    "created_at": createdAt.toIso8601String(),
    "updated_at": updatedAt.toIso8601String(),
  };
}
