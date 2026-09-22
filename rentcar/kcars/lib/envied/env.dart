/// Runtime endpoints used by the mobile client.
///
/// These were previously generated into an ignored `env.g.dart` file. Keeping
/// the values here makes clean APK builds reproducible and avoids a missing
/// generated part when the source is checked out on another machine.
abstract class Env {
  static const String baseUrl = 'https://carvarent.com/api/v1';
  static const String oneSignal = '3a348b1a-a27b-4ad5-8bff-2356b48aa4d8';
  static const String imageUrl = 'https://kcarsbucket.s3.amazonaws.com';
}
