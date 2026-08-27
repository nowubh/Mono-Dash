import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/presentation/features/cronjobs/providers/cronjob_provider.dart';

void main() {
  test('cronjob enabled status is case-insensitive', () {
    expect(cronjobStatusIsEnabled('enable'), isTrue);
    expect(cronjobStatusIsEnabled('Enable'), isTrue);
    expect(cronjobStatusIsEnabled('disable'), isFalse);
  });
}
