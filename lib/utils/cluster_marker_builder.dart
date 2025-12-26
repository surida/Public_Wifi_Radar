import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ClusterMarkerBuilder {
  // Cache for generated bitmaps to avoid regeneration
  static final Map<String, BitmapDescriptor> _cache = {};

  /// Gets a cluster icon based on count
  static Future<BitmapDescriptor> getClusterIcon(int count) async {
    final cacheKey = _getCacheKey(count);
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final size = _calculateSize(count);
    final color = _getColorForCount(count);

    final icon = await _createClusterBitmap(size, count.toString(), color);
    _cache[cacheKey] = icon;

    return icon;
  }

  /// Size scaling formula based on marker count
  static int _calculateSize(int count) {
    // Base size: 60, scales logarithmically
    // 1-9: 60, 10-99: 80, 100-999: 100, 1000+: 120
    if (count < 10) return 60;
    if (count < 100) return 80;
    if (count < 1000) return 100;
    return 120;
  }

  /// Color based on cluster density
  static Color _getColorForCount(int count) {
    if (count < 10) return Colors.blue;
    if (count < 50) return Colors.teal;
    if (count < 100) return Colors.orange;
    return Colors.red;
  }

  /// Cache key based on count bucket
  static String _getCacheKey(int count) {
    if (count < 10) return 'small_$count';
    if (count < 100) return 'medium_${(count ~/ 10) * 10}';
    if (count < 1000) return 'large_${(count ~/ 100) * 100}';
    return 'xlarge_${(count ~/ 1000) * 1000}';
  }

  /// Creates the bitmap for cluster markers
  static Future<BitmapDescriptor> _createClusterBitmap(
    int size,
    String text,
    Color color,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double sizeDouble = size.toDouble();

    // Outer circle (cluster background)
    final Paint outerPaint = Paint()..color = color;
    canvas.drawCircle(
      Offset(sizeDouble / 2, sizeDouble / 2),
      sizeDouble / 2.0,
      outerPaint,
    );

    // Inner circle (white border effect)
    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = sizeDouble / 15;
    canvas.drawCircle(
      Offset(sizeDouble / 2, sizeDouble / 2),
      sizeDouble / 2.5,
      innerPaint,
    );

    // Text (count number in center)
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: sizeDouble / 3,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        sizeDouble / 2 - textPainter.width / 2,
        sizeDouble / 2 - textPainter.height / 2,
      ),
    );

    final ui.Image img = await recorder.endRecording().toImage(size, size);
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  /// Clear cache (call when memory pressure is detected)
  static void clearCache() {
    _cache.clear();
  }
}
