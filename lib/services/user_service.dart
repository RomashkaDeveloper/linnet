import '../models/user.dart';
import 'api_client.dart';

class UserService {
  Future<UserPrivate> getMe() async {
    final data = await ApiClient.instance.get('/users/me');
    return UserPrivate.fromJson(data as Map<String, dynamic>);
  }

  Future<UserPrivate> updateMe({String? fullName, String? bio}) async {
    final data = await ApiClient.instance.patch('/users/me', body: {
      'full_name': ?fullName,
      'bio': ?bio,
    });
    return UserPrivate.fromJson(data as Map<String, dynamic>);
  }

  Future<UserPrivate> uploadAvatar(String filePath) async {
    final data = await ApiClient.instance.multipart(
      '/users/me/avatar',
      fieldName: 'file',
      filePath: filePath,
    );
    return UserPrivate.fromJson(data as Map<String, dynamic>);
  }

  Future<UserPrivate> deleteAvatar() async {
    final data = await ApiClient.instance.delete('/users/me/avatar');
    return UserPrivate.fromJson(data as Map<String, dynamic>);
  }

  Future<List<UserPublic>> search(String query) async {
    final data = await ApiClient.instance.get('/users/search', query: {'query': query});
    return (data as List<dynamic>)
        .map((e) => UserPublic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserPublic> getUser(String id) async {
    final data = await ApiClient.instance.get('/users/$id');
    return UserPublic.fromJson(data as Map<String, dynamic>);
  }
}
