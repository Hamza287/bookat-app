import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bookat/src/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Google mark on the sign-in button is drawn, not shipped as an asset, so
/// nothing but a render catches a mistake in its geometry. Sampling one pixel
/// per arc is enough: a wrong angle or radius moves the colours off these
/// points immediately.
void main() {
  testWidgets('shows all four brand colours in the right places',
      (tester) async {
    const extent = 48.0;
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: const ColoredBox(
              color: Color(0xFFFFFFFF),
              child: SizedBox.square(dimension: extent, child: GoogleMark()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pixels = await _readPixels(tester, boundaryKey, extent);

    // Centre is (24, 24); the ring's centre-line radius is about 17.
    expect(pixels.at(24, 7), _closeTo(const Color(0xFFEA4335)),
        reason: 'top is red');
    expect(pixels.at(7, 24), _closeTo(const Color(0xFFFBBC05)),
        reason: 'left is yellow');
    expect(pixels.at(24, 41), _closeTo(const Color(0xFF34A853)),
        reason: 'bottom is green');
    expect(pixels.at(39, 31), _closeTo(const Color(0xFF4285F4)),
        reason: 'lower right is blue');

    // The crossbar reaches in from the right at mid height.
    expect(pixels.at(34, 24), _closeTo(const Color(0xFF4285F4)),
        reason: 'crossbar is blue');

    // The G's mouth. This is what tells the mark apart from its vertical
    // mirror: flipped, the opening lands at the lower right instead and the
    // whole thing reads upside down.
    expect(pixels.at(40, 17), _closeTo(const Color(0xFFFFFFFF)),
        reason: 'upper right is the open mouth');

    // Above the crossbar the middle stays empty, or the mark is a filled disc
    // rather than a ring.
    expect(pixels.at(24, 17), _closeTo(const Color(0xFFFFFFFF)),
        reason: 'ring is hollow');
  });
}

Matcher _closeTo(Color expected) => _ColorCloseTo(expected);

/// Antialiasing shifts channels a little, so an exact match is too strict.
class _ColorCloseTo extends Matcher {
  const _ColorCloseTo(this.expected);

  final Color expected;

  static const _tolerance = 30;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! Color) {
      return false;
    }
    return _within(item.r, expected.r) &&
        _within(item.g, expected.g) &&
        _within(item.b, expected.b);
  }

  bool _within(double a, double b) =>
      ((a - b) * 255).abs().round() <= _tolerance;

  @override
  Description describe(Description description) {
    return description.add('within $_tolerance/255 per channel of $expected');
  }
}

Future<_Pixels> _readPixels(
  WidgetTester tester,
  GlobalKey key,
  double extent,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  late ByteData data;
  late int width;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });

  return _Pixels(data, width, width / extent);
}

class _Pixels {
  _Pixels(this._data, this._width, this._scale);

  final ByteData _data;
  final int _width;
  final double _scale;

  /// [x] and [y] are in the mark's own 48-unit space.
  Color at(int x, int y) {
    final offset =
        ((y * _scale).round() * _width + (x * _scale).round()) * 4;
    return Color.fromARGB(
      _data.getUint8(offset + 3),
      _data.getUint8(offset),
      _data.getUint8(offset + 1),
      _data.getUint8(offset + 2),
    );
  }
}
