import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/company/data/model/company.dart';
import 'package:kcars/features/chat/presentation/screen/chat_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';

Future<void> showCompanyContextPreview(
  BuildContext context,
  Company company,
) async {
  AppHaptics.mediumAction();
  final router = context.router.root;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    showDragHandle: true,
    barrierColor: Colors.black.withValues(alpha: .38),
    backgroundColor: Colors.transparent,
    builder: (_) => _CompanyContextPreview(company: company, router: router),
  );
}

class _CompanyContextPreview extends StatelessWidget {
  const _CompanyContextPreview({required this.company, required this.router});
  final Company company;
  final StackRouter router;

  void _openCompany(BuildContext context) {
    Navigator.of(context).pop();
    router.push(CompanyDetailsRoute(companyId: company.id));
  }

  Future<void> _messageCompany(BuildContext context) async {
    try {
      final result = await GetIt.I<ApiService>().post<dynamic>(
        '/chat/start',
        data: {'companyId': company.id},
      );
      final conversation = result is Map
          ? Map<String, dynamic>.from(
              result['conversation'] is Map ? result['conversation'] : result,
            )
          : <String, dynamic>{};
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(conversation: conversation),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Messaging is unavailable right now')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 2.w),
      child: IOSGlassSurface(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
          bottom: Radius.circular(28),
        ),
        padding: EdgeInsets.all(3.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ImageHolder(
                  image: company.coverImage,
                  type: ImageType.company,
                  width: double.infinity,
                  height: 34.w,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(20),
                ),
                Transform.translate(
                  offset: Offset(0, 8.w),
                  child: ImageHolder(
                    image: company.image,
                    type: ImageType.company,
                    width: 18.w,
                    height: 18.w,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.w),
            Center(
              child: Text(
                company.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.title3SemiBold,
              ),
            ),
            if (company.cars != null) ...[
              SizedBox(height: 1.w),
              Center(
                child: Text(
                  '${company.cars} cars',
                  style: context.caption.copyWith(color: context.outline),
                ),
              ),
            ],
            SizedBox(height: 3.w),
            Row(
              children: [
                _CompanyAction(
                  icon: Icons.business_outlined,
                  label: 'View company',
                  onTap: () => _openCompany(context),
                ),
                _CompanyAction(
                  icon: Icons.directions_car_outlined,
                  label: 'Cars',
                  onTap: () => _openCompany(context),
                ),
                _CompanyAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () => SharePlus.instance.share(
                    ShareParams(
                      title: company.name,
                      text:
                          '${company.name}\nhttps://carvarent.com/company/${company.id}',
                    ),
                  ),
                ),
                _CompanyAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  onTap: () => _messageCompany(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyAction extends StatelessWidget {
  const _CompanyAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SpringPressable(
        onTap: onTap,
        semanticsLabel: label,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 2.w),
          child: Column(
            children: [
              Icon(icon, color: context.primary, size: 6.w),
              SizedBox(height: 1.w),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.caption.copyWith(fontSize: 10.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
