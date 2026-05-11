import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ImgbbService {
  // Lấy API key miễn phí tại: https://api.imgbb.com/
  // Đăng ký → My API → Copy key → dán vào đây
  static const String _apiKey = '7b1b32a85809c2e714b2d44b72a0f934';

  /// Upload ảnh lên ImgBB, trả về URL ảnh hoặc null nếu thất bại
  static Future<String?> uploadImage(Uint8List bytes) async {
    try {
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload?key=$_apiKey'),
        body: {'image': base64Image},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return json['data']['url'] as String;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
