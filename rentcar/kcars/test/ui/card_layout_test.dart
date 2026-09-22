import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kcars/core/services/app_icons.dart';
import 'package:kcars/core/widget/bottm_bar.dart';
import 'package:kcars/features/car/data/model/car.dart';
import 'package:kcars/features/car/data/model/enums.dart';
import 'package:kcars/features/car/data/model/feature.dart';
import 'package:kcars/features/car/data/model/rental_plan.dart';
import 'package:kcars/features/car/presentation/views/all_cars_view.dart';
import 'package:kcars/features/car/presentation/widget/car_widget_view.dart';
import 'package:kcars/features/car/presentation/widget/featured_hero_card.dart';
import 'package:kcars/translations/codegen_loader.g.dart';
import 'package:sizer/sizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async => call.method == 'getAll' ? <String, Object>{} : true,
        );
    await EasyLocalization.ensureInitialized();
  });

  final car = Car(
    id: 'layout-fixture',
    title: 'Jeep Grand Cherokee L Limited',
    listedAt: DateTime(2026),
    images: [],
    feature: Feature(
      year: 2019,
      transmission: Transmission.automatic,
      odometer: 42000,
    ),
    displayPlan: RentalPeriodType.monthly,
    rentalPlan: [
      RentalPlan(
        id: 'monthly',
        price: 1200000,
        currency: Currency.iqd,
        periodType: RentalPeriodType.monthly,
      ),
    ],
  );

  Future<void> mount(
    WidgetTester tester,
    Widget child,
    double scale, {
    bool rtl = false,
  }) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [Locale('en')],
          startLocale: const Locale('en'),
          path: 'assets/translations',
          assetLoader: const CodegenLoader(),
          child: Sizer(
            builder: (context, orientation, deviceType) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF3957D7),
                ),
              ),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 900),
                  textScaler: TextScaler.linear(scale),
                ),
                child: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Scaffold(body: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final rtl in [false, true]) {
    testWidgets(
      'Featured and list cards fit narrow screen with larger text, RTL=$rtl',
      (tester) async {
        await mount(
          tester,
          SingleChildScrollView(
            child: Column(
              children: [
                FeaturedHeroCarousel(cars: [car], isLoggedIn: false),
                CarsWidget(car: car),
              ],
            ),
          ),
          1.4,
          rtl: rtl,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('2019'), findsOneWidget);
        expect(find.text('Automatic'), findsOneWidget);
        expect(find.textContaining('Per month'), findsNWidgets(2));
      },
    );
  }

  testWidgets('Two-card rail fits long names and an empty photo list', (
    tester,
  ) async {
    await mount(
      tester,
      SizedBox(
        height: 224,
        child: Column(
          children: [
            CarWidget(cars: [car]),
          ],
        ),
      ),
      1.4,
    );
    expect(tester.takeException(), isNull);
    expect(find.text(car.title), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Navigation highlights the routed tab and reports taps', (
    tester,
  ) async {
    int? tapped;
    await mount(
      tester,
      CustomBottomNavigationBar(
        activeIndex: 1,
        onTap: (index) => tapped = index,
        tabs: [
          BottmBarModel(
            lable: 'Cars',
            icon: AppIcons.car,
            activeIcon: AppIcons.carActive,
          ),
          BottmBarModel(
            lable: 'Chat',
            icon: AppIcons.chat,
            activeIcon: AppIcons.chatActive,
          ),
          BottmBarModel(
            lable: 'Companies',
            icon: AppIcons.company,
            activeIcon: AppIcons.companyFill,
          ),
          BottmBarModel(
            lable: 'Settings',
            icon: AppIcons.settings,
            activeIcon: AppIcons.settingsActive,
          ),
        ],
      ),
      1.4,
    );
    expect(tester.takeException(), isNull);
    final semantics = tester.widgetList<Semantics>(
      find.ancestor(of: find.text('Chat'), matching: find.byType(Semantics)),
    );
    expect(semantics.any((node) => node.properties.selected == true), isTrue);
    await tester.tap(find.text('Companies'));
    expect(tapped, 2);
  });
}
