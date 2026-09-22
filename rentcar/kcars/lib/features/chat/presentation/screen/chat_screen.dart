import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/error/exception.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/core/services/info.dart';
import 'package:kcars/core/services/secure_storage.dart';
import 'package:kcars/core/utils/permissions.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/app_bar.dart';
import 'package:kcars/core/widget/loadin_widget.dart';
import 'package:sizer/sizer.dart';

final _chatApi = GetIt.I<ApiService>();
const _red = Color(0xffc51d27);
const _skyBlue = Color(0xff55a9f7);
const _ink = Color(0xff202431);
const _muted = Color(0xff737b89);
const _sharedCarMarker = '__CARVA_SHARED_CAR__';

Map<String, dynamic>? _decodeSharedCar(String body) {
  final marker = body.indexOf(_sharedCarMarker);
  if (marker < 0) return null;
  final encoded = body.substring(marker + _sharedCarMarker.length).trim();
  if (encoded.isEmpty) return null;
  try {
    final decoded = jsonDecode(encoded);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _sharedCarPayload(Map<String, dynamic> car) {
  final payload = <String, dynamic>{};
  for (final key in const [
    'id',
    'carId',
    'title',
    'name',
    'image',
    'imageUrl',
    'images',
    'feature',
    'rentalPlan',
    'rentalPlans',
    'brand',
    'type',
  ]) {
    if (car[key] != null) payload[key] = car[key];
  }
  return payload;
}

@RoutePage()
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int? _errorStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  dynamic _nested(dynamic response, String key) {
    if (response is! Map) return response;
    final data = response['data'];
    if (data is Map && data[key] != null) return data[key];
    return response[key] ?? response;
  }

  Future<void> _load() async {
    try {
      final result = await _chatApi.post<dynamic>('/chat/list', data: {});
      final raw = result is List ? result : _nested(result, 'conversations');
      if (!mounted) return;
      setState(() {
        _items = (raw is List ? raw : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorStatus = error is ApiException ? error.statusCode : null;
          _error = error is ApiException
              ? error.message
              : 'Unable to load chats right now.';
        });
      }
    }
  }

  Map<String, dynamic>? _user(Map<String, dynamic> item) {
    final value =
        item['recipient'] ??
        item['otherUser'] ??
        item['participant'] ??
        item['user'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String _name(Map<String, dynamic> item) =>
      '${_user(item)?['name'] ?? _user(item)?['userName'] ?? _user(item)?['email'] ?? item['name'] ?? item['title'] ?? 'Carva user'}';
  String? _image(Map<String, dynamic> item) =>
      _user(item)?['image']?.toString() ?? item['image']?.toString();
  String _preview(Map<String, dynamic> item) {
    final message = item['lastMessage'] ?? item['last_message'];
    if (message is Map) {
      final body = '${message['body'] ?? ''}';
      if (body.contains(_sharedCarMarker) ||
          body.trim().toLowerCase() == 'shared car') {
        return 'Car shared';
      }
      return body.isNotEmpty
          ? body
          : (message['image'] != null ? 'Photo' : 'New message');
    }
    return '${message ?? item['lastMessagePreview'] ?? item['preview'] ?? 'Start a conversation'}';
  }

  DateTime? _lastSeen(Map<String, dynamic> item) => DateTime.tryParse(
    '${_user(item)?['lastSeen'] ?? _user(item)?['lastSeenAt'] ?? item['lastSeen'] ?? item['lastSeenAt'] ?? item['updatedAt']}',
  )?.toLocal();
  String _presence(Map<String, dynamic> item) {
    final date = _lastSeen(item);
    if (item['isOnline'] == true ||
        (date != null && DateTime.now().difference(date).inMinutes < 10))
      return 'Active now';
    if (date == null) return 'Last seen unavailable';
    if (DateTime.now().difference(date).inDays < 7)
      return 'Last active ${DateFormat('EEEE').format(date)}';
    return 'Last active ${DateFormat('MMM d, yyyy').format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _items
        .where((item) => _name(item).toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: const HomeAppBar(),
      backgroundColor: const Color(0xfffafafa),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingWidget()
            : _error != null
            ? ListView(
                children: [
                  SizedBox(height: 24.h),
                  Icon(
                    _errorStatus == 401
                        ? Icons.lock_outline_rounded
                        : Icons.cloud_off_rounded,
                    size: 15.w,
                    color: _red,
                  ),
                  SizedBox(height: 3.w),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      _errorStatus == 401
                          ? 'Your session has expired.'
                          : _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  SizedBox(height: 2.w),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      _errorStatus == 401
                          ? 'Sign in again to use chat.'
                          : 'Please try again in a moment.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted),
                    ),
                  ),
                  SizedBox(height: 4.w),
                  if (_errorStatus == 401)
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => context.router.push(LoginRoute()),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in again'),
                      ),
                    )
                  else
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(4.w, 2.w, 4.w, 24.w),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 13.w,
                        height: 13.w,
                        decoration: const BoxDecoration(
                          color: Color(0xffffe7e8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.forum_rounded, color: _red),
                      ),
                      SizedBox(width: 3.w),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Messages',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            Text(
                              'Keep in touch with car owners',
                              style: TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                      _CountBadge(count: _items.length),
                    ],
                  ),
                  SizedBox(height: 4.w),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search conversations',
                      prefixIcon: const Icon(Icons.search, color: _muted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.w),
                        borderSide: const BorderSide(color: Color(0xffe8e9ed)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.w),
                        borderSide: const BorderSide(color: Color(0xffe8e9ed)),
                      ),
                    ),
                  ),
                  SizedBox(height: 3.w),
                  if (visible.isEmpty)
                    _EmptyChatState(hasSearch: query.isNotEmpty)
                  else
                    ...visible.map(
                      (item) => _ConversationTile(
                        name: _name(item),
                        presence: _presence(item),
                        preview: _preview(item),
                        image: _image(item),
                        active: item['isOnline'] == true,
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ChatConversationScreen(conversation: item),
                              ),
                            )
                            .then((_) => _load()),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.w),
    decoration: BoxDecoration(
      color: const Color(0xffffe7e8),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      '$count',
      style: const TextStyle(color: _red, fontWeight: FontWeight.w800),
    ),
  );
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.hasSearch});
  final bool hasSearch;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(top: 10.w),
    padding: EdgeInsets.symmetric(vertical: 12.w, horizontal: 8.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(5.w),
      border: Border.all(color: const Color(0xffe8e9ed)),
    ),
    child: Column(
      children: [
        Container(
          width: 20.w,
          height: 20.w,
          decoration: const BoxDecoration(
            color: Color(0xffffe7e8),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: _red,
            size: 10.w,
          ),
        ),
        SizedBox(height: 3.w),
        Text(
          hasSearch ? 'No matching chats' : 'No chats yet',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        SizedBox(height: 1.w),
        Text(
          hasSearch
              ? 'Try another name.'
              : 'Open a car and tap Chat with owner to start.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
      ],
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.name,
    required this.presence,
    required this.preview,
    required this.image,
    required this.active,
    required this.onTap,
  });
  final String name, presence, preview;
  final String? image;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 2.w),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4.w),
      border: Border.all(color: const Color(0xffe8e9ed)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.w),
      leading: _Avatar(image: image, active: active, size: 14.w),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: .8.w),
          Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _muted),
          ),
          SizedBox(height: .8.w),
          Row(
            children: [
              Container(
                width: 2.w,
                height: 2.w,
                decoration: BoxDecoration(
                  color: active ? Colors.green : const Color(0xffb4b8c0),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 1.5.w),
              Text(
                presence,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.green.shade700 : _muted,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.image,
    required this.active,
    required this.size,
  });
  final String? image;
  final bool active;
  final double size;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(image == null ? 3.w : 0),
        decoration: const BoxDecoration(
          color: Color(0xffffe7e8),
          shape: BoxShape.circle,
        ),
        child: image == null
            ? const Icon(Icons.person_outline_rounded, color: _red)
            : ClipOval(
                child: Image.network(
                  image!.startsWith('http')
                      ? image!
                      : '${Info.imageUrl}/$image',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person_outline_rounded, color: _red),
                ),
              ),
      ),
      if (active)
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 4.w,
            height: 4.w,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ],
  );
}

class ChatConversationScreen extends StatefulWidget {
  const ChatConversationScreen({super.key, required this.conversation});
  final Map<String, dynamic> conversation;
  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _cars = [];
  final Map<String, Map<String, dynamic>> _sharedCars = {};
  final Set<String> _loadingSharedCars = {};
  File? _pendingImage;
  bool _loading = true, _sending = false, _carsLoading = false;
  String? _currentUserId;

  String get _id =>
      '${widget.conversation['id'] ?? widget.conversation['conversationId'] ?? ''}';
  Map<String, dynamic>? get _recipient {
    final value =
        widget.conversation['recipient'] ?? widget.conversation['otherUser'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String get _title =>
      '${_recipient?['name'] ?? widget.conversation['name'] ?? widget.conversation['title'] ?? 'Carva user'}';
  String? get _recipientId {
    final value =
        _recipient?['userId'] ??
        _recipient?['id'] ??
        widget.conversation['recipientUserId'];
    return value == null ? null : '$value';
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 7),
      (_) => _load(silent: true),
    );
  }

  Future<void> _loadCurrentUser() async {
    final profile = await GetIt.I<SecureStorage>().getUserData();
    if (mounted) setState(() => _currentUserId = profile?.userId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final result = await _chatApi.post<dynamic>(
        '/chat/messages',
        data: {'conversationId': _id},
      );
      final raw = result is List
          ? result
          : result is Map
          ? (result['messages'] ?? result['data'] ?? const [])
          : const [];
      if (mounted)
        setState(() {
          _messages = (raw is List ? raw : const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      _loadSharedCarsFromMessages();
    } catch (_) {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send({String? carId, Map<String, dynamic>? sharedCar}) async {
    if (_sending ||
        (_text.text.trim().isEmpty && _pendingImage == null && carId == null))
      return;
    setState(() => _sending = true);
    try {
      // Keep a small body for car-only messages because the API validates the
      // message body even when `carId` is present. The renderer hides this
      // marker and shows the rich car card instead.
      final carPayload =
          sharedCar ?? (carId == null ? null : _sharedCars[carId]);
      final sharedMarker = carPayload == null
          ? (carId == null ? '' : 'Shared car')
          : '$_sharedCarMarker${jsonEncode(_sharedCarPayload(carPayload))}';
      final body = [
        if (_text.text.trim().isNotEmpty) _text.text.trim(),
        if (sharedMarker.isNotEmpty) sharedMarker,
      ].join('\n');
      final data = FormData.fromMap({
        'conversationId': _id,
        if (body.isNotEmpty) 'body': body,
        if (carId != null) 'carId': carId,
        if (_pendingImage != null)
          'image': await MultipartFile.fromFile(
            _pendingImage!.path,
            filename: _pendingImage!.uri.pathSegments.last,
            contentType: MediaType.parse(getMimeType(_pendingImage!.path)),
          ),
      });
      await _chatApi.post<dynamic>(
        '/chat/send',
        data: data,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );
      _text.clear();
      _pendingImage = null;
      await _load(silent: true);
    } catch (error) {
      if (mounted) {
        final message = error is ApiException && error.message.isNotEmpty
            ? error.message
            : 'Message could not be sent';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Map<String, dynamic>? _messageCar(Map<String, dynamic> message) {
    final bodyCar = _decodeSharedCar('${message['body'] ?? ''}');
    if (bodyCar != null) return bodyCar;
    final value = message['car'] ?? message['sharedCar'];
    if (value is Map) return Map<String, dynamic>.from(value);
    final carId = message['carId'] ?? message['car_id'];
    if (carId == null || '$carId'.isEmpty) return null;
    return _sharedCars['$carId'] ?? {'id': '$carId'};
  }

  Future<void> _loadSharedCarsFromMessages() async {
    final ids = _messages
        .map(
          (message) =>
              message['carId'] ??
              message['car_id'] ??
              _decodeSharedCar('${message['body'] ?? ''}')?['carId'] ??
              _decodeSharedCar('${message['body'] ?? ''}')?['id'],
        )
        .where((id) => id != null && '$id'.isNotEmpty)
        .map((id) => '$id')
        .toSet();
    for (final id in ids) {
      if (_sharedCars.containsKey(id) || _loadingSharedCars.contains(id)) {
        continue;
      }
      _loadingSharedCars.add(id);
      try {
        final result = await _chatApi.post<dynamic>(
          '/user/carDetails',
          data: {'id': id},
        );
        final raw = result is Map && result['data'] is Map
            ? result['data']
            : result;
        if (raw is Map && mounted) {
          setState(() => _sharedCars[id] = Map<String, dynamic>.from(raw));
        }
      } catch (_) {
        // Keep the id-only preview. The card can still be opened when the
        // server supplies the details in a later message response.
      } finally {
        _loadingSharedCars.remove(id);
      }
    }
    if (mounted) setState(() {});
  }

  void _rememberSharedCar(Map<String, dynamic> car) {
    for (final value in [car['carId'], car['id']]) {
      if (value != null && '$value'.isNotEmpty) _sharedCars['$value'] = car;
    }
  }

  Future<void> _pickImage() async {
    final image = await selectImageWithPermissionPrompt(context);
    if (image != null && mounted) setState(() => _pendingImage = image);
  }

  String _presence() {
    final raw =
        _recipient?['lastSeen'] ??
        _recipient?['lastSeenAt'] ??
        widget.conversation['lastSeen'] ??
        widget.conversation['lastSeenAt'];
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (widget.conversation['isOnline'] == true ||
        (date != null && DateTime.now().difference(date).inMinutes < 10))
      return 'Active now';
    if (date == null) return 'Last seen unavailable';
    return DateTime.now().difference(date).inDays < 7
        ? 'Last active ${DateFormat('EEEE').format(date)}'
        : 'Last active ${DateFormat('MMM d, yyyy').format(date)}';
  }

  Future<void> _loadCars() async {
    if (_carsLoading) return;
    setState(() => _carsLoading = true);
    try {
      final recipientCompany = _recipient?['company'];
      final companyId =
          widget.conversation['companyId'] ??
          _recipient?['companyId'] ??
          (recipientCompany is Map ? recipientCompany['id'] : null);
      final result = await _chatApi.post<dynamic>(
        '/user/getCars',
        data: {
          'companyId': companyId,
          'cursor': null,
          'type': null,
          'brand': null,
        },
      );
      final raw = result is List
          ? result
          : result is Map
          ? (result['cars'] ?? result['data'] ?? const [])
          : const [];
      if (mounted)
        setState(() {
          _cars = (raw is List ? raw : const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _carsLoading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _cars = [];
          _carsLoading = false;
        });
    }
  }

  Future<void> _showCars() async {
    await _loadCars();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CarsSheet(
        cars: _cars,
        loading: _carsLoading,
        onSelect: (car) {
          Navigator.pop(context);
          _rememberSharedCar(car);
          _send(carId: '${car['carId'] ?? car['id'] ?? ''}', sharedCar: car);
        },
      ),
    );
  }

  Future<void> _showProfile() async {
    Map<String, dynamic> profile = _recipient ?? {};
    try {
      if (_recipientId != null) {
        final result = await _chatApi.post<dynamic>(
          '/chat/profile',
          data: {'userId': _recipientId},
        );
        if (result is Map)
          profile = Map<String, dynamic>.from(
            result['data'] is Map ? result['data'] : result,
          );
      }
    } catch (_) {}
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 5.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Avatar(
                  image: profile['image']?.toString(),
                  active: _presence() == 'Active now',
                  size: 17.w,
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${profile['name'] ?? _title}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      if (profile['email'] != null)
                        Text(
                          '${profile['email']}',
                          style: const TextStyle(color: _muted),
                        ),
                      SizedBox(height: 1.w),
                      Text(_presence(), style: const TextStyle(color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.w),
            if (profile['kycStatus'] == 'approved')
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.blue),
                  SizedBox(width: 2),
                  Text(
                    'KYC verified',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            SizedBox(height: 4.w),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showCars();
                },
                icon: const Icon(Icons.directions_car_filled_outlined),
                label: const Text('Show their cars'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = _presence() == 'Active now';
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _showProfile,
          child: Row(
            children: [
              _Avatar(
                image: _recipient?['image']?.toString(),
                active: online,
                size: 11.w,
              ),
              SizedBox(width: 2.5.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    Text(
                      _presence(),
                      style: TextStyle(
                        fontSize: 11,
                        color: online ? Colors.green.shade700 : _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(4.w, 4.w, 4.w, 4.w),
                    children: [
                      if (widget.conversation['car'] is Map)
                        _SharedCarCard(
                          car: Map<String, dynamic>.from(
                            widget.conversation['car'],
                          ),
                        ),
                      if (_messages.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 25),
                          child: Center(
                            child: Text(
                              'Start the conversation',
                              style: TextStyle(color: _muted),
                            ),
                          ),
                        ),
                      ..._messages.map(
                        (message) => _MessageBubble(
                          message: message,
                          sharedCar: _messageCar(message),
                          currentUserId: _currentUserId,
                        ),
                      ),
                      SizedBox(height: 2.w),
                    ],
                  ),
          ),
          _Composer(
            text: _text,
            image: _pendingImage,
            sending: _sending,
            onPickImage: _pickImage,
            onPickCar: _showCars,
            onRemoveImage: () => setState(() => _pendingImage = null),
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.text,
    required this.image,
    required this.sending,
    required this.onPickImage,
    required this.onPickCar,
    required this.onRemoveImage,
    required this.onSend,
  });
  final TextEditingController text;
  final File? image;
  final bool sending;
  final VoidCallback onPickImage, onPickCar, onRemoveImage, onSend;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: EdgeInsets.fromLTRB(3.w, 2.w, 3.w, 2.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xffe5e6ea))),
      ),
      child: Column(
        children: [
          if (image != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(bottom: 2.w),
                padding: EdgeInsets.all(1.5.w),
                decoration: BoxDecoration(
                  color: const Color(0xffffe7e8),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1.w),
                      child: Image.file(
                        image!,
                        width: 14.w,
                        height: 14.w,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    const Text(
                      'Photo ready',
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: onRemoveImage,
                      icon: const Icon(Icons.close, color: _red, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Add photo',
                onPressed: sending ? null : onPickImage,
                icon: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _red,
                ),
              ),
              IconButton(
                tooltip: 'Send a car',
                onPressed: sending ? null : onPickCar,
                icon: const Icon(
                  Icons.directions_car_filled_outlined,
                  color: _red,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: text,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    filled: true,
                    fillColor: const Color(0xfff3f4f6),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 3.w,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5.w),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Container(
                width: 12.w,
                height: 12.w,
                decoration: const BoxDecoration(
                  color: _red,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? SizedBox(
                          width: 5.w,
                          height: 5.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CarsSheet extends StatelessWidget {
  const _CarsSheet({
    required this.cars,
    required this.loading,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> cars;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelect;
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .72,
    minChildSize: .45,
    maxChildSize: .92,
    expand: false,
    builder: (_, controller) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(5.w, 4.w, 5.w, 2.w),
            child: Row(
              children: [
                const Icon(Icons.directions_car_filled_rounded, color: _red),
                SizedBox(width: 2.w),
                const Expanded(
                  child: Text(
                    'Choose a car to share',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select one of their available cars.',
                style: TextStyle(color: _muted),
              ),
            ),
          ),
          SizedBox(height: 2.w),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : cars.isEmpty
                ? const Center(child: Text('No public cars available'))
                : ListView.separated(
                    controller: controller,
                    padding: EdgeInsets.all(5.w),
                    itemCount: cars.length,
                    separatorBuilder: (_, __) => SizedBox(height: 3.w),
                    itemBuilder: (_, index) => _CarChoice(
                      car: cars[index],
                      onTap: () => onSelect(cars[index]),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _CarChoice extends StatelessWidget {
  const _CarChoice({required this.car, required this.onTap});
  final Map<String, dynamic> car;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final image =
        car['image'] ??
        car['imageUrl'] ??
        (car['images'] is List && (car['images'] as List).isNotEmpty
            ? ((car['images'] as List).first is Map
                  ? (car['images'] as List).first['image']
                  : (car['images'] as List).first)
            : null);
    final imageUrl = image == null
        ? null
        : '$image'.startsWith('http')
        ? '$image'
        : '${Info.imageUrl}/$image';
    final feature = car['feature'] is Map ? car['feature'] as Map : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.w),
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: const Color(0xfffafafa),
          border: Border.all(color: const Color(0xffe3e4e8)),
          borderRadius: BorderRadius.circular(4.w),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.w),
              child: imageUrl == null
                  ? Container(
                      width: 25.w,
                      height: 18.w,
                      color: const Color(0xffffe7e8),
                      child: const Icon(
                        Icons.directions_car_filled,
                        color: _red,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      width: 25.w,
                      height: 18.w,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 25.w,
                        height: 18.w,
                        color: const Color(0xffffe7e8),
                        child: const Icon(
                          Icons.directions_car_filled,
                          color: _red,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${car['title'] ?? car['name'] ?? 'Car'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  if (car['year'] != null || feature?['year'] != null)
                    Text(
                      '${car['year'] ?? feature?['year']}',
                      style: const TextStyle(color: _muted),
                    ),
                  SizedBox(height: 1.w),
                  const Text(
                    'Send this car',
                    style: TextStyle(color: _red, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.send_rounded, color: _red),
          ],
        ),
      ),
    );
  }
}

class _SharedCarCard extends StatelessWidget {
  const _SharedCarCard({required this.car, this.onTap});
  final Map<String, dynamic> car;
  final VoidCallback? onTap;

  String? _imageUrl() {
    final image =
        car['image'] ??
        car['imageUrl'] ??
        (car['images'] is List && (car['images'] as List).isNotEmpty
            ? ((car['images'] as List).first is Map
                  ? (car['images'] as List).first['image']
                  : (car['images'] as List).first)
            : null);
    if (image == null || '$image'.isEmpty) return null;
    return '$image'.startsWith('http') ? '$image' : '${Info.imageUrl}/$image';
  }

  String? _value(String key) {
    final feature = car['feature'] is Map
        ? Map<String, dynamic>.from(car['feature'])
        : <String, dynamic>{};
    final value = car[key] ?? feature[key];
    if (value == null || '$value'.trim().isEmpty) return null;
    if (value is Map) {
      return '${value['en'] ?? value['name'] ?? value['title'] ?? value['value'] ?? ''}'
          .trim();
    }
    return '$value';
  }

  String? _plan() {
    final plans = car['rentalPlan'] ?? car['rentalPlans'];
    if (plans is! List || plans.isEmpty || plans.first is! Map) return null;
    final plan = Map<String, dynamic>.from(plans.first as Map);
    final price = plan['price'];
    if (price == null || '$price'.isEmpty) return null;
    final currency = plan['currency'] ?? '';
    final period = plan['periodType'] ?? plan['period'] ?? '';
    return '$price $currency${period.toString().isEmpty ? '' : ' / $period'}'
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();
    final title = '${car['title'] ?? car['name'] ?? 'Car shared in this chat'}';
    final details = <String>[
      if (_value('year') != null) _value('year')!,
      if (_value('type') != null) _value('type')!,
      if (_value('transmission') != null) _value('transmission')!,
      if (_plan() != null) _plan()!,
    ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3.5.w),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.w),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffe5e6ea)),
          borderRadius: BorderRadius.circular(3.5.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 32.w,
              width: double.infinity,
              child: imageUrl == null
                  ? const ColoredBox(
                      color: Color(0xffffe7e8),
                      child: Center(
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          color: _red,
                          size: 38,
                        ),
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xffffe7e8),
                        child: Center(
                          child: Icon(
                            Icons.directions_car_filled_rounded,
                            color: _red,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(3.w, 2.5.w, 3.w, 2.5.w),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car_filled_rounded,
                    color: _red,
                    size: 19,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          SizedBox(height: 1.w),
                          Text(
                            details.join('  •  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 2.w),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _red,
                    size: 19,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.sharedCar,
    this.currentUserId,
  });
  final Map<String, dynamic> message;
  final Map<String, dynamic>? sharedCar;
  final String? currentUserId;
  @override
  Widget build(BuildContext context) {
    final sender = message['sender'] is Map
        ? Map<String, dynamic>.from(message['sender'])
        : const <String, dynamic>{};
    final senderId =
        message['senderId'] ??
        message['fromUserId'] ??
        sender['userId'] ??
        sender['id'];
    final explicitMine =
        message['isMine'] ?? message['fromMe'] ?? message['mine'];
    final mine = explicitMine is bool
        ? explicitMine
        : senderId != null &&
              (senderId == currentUserId ||
                  senderId == message['currentUserId']);
    final body = '${message['body'] ?? ''}';
    final markerIndex = body.indexOf(_sharedCarMarker);
    final bodyWithoutCar = markerIndex >= 0
        ? body.substring(0, markerIndex).trim()
        : body;
    final interestIndex = bodyWithoutCar.toLowerCase().indexOf(
      'interested in:',
    );
    final visibleBody = interestIndex >= 0
        ? bodyWithoutCar.substring(0, interestIndex).trim()
        : bodyWithoutCar;
    final card = sharedCar ?? _decodeSharedCar(body);
    final displayBody =
        visibleBody.toLowerCase() == 'shared car' && card != null
        ? ''
        : visibleBody;
    final image = message['imageUrl'] ?? message['image'];
    final url = image == null
        ? null
        : '$image'.startsWith('http')
        ? '$image'
        : '${Info.imageUrl}/$image';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 2.w),
        padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 2.5.w),
        constraints: BoxConstraints(maxWidth: 82.w),
        decoration: BoxDecoration(
          color: mine ? _skyBlue : Colors.white,
          border: mine ? null : Border.all(color: const Color(0xffe5e6ea)),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(5.w),
            topRight: Radius.circular(5.w),
            bottomLeft: Radius.circular(mine ? 5.w : 1.w),
            bottomRight: Radius.circular(mine ? 1.w : 5.w),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card != null)
              _SharedCarCard(
                car: card,
                onTap: () {
                  final id = card['carId'] ?? card['id'];
                  if (id != null && '$id'.isNotEmpty) {
                    context.router.push(CarDetailsRoute(carId: '$id'));
                  }
                },
              ),
            if (url != null)
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.black,
                    child: InteractiveViewer(child: Image.network(url)),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3.w),
                  child: Image.network(
                    url,
                    height: 38.w,
                    width: 70.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (displayBody.isNotEmpty)
              Text(
                displayBody,
                style: TextStyle(
                  color: mine ? Colors.white : _ink,
                  height: 1.35,
                ),
              ),
            if (message['createdAt'] != null)
              Padding(
                padding: EdgeInsets.only(top: 1.w),
                child: Text(
                  DateFormat('h:mm a').format(
                    DateTime.tryParse('${message['createdAt']}')?.toLocal() ??
                        DateTime.now(),
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    color: mine ? Colors.white70 : _muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
