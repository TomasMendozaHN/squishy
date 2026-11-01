// Renders the mascot to docs/logo.png for the README:
//   flutter test tool/render_logo_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squishy/widgets/squishy_logo.dart';

void main() {
  testWidgets('render logo', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: Container(
            width: 512,
            height: 512,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A0F45), Color(0xFF06243F)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(112)),
            ),
            alignment: Alignment.center,
            child: const SquishyLogo(size: 400, playing: false),
          ),
        ),
      ),
    );
    await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../docs/logo.png'));
  });
}
