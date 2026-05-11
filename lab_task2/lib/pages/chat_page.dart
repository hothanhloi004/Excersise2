import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../imgbb_service.dart';

// Message types
class MessageType {
  static const int text = 0;
  static const int image = 1;
  static const int sticker = 2;
}

// Stickers mẫu (dùng emoji)
const kStickers = ['😀', '😂', '😍', '🥰', '😎', '🤔', '😢', '😡',
  '👍', '👏', '🙏', '❤️', '🔥', '🎉', '🎊', '🌈'];

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerAvatar;

  const ChatPage({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerAvatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  late String _currentUserId;
  late String _groupChatId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    // groupChatId: hash uid của 2 users, sort để đảm bảo chỉ có 1 node
    final ids = [_currentUserId, widget.peerId]..sort();
    _groupChatId = ids.join('_');
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Gửi tin nhắn text
  Future<void> _sendTextMessage() async {
    final content = _msgController.text.trim();
    if (content.isEmpty) return;
    _msgController.clear();
    await _sendMessage(content, MessageType.text);
  }

  // Gửi sticker
  Future<void> _sendSticker(String sticker) async {
    Navigator.pop(context);
    await _sendMessage(sticker, MessageType.sticker);
  }

  // Gửi ảnh qua ImgBB
  Future<void> _sendImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    setState(() => _isSending = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final url = await ImgbbService.uploadImage(bytes);
      if (url != null) {
        await _sendMessage(url, MessageType.image);
      } else {
        Fluttertoast.showToast(
          msg: 'Gửi ảnh thất bại. Kiểm tra ImgBB API key.',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Lỗi: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage(String content, int type) async {
    await _firestore
        .collection('messages')
        .doc(_groupChatId)
        .collection('chats')
        .add({
      'senderId': _currentUserId,
      'receiverId': widget.peerId,
      'content': content,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        height: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn sticker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: kStickers.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _sendSticker(kStickers[i]),
                  child: Text(
                    kStickers[i],
                    style: const TextStyle(fontSize: 30),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.peerId}',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white24,
                child: widget.peerAvatar.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.peerAvatar,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Online',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('messages')
                    .doc(_groupChatId)
                    .collection('chats')
                    .orderBy('timestamp', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Bắt đầu cuộc trò chuyện nhé! 👋',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Tin nhắn mới nhất ở dưới
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg =
                          messages[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == _currentUserId;
                      return _buildMessageItem(msg, isMe);
                    },
                  );
                },
              ),
            ),

            // Sending indicator
            if (_isSending)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Đang gửi ảnh...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),

            // Input bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> msg, bool isMe) {
    final int type = msg['type'] as int? ?? MessageType.text;
    final String content = msg['content'] as String? ?? '';
    final Timestamp? ts = msg['timestamp'] as Timestamp?;
    final String timeStr = ts != null
        ? DateFormat('HH:mm').format(ts.toDate())
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              child: widget.peerAvatar.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: widget.peerAvatar,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, size: 16),
            ),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildBubble(type, content, isMe),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style:
                    const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildBubble(int type, String content, bool isMe) {
    final bubbleColor =
        isMe ? const Color(0xFFDCF8C6) : Colors.white;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    if (type == MessageType.sticker) {
      return Text(content, style: const TextStyle(fontSize: 40));
    }

    if (type == MessageType.image) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 220),
        child: ClipRRect(
          borderRadius: radius,
          child: CachedNetworkImage(
            imageUrl: content,
            width: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 200,
              height: 150,
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        ),
      );
    }

    // Text message
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        content,
        style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sticker button
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined,
                color: Color(0xFF075E54)),
            onPressed: _showStickerPicker,
          ),
          // Image button
          IconButton(
            icon: const Icon(Icons.photo_outlined, color: Color(0xFF075E54)),
            onPressed: _sendImage,
          ),
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgController,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          GestureDetector(
            onTap: _sendTextMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF075E54),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
