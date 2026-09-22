import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/core/utils/permissions.dart';
import 'package:sizer/sizer.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _api = GetIt.I<ApiService>();
  String _type = 'national_id';
  File? _front;
  File? _back;
  String _status = 'unverified';
  String? _reason;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final response = await _api.post<dynamic>('/user/kyc/status', data: {});
      final map = response is Map
          ? Map<String, dynamic>.from(
              response['data'] is Map ? response['data'] : response,
            )
          : <String, dynamic>{};
      if (mounted)
        setState(() {
          _status = '${map['status'] ?? map['kycStatus'] ?? 'unverified'}';
          _reason = map['rejectionReason']?.toString();
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool back) async {
    final image = await selectImageWithPermissionPrompt(context);
    if (image == null || !mounted) return;
    setState(() {
      if (back) {
        _back = image;
      } else {
        _front = image;
      }
    });
  }

  Future<void> _submit() async {
    if (_front == null || (_type != 'passport' && _back == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload the required document photos'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final form = FormData.fromMap({
        'documentType': _type,
        'documentFront': await MultipartFile.fromFile(
          _front!.path,
          filename: 'document-front.jpg',
        ),
        if (_back != null)
          'documentBack': await MultipartFile.fromFile(
            _back!.path,
            filename: 'document-back.jpg',
          ),
      });
      await _api.post<dynamic>('/user/kyc/submit', data: form);
      if (!mounted) return;
      setState(() {
        _status = 'pending';
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('KYC submitted for admin review')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC submission failed. Please try again.'),
          ),
        );
      }
    }
  }

  String get _statusText => switch (_status) {
    'approved' => 'Verified',
    'pending' => 'Waiting for admin approval',
    'rejected' => 'Rejected',
    _ => 'Not verified',
  };

  @override
  Widget build(BuildContext context) {
    final approved = _status == 'approved';
    final locked = approved || _status == 'pending';
    return Scaffold(
      backgroundColor: const Color(0xfffafafa),
      appBar: AppBar(
        title: const Text('Identity verification'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(5.w, 3.w, 5.w, 10.w),
              children: [
                Container(
                  padding: EdgeInsets.all(4.5.w),
                  decoration: BoxDecoration(
                    color: approved ? const Color(0xffe8f3ff) : Colors.white,
                    border: Border.all(
                      color: approved
                          ? const Color(0xffb9d9ff)
                          : const Color(0xffe8e8ea),
                    ),
                    borderRadius: BorderRadius.circular(4.w),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 13.w,
                        height: 13.w,
                        decoration: BoxDecoration(
                          color: approved
                              ? const Color(0xffd5eaff)
                              : const Color(0xffffe7e8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          approved
                              ? Icons.verified_rounded
                              : Icons.shield_outlined,
                          color: approved
                              ? const Color(0xff1976d2)
                              : const Color(0xffc51d27),
                          size: 7.w,
                        ),
                      ),
                      SizedBox(width: 3.5.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff202431),
                              ),
                            ),
                            SizedBox(height: 1.w),
                            Text(
                              approved
                                  ? 'Your account is verified.'
                                  : _status == 'pending'
                                  ? 'Your documents are being reviewed.'
                                  : 'Verify your identity to rent or publish cars.',
                              style: const TextStyle(color: Color(0xff68707f)),
                            ),
                            if (_reason != null) ...[
                              SizedBox(height: 1.w),
                              Text(
                                _reason!,
                                style: const TextStyle(
                                  color: Color(0xffc51d27),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6.w),
                const Text(
                  'Choose a document',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff202431),
                  ),
                ),
                SizedBox(height: 1.w),
                const Text(
                  'Select one document type and upload clear photos.',
                  style: TextStyle(color: Color(0xff68707f)),
                ),
                SizedBox(height: 3.w),
                _DocumentOption(
                  value: 'national_id',
                  title: 'National ID',
                  subtitle: 'Front and back photos required',
                  icon: Icons.badge_outlined,
                  selected: _type == 'national_id',
                  enabled: !locked,
                  onTap: () => setState(() {
                    _type = 'national_id';
                    _back = null;
                  }),
                ),
                SizedBox(height: 2.w),
                _DocumentOption(
                  value: 'passport',
                  title: 'Passport',
                  subtitle: 'One photo of the information page',
                  icon: Icons.menu_book_outlined,
                  selected: _type == 'passport',
                  enabled: !locked,
                  onTap: () => setState(() {
                    _type = 'passport';
                    _back = null;
                  }),
                ),
                SizedBox(height: 2.w),
                _DocumentOption(
                  value: 'driving_license',
                  title: 'Driving license',
                  subtitle: 'Front and back photos required',
                  icon: Icons.credit_card_outlined,
                  selected: _type == 'driving_license',
                  enabled: !locked,
                  onTap: () => setState(() {
                    _type = 'driving_license';
                    _back = null;
                  }),
                ),
                SizedBox(height: 5.w),
                _UploadCard(
                  label: 'Front photo',
                  file: _front,
                  icon: Icons.photo_camera_back_outlined,
                  required: true,
                  onTap: locked ? null : () => _pick(false),
                ),
                if (_type != 'passport') ...[
                  SizedBox(height: 3.w),
                  _UploadCard(
                    label: 'Back photo',
                    file: _back,
                    icon: Icons.flip_camera_android_outlined,
                    required: true,
                    onTap: locked ? null : () => _pick(true),
                  ),
                ],
                SizedBox(height: 6.w),
                if (!approved && _status != 'pending')
                  SizedBox(
                    height: 13.w,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffc51d27),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.5.w),
                        ),
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const CircularProgressIndicator()
                          : const Text('Submit for review'),
                    ),
                  ),
                if (_status == 'pending')
                  const Text(
                    'Your documents are securely stored and will be reviewed by the general admin.',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.label,
    required this.file,
    required this.icon,
    required this.required,
    required this.onTap,
  });
  final String label;
  final File? file;
  final IconData icon;
  final bool required;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4.w),
    child: Container(
      height: 42.w,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: file == null
              ? const Color(0xffdfe1e6)
              : const Color(0xffb8dfc4),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(4.w),
      ),
      clipBehavior: Clip.antiAlias,
      child: file == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 15.w,
                  height: 15.w,
                  decoration: const BoxDecoration(
                    color: Color(0xffffe7e8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xffc51d27), size: 8.w),
                ),
                SizedBox(height: 2.w),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xff202431),
                  ),
                ),
                SizedBox(height: 1.w),
                Text(
                  required ? 'Required · Tap to choose a photo' : 'Optional',
                  style: const TextStyle(color: Color(0xff68707f)),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.file(file!, fit: BoxFit.cover),
                Positioned(
                  left: 3.w,
                  right: 3.w,
                  bottom: 3.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 2.w,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.65),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 5.w,
                        ),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            '$label added',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.edit_outlined, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class _DocumentOption extends StatelessWidget {
  const _DocumentOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(3.5.w),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: selected ? const Color(0xffffe7e8) : Colors.white,
        border: Border.all(
          color: selected ? const Color(0xffc51d27) : const Color(0xffe0e1e5),
          width: selected ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(3.5.w),
      ),
      child: Row(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xffc51d27)
                  : const Color(0xfff0f1f4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : const Color(0xff4d5563),
              size: 6.w,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? const Color(0xffa9151e)
                        : const Color(0xff202431),
                  ),
                ),
                SizedBox(height: .7.w),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff68707f),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? const Color(0xffc51d27) : const Color(0xffa6aab3),
          ),
        ],
      ),
    ),
  );
}
