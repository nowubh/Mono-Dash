import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/core/localization/generated/app_localizations.dart';
import 'package:mono_dash/presentation/common/components/app_picker.dart';

void main() {
  testWidgets('inline picker keeps list scroll notifications local', (
    tester,
  ) async {
    var parentNotifications = 0;

    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: 240,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                parentNotifications++;
                return false;
              },
              child: AppInlinePicker<int>(
                value: 0,
                onChanged: (_) {},
                options: List.generate(
                  12,
                  (i) => AppPickerOption(value: i, label: 'Option $i'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Option 0'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pump();

    expect(parentNotifications, 0);
  });
}
