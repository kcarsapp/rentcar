import 'package:share_plus/share_plus.dart';
import 'package:kcars/features/car/data/model/car.dart';

String carLink(Car car) => "https://carvarent.com/car/${car.carId}";

/// Shares a car as its title + link through the system share sheet.
///
/// The site serves a per-car og:image (the car's actual photo), so the
/// link unfurls into a photo preview in WhatsApp, Messenger, Telegram…
/// — no file attachment needed, which is also what fixes Messenger
/// (it drops the text when a file is attached).
Future<void> shareCar(Car car) async {
  await SharePlus.instance.share(
    ShareParams(text: "${car.title}\n${carLink(car)}", subject: car.title),
  );
}
