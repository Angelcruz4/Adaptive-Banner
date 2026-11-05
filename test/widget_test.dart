import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_anuncio/main.dart';

void main() {
  testWidgets(
    'inserta un anuncio después de cada diez elementos',
    (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InterleavedFeedList(
            itemCount: 33,
            itemsPerAd: 10,
            itemBuilder: (context, index) => Text('Contenido ${index + 1}'),
            adBuilder: (context, index) => SizedBox(
              height: 32,
              child: Text('Anuncio ${index + 1}'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Anuncio 1'), findsOneWidget);
    expect(find.text('Anuncio 2'), findsOneWidget);
    expect(find.text('Anuncio 3'), findsOneWidget);
    expect(find.text('Contenido 33'), findsOneWidget);

    final firstAdY = tester.getTopLeft(find.text('Anuncio 1')).dy;
    final secondAdY = tester.getTopLeft(find.text('Anuncio 2')).dy;
    final thirdAdY = tester.getTopLeft(find.text('Anuncio 3')).dy;

    expect(
      firstAdY,
      greaterThan(tester.getTopLeft(find.text('Contenido 10')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Contenido 11')).dy,
      greaterThan(firstAdY),
    );
    expect(
      secondAdY,
      greaterThan(tester.getTopLeft(find.text('Contenido 20')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Contenido 21')).dy,
      greaterThan(secondAdY),
    );
    expect(
      thirdAdY,
      greaterThan(tester.getTopLeft(find.text('Contenido 30')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Contenido 31')).dy,
      greaterThan(thirdAdY),
    );
  });
}
