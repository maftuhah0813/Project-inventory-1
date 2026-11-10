/// Model data representasi Pengguna Sistem (Admin & Kasir)
class UserModel {
  final String uid;
  final String email;
  final String namaLengkap;
  final String role; // 'admin' atau 'kasir'
  final String? fcmToken;
  final bool statusAktif;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.namaLengkap,
    required this.role,
    this.fcmToken,
    this.statusAktif = true,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isKasir => role == 'kasir';

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] as String? ?? '',
      namaLengkap: map['nama_lengkap'] as String? ?? '',
      role: map['role'] as String? ?? 'kasir',
      fcmToken: map['fcm_token'] as String?,
      statusAktif: map['status_aktif'] as bool? ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'nama_lengkap': namaLengkap,
      'role': role,
      'fcm_token': fcmToken,
      'status_aktif': statusAktif,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
