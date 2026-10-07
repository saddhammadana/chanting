import 'package:chanting/shared/widgets/app_asset_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing asset displays the product image-not-found artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppAssetImage('assets/images/home/does_not_exist.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((provider) => provider.assetName);
    expect(assetNames, contains(AppAssetImage.fallbackAsset));
  });
}
