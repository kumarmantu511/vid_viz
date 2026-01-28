import 'dart:convert'; // Base64 için gerekli
import 'dart:io';
import 'dart:math';
import 'dart:typed_data'; // Byte işlemleri için
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Sıkıştırma paketi
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidviz/core/theme.dart' as app_theme;

// ============================================================================
// FEEDBACK TYPES
// ============================================================================
enum FeedbackType {
  bug('🐛', 'Bug Report', 'critical'),
  feature('💡', 'Feature Request', 'normal'),
  question('❓', 'Question', 'low'),
  performance('⚡', 'Performance', 'high'),
  other('💬', 'Other', 'normal');

  final String emoji;
  final String label;
  final String defaultPriority;

  const FeedbackType(this.emoji, this.label, this.defaultPriority);
}

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({Key? key}) : super(key: key);

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isSending = false;
  String? _conversationId;

  FeedbackType _selectedType = FeedbackType.bug;
  List<String> _attachedImages = []; // Yerel dosya yolları

  bool get _isConversationStarted => _messages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadDraft();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- DRAFT LOGIC ---
  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedback_draft', _messageController.text);
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('feedback_draft');
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('feedback_draft');
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic> _getLocalizedData(BuildContext context) {
    String langCode = Localizations.localeOf(context).languageCode;
    if (!_FeedbackDictionary.data.containsKey(langCode)) {
      langCode = 'en';
    }
    return _FeedbackDictionary.data[langCode]!;
  }

  // --- DOSYA SEÇME ---
  Future<void> _pickImage() async {
    if (_attachedImages.length >= 2) { // Firestore limiti için max 2 resim yapalım
      _showSnackbar('Max 2 images allowed (Storage Limit)');
      return;
    }
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedImages.add(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  // --- RESİMLERİ SIKIŞTIR VE BASE64 YAP ---
  // Storage yerine bu fonksiyonu kullanacağız
  Future<List<String>> _compressAndConvertImages() async {
    List<String> base64Images = [];

    for (String imagePath in _attachedImages) {
      try {
        // 1. Resmi Sıkıştır (Firestore 1MB limitine takılmamak için)
        // Kaliteyi %40'a düşür, genişliği max 800px yap
        Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
          imagePath,
          minWidth: 800,
          minHeight: 800,
          quality: 40,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes != null) {
          // 2. Base64 String'e çevir
          String base64String = base64Encode(compressedBytes);
          base64Images.add(base64String);
        }
      } catch (e) {
        debugPrint('Compression Error: $e');
      }
    }
    return base64Images;
  }

  List<String> _detectTags(String message) {
    final tags = <String>[];
    final lowerMsg = message.toLowerCase();
    if (lowerMsg.contains('slow') || lowerMsg.contains('lag')) tags.add('performance');
    if (lowerMsg.contains('crash') || lowerMsg.contains('close')) tags.add('crash');
    if (lowerMsg.contains('ui') || lowerMsg.contains('button')) tags.add('ui');
    return tags;
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // --- MESAJ GÖNDER ---
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _messages.add({
        "text": text,
        "isUser": true,
        "timestamp": DateTime.now(),
      });
      _isTyping = true;
    });

    _messageController.clear();
    await _clearDraft();
    _scrollToBottom();
    FocusScope.of(context).unfocus();

    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      String deviceModel = 'Unknown';
      String osVersion = 'Unknown';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceModel = '${androidInfo.brand} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceModel = iosInfo.utsname.machine;
        osVersion = 'iOS ${iosInfo.systemVersion}';
      }

      // --- DEĞİŞİKLİK BURADA: STORAGE YERİNE BASE64 ---
      List<String> base64Images = [];
      if (_attachedImages.isNotEmpty) {
        base64Images = await _compressAndConvertImages();
        if (mounted) setState(() => _attachedImages.clear());
      }

      final tags = _detectTags(text);

      await FirebaseFirestore.instance
          .collection('feedbacks')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'message': text,
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'type': _selectedType.label,
        'priority': _selectedType.defaultPriority,
        'tags': tags,
        // Artık URL değil, direkt resim verisi (Base64 String) gönderiyoruz
        'images_base64': base64Images,
        'has_images': base64Images.isNotEmpty,
        'timestamp': FieldValue.serverTimestamp(),
        'device_model': deviceModel,
        'os_version': osVersion,
        'app_version': '${packageInfo.version} (${packageInfo.buildNumber})',
        'locale': Localizations.localeOf(context).toString(),
        'conversation_id': _conversationId,
        'is_user_message': true,
      });

      await FirebaseFirestore.instance
          .collection('feedbacks')
          .doc(_conversationId)
          .set({
        'last_message': text,
        'last_updated': FieldValue.serverTimestamp(),
        'type': _selectedType.label,
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      }, SetOptions(merge: true));

      // Bot Response Simulation
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      final localizedData = _getLocalizedData(context);
      final List<String> responses = localizedData['responses'];
      final randomResponse = responses[Random().nextInt(responses.length)];

      setState(() {
        _messages.add({
          "text": randomResponse,
          "isUser": false,
          "timestamp": DateTime.now(),
        });
      });
      _scrollToBottom();

    } catch (e) {
      debugPrint("Geri bildirim hatası: $e");
      _showSnackbar('Mesaj gönderilemedi.');
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _isSending = false;
        });
      }
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final langData = _getLocalizedData(context);

    final bgColor = isDark ? app_theme.projectListBg : app_theme.background;
    final cardColor = isDark ? app_theme.projectListCardBg : app_theme.surface;
    final textColor = isDark ? app_theme.darkTextPrimary : app_theme.textPrimary;
    final hintColor = isDark ? app_theme.darkTextSecondary : app_theme.textSecondary;
    final accentColor = isDark ? app_theme.darkAccent : app_theme.accent;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(app_theme.radiusXL)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // DRAG HANDLE
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: hintColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // HEADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: app_theme.spaceM),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      langData['title'],
                      style: TextStyle(color: textColor, fontSize: app_theme.textTitle, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: hintColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? app_theme.projectListCardBorder : app_theme.border),

              // CHAT CONTENT
              Flexible(
                child: ListView(
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(app_theme.spaceM),
                  children: [

                    if (!_isConversationStarted) ...[
                      // KATEGORİ
                      Text('Select Category:', style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: FeedbackType.values.map((type) {
                            final isSelected = _selectedType == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${type.emoji} ${type.label}'),
                                selected: isSelected,
                                onSelected: (selected) { if (selected) setState(() => _selectedType = type); },
                                backgroundColor: cardColor,
                                selectedColor: accentColor.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? accentColor : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // EMAIL
                      TextField(
                        controller: _emailController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email (Optional)',
                          labelStyle: TextStyle(color: hintColor),
                          prefixIcon: Icon(Icons.email_outlined, size: 20, color: hintColor),
                          filled: true,
                          fillColor: cardColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(app_theme.radiusM), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Opacity(
                          opacity: 0.5,
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 40, color: hintColor),
                              const SizedBox(height: 8),
                              Text(langData['empty'], style: TextStyle(color: hintColor)),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // MESAJLAR
                    if (_isConversationStarted)
                      ..._messages.map((msg) {
                        final isUser = msg['isUser'];
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                            decoration: BoxDecoration(
                              color: isUser ? accentColor : cardColor,
                              borderRadius: BorderRadius.circular(app_theme.radiusM).copyWith(
                                bottomRight: isUser ? Radius.zero : const Radius.circular(app_theme.radiusM),
                                bottomLeft: !isUser ? Radius.zero : const Radius.circular(app_theme.radiusM),
                              ),
                            ),
                            child: Text(
                              msg['text'],
                              style: TextStyle(color: isUser ? app_theme.textOnAccent : textColor, fontSize: app_theme.textBody),
                            ),
                          ),
                        );
                      }).toList(),

                    // YAZIYOR
                    if (_isTyping)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: hintColor)),
                            const SizedBox(width: 8),
                            Text(langData['typing'], style: TextStyle(color: hintColor, fontSize: 12)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // INPUT ALANI
              Container(
                padding: const EdgeInsets.all(app_theme.spaceM),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(top: BorderSide(color: isDark ? app_theme.projectListCardBorder : app_theme.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resim Önizleme
                    if (_attachedImages.isNotEmpty)
                      Container(
                        height: 60,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachedImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(File(_attachedImages[index])),
                                      fit: BoxFit.cover,
                                    ),
                                    border: Border.all(color: hintColor.withOpacity(0.2)),
                                  ),
                                ),
                                Positioned(
                                  top: 0, right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _attachedImages.removeAt(index)),
                                    child: CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.black,
                                      child: Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    // Input
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.add_photo_alternate_outlined, color: hintColor),
                          onPressed: _pickImage,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(color: textColor),
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onChanged: (_) => _saveDraft(),
                            decoration: InputDecoration(
                              hintText: langData['hint'],
                              hintStyle: TextStyle(color: hintColor),
                              filled: true,
                              fillColor: cardColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Opacity(
                          opacity: _isSending ? 0.5 : 1.0,
                          child: CircleAvatar(
                            backgroundColor: accentColor,
                            radius: 20,
                            child: _isSending
                                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : IconButton(
                              icon: Icon(Icons.arrow_upward_rounded, size: 20, color: app_theme.textOnAccent),
                              onPressed: _isSending ? null : _sendMessage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================================
// LANGUAGE DICTIONARY
// ============================================================================
class _FeedbackDictionary {
  static const Map<String, Map<String, dynamic>> data = {
    'en': {
      'title': 'Support & Feedback',
      'hint': 'Message...',
      'empty': 'How can we help you?',
      'typing': 'Support is typing...',
      'responses': [
        "Thanks for the feedback! Our team is looking into it. 🚀",
        "Message received. We'll consider this for the next update. 👍",
        "Great catch! Thanks for helping us improve.",
        "Good to know, we've added this to our notes. ✍️",
        "Feedback received. We'll try to solve it ASAP."
      ]
    },
    'tr': {
      'title': 'Destek & Geri Bildirim',
      'hint': 'Mesaj yaz...',
      'empty': 'Size nasıl yardımcı olabiliriz?',
      'typing': 'Destek yazıyor...',
      'responses': [
        "Geri bildirimin için teşekkürler! Ekibimiz inceliyor. 🚀",
        "Mesajın alındı. Sonraki güncellemede dikkate alacağız. 👍",
        "Harika tespit! Geliştirmemize yardım ettiğin için sağ ol.",
        "Bunu bildirdiğin iyi oldu, notlarımıza ekledik. ✍️",
        "Bildirimin ulaştı. En kısa sürede çözmeye çalışacağız."
      ]
    },
    // Diğer diller (es, pt, fr, de, ru, ar, hi, zh, ja, ko) buraya eklenebilir...
    'ja': {
      'title': 'サポートとフィードバック',
      'hint': 'メッセージ...',
      'empty': 'どのようなご用件でしょうか？',
      'typing': 'サポートが入力中...',
      'responses': [
        "フィードバックありがとうございます！チームが確認しています。 🚀",
        "メッセージを受け取りました。次回の更新で検討します。 👍",
        "素晴らしいご指摘です！改善にご協力いただきありがとうございます。",
        "ご報告ありがとうございます。メモに追加しました。 ✍️",
        "フィードバックを受け取りました。できるだけ早く解決するよう努めます。"
      ]
    },
  };
}