import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_remote_app/app.dart';

void main() {
  testWidgets('Traffic Remote starts', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafficRemoteApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
