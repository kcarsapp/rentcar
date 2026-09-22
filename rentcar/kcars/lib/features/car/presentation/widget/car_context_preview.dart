import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kcars/configs/app_router.gr.dart';
import 'package:kcars/configs/image_type.dart';
import 'package:kcars/core/services/service_location.dart';
import 'package:kcars/core/ui/ios_interactions.dart';
import 'package:kcars/core/utils/extensions.dart';
import 'package:kcars/core/widget/image_holder.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/domain/repo/car_repo.dart';
import 'package:collection/collection.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sizer/sizer.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/features/chat/presentation/screen/chat_screen.dart';

/// Native-feeling long-press preview for a car card. It uses a draggable
/// bottom sheet on Android and iOS while keeping the same actions everywhere.
Future<void> showCarContextPreview(
  BuildContext context,
  Car car, {
  bool isLoggedIn = false,
}) async {
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
    builder: (sheetContext) =>
        _CarContextPreview(car: car, router: router, isLoggedIn: isLoggedIn),
  );
}

class _CarContextPreview extends StatelessWidget {
  const _CarContextPreview({
    required this.car,
    required this.router,
    required this.isLoggedIn,
  });
  final Car car;
  final StackRouter router;
  final bool isLoggedIn;

  void _openDetails(BuildContext context) {
    Navigator.of(context).pop();
    router.push(CarDetailsRoute(carId: car.carId ?? car.id));
  }

  Future<void> _saveCar(BuildContext context) async {
    if (!isLoggedIn) {
      Navigator.of(context).pop();
      router.push(LoginRoute());
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await sl<CarRepo>().favoriteCar(car.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    result.fold(
      (failure) =>
          messenger?.showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => messenger?.showSnackBar(
        const SnackBar(content: Text('Car saved to favorites')),
      ),
    );
  }

  Future<void> _messageOwner(BuildContext context) async {
    try {
      final result = await GetIt.I<ApiService>().post<dynamic>(
        '/chat/start',
        data: {'carId': car.id, 'companyId': car.company?.id},
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
    final carId = car.carId ?? car.id;
    final image = car.images?.firstOrNull?.image;
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openDetails(context),
              child: Hero(
                tag: carImageHeroTag(carId),
                child: ImageHolder(
                  image: image,
                  type: ImageType.car,
                  width: double.infinity,
                  height: 48.w,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(height: 3.w),
            Text(
              car.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.title3SemiBold,
            ),
            if (car.feature?.year != null) ...[
              SizedBox(height: 1.w),
              Text(
                '${car.feature!.year} · ${car.feature?.transmission?.transmissionType() ?? ''}',
                style: context.caption.copyWith(color: context.outline),
              ),
            ],
            SizedBox(height: 3.w),
            Row(
              children: [
                _PreviewAction(
                  icon: Icons.directions_car_outlined,
                  label: 'View car',
                  onTap: () => _openDetails(context),
                ),
                _PreviewAction(
                  icon: Icons.bookmark_border_rounded,
                  label: 'Save',
                  onTap: () => _saveCar(context),
                ),
                _PreviewAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () => SharePlus.instance.share(
                    ShareParams(
                      title: car.title,
                      text: '${car.title}\nhttps://carvarent.com/car/$carId',
                    ),
                  ),
                ),
                _PreviewAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  onTap: () => _messageOwner(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  const _PreviewAction({
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
