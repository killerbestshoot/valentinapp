import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'local_profile_store.dart';
import 'uuid_v4.dart';

class UserProfile {
  const UserProfile({
    required this.authUid,
    required this.userId,
    required this.email,
    required this.displayName,
    required this.role,
    required this.enterpriseId,
    required this.enterpriseName,
    required this.isActive,
  });

  final String authUid;
  final String userId;
  final String email;
  final String displayName;
  final String role;
  final String enterpriseId;
  final String enterpriseName;
  final bool isActive;

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'administrator' || role == 'admin';
  bool get isAgent => role == 'agent';

  static String _text(dynamic value) => (value ?? '').toString().trim();

  factory UserProfile.fromMap({
    required String authUid,
    required Map<String, dynamic> data,
    required User authUser,
  }) {
    final userId = _text(data['userId']);

    return UserProfile(
      authUid: authUid,
      userId: UuidV4.isValid(userId) ? userId : UuidV4.generate(),
      email: _text(data['email']).isEmpty
          ? (authUser.email ?? '')
          : _text(data['email']),
      displayName: _text(data['displayName']).isEmpty
          ? (authUser.displayName ?? authUser.email ?? authUid)
          : _text(data['displayName']),
      role: _text(data['role']).toLowerCase(),
      enterpriseId: _text(data['enterpriseId']),
      enterpriseName: _text(data['enterpriseName']).isEmpty
          ? 'VOUPVAPCASH'
          : _text(data['enterpriseName']),
      isActive: data['isActive'] is bool
          ? data['isActive'] as bool
          : (data['active'] is bool ? data['active'] as bool : true),
    );
  }
}

class UserProfileService {
  UserProfileService._();

  static final UserProfileService instance = UserProfileService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String authUid) {
    return _db.collection('users').doc(authUid);
  }

  Future<UserProfile> ensureCurrentProfile({
    String defaultRole = 'client',
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User pa konekte.');
    }

    return ensureProfileForUser(
      user: user,
      defaultRole: defaultRole,
      displayName: displayName,
    );
  }

  Future<UserProfile> ensureProfileForUser({
    required User user,
    String defaultRole = 'client',
    String? displayName,
  }) async {
    try {
      return await _ensureFirestoreProfileForUser(
        user: user,
        defaultRole: defaultRole,
        displayName: displayName,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;

      return _ensureLocalProfileForUser(
        user: user,
        defaultRole: defaultRole,
        displayName: displayName,
      );
    }
  }

  Future<UserProfile> _ensureFirestoreProfileForUser({
    required User user,
    required String defaultRole,
    String? displayName,
  }) async {
    final ref = userDoc(user.uid);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final payload = _buildProfilePayload(
      user: user,
      data: data,
      defaultRole: defaultRole,
      displayName: displayName,
    );

    final firestorePayload = <String, dynamic>{
      ...payload,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists || data['createdAt'] == null) {
      firestorePayload['createdAt'] = FieldValue.serverTimestamp();
    }

    await ref.set(firestorePayload, SetOptions(merge: true));

    final freshSnap = await ref.get();
    return UserProfile.fromMap(
      authUid: user.uid,
      data: freshSnap.data() ?? payload,
      authUser: user,
    );
  }

  Future<UserProfile> _ensureLocalProfileForUser({
    required User user,
    required String defaultRole,
    String? displayName,
  }) async {
    final stored = await LocalProfileStore.instance.load(user.uid);
    final data = stored ?? <String, dynamic>{};
    final payload = _buildProfilePayload(
      user: user,
      data: data,
      defaultRole: defaultRole,
      displayName: displayName,
    );
    final now = DateTime.now().toIso8601String();

    final localPayload = <String, dynamic>{
      ...payload,
      'createdAt': data['createdAt'] ?? now,
      'updatedAt': now,
      'source': 'local',
    };

    await LocalProfileStore.instance.save(user.uid, localPayload);

    return UserProfile.fromMap(
      authUid: user.uid,
      data: localPayload,
      authUser: user,
    );
  }

  Map<String, dynamic> _buildProfilePayload({
    required User user,
    required Map<String, dynamic> data,
    required String defaultRole,
    String? displayName,
  }) {
    final existingUserId = (data['userId'] ?? '').toString().trim();
    final userId =
        UuidV4.isValid(existingUserId) ? existingUserId : UuidV4.generate();
    final resolvedDisplayName = (displayName ?? '').trim().isEmpty
        ? ((data['displayName'] ?? user.displayName ?? user.email ?? user.uid)
            .toString()
            .trim())
        : displayName!.trim();
    final resolvedRole = (data['role'] ?? defaultRole).toString().trim();

    return <String, dynamic>{
      'uid': user.uid,
      'authUid': user.uid,
      'userId': userId,
      'email': user.email ?? data['email'] ?? '',
      'displayName': resolvedDisplayName,
      'role': resolvedRole.isEmpty ? defaultRole : resolvedRole,
      'isActive': data['isActive'] is bool ? data['isActive'] : true,
      'active': data['active'] is bool ? data['active'] : true,
    };
  }
}
