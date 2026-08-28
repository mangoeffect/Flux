// 生成 Flux 图标:靛蓝渐变圆角方块 + 白色闪电。
// 产物:assets/app/icon_256.png(launcher 图标源)、assets/tray/icon.png、
//       assets/tray/icon.ico(16/24/32/48/64 多尺寸,适应高 DPI 托盘)。
// 用法:dart run tool/gen_icons.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

const _master = 1024;
const _radius = 0.18; // 圆角半径(相对边长)

// 白色闪电(单位坐标,y 向下)
const _bolt = [
  [0.585, 0.08],
  [0.27, 0.55],
  [0.455, 0.55],
  [0.38, 0.92],
  [0.73, 0.40],
  [0.545, 0.40],
];

void main() async {
  final img = Image(width: _master, height: _master);
  for (var y = 0; y < _master; y++) {
    for (var x = 0; x < _master; x++) {
      final px = (x + 0.5) / _master;
      final py = (y + 0.5) / _master;
      if (!_inRoundedRect(px, py)) continue;
      if (_inPolygon(px, py, _bolt)) {
        img.setPixel(x, y, ColorUint8.rgb(255, 255, 255));
      } else {
        // 顶部亮靛蓝 → 底部深靛蓝的垂直渐变
        final r = _lerp(0x5C, 0x30, py).round();
        final g = _lerp(0x6B, 0x3F, py).round();
        final b = _lerp(0xC0, 0x9F, py).round();
        img.setPixel(x, y, ColorUint8.rgb(r, g, b));
      }
    }
  }

  Image scaled(int s) => copyResize(img, width: s, height: s,
      interpolation: Interpolation.average);

  // 托盘双态:运行=彩色,停止=去饱和灰
  final runSizes = [16, 24, 32, 48, 64].map(scaled).toList();
  final stopSizes =
      [16, 24, 32, 48, 64].map((s) => _desaturate(scaled(s))).toList();

  await _write('assets/app/icon_256.png', encodePng(scaled(256)));
  await _write('assets/tray/icon_running.png', encodePng(scaled(256)));
  await _write('assets/tray/icon_running.ico', _encodeIcoMulti(runSizes));
  await _write('assets/tray/icon_stopped.png', encodePng(_desaturate(scaled(256))));
  await _write('assets/tray/icon_stopped.ico', _encodeIcoMulti(stopSizes));
  stdout.writeln(
      '图标已生成:assets/app/icon_256.png + assets/tray/icon_{running,stopped}.{png,ico}');
}

/// 去饱和(亮度加权),保留 alpha。
Image _desaturate(Image img) {
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      final c = img.getPixel(x, y);
      final lum = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b).round();
      img.setPixel(x, y, ColorUint8.rgba(lum, lum, lum, c.a.toInt()));
    }
  }
  return img;
}

bool _inRoundedRect(double x, double y) {
  final dx = (x - 0.5).abs() - (0.5 - _radius);
  final dy = (y - 0.5).abs() - (0.5 - _radius);
  if (dx <= 0 || dy <= 0) return true;
  return dx * dx + dy * dy <= _radius * _radius;
}

bool _inPolygon(double px, double py, List<List<double>> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i][0], yi = poly[i][1];
    final xj = poly[j][0], yj = poly[j][1];
    final hit = ((yi > py) != (yj > py)) &&
        (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
    if (hit) inside = !inside;
  }
  return inside;
}

double _lerp(int a, int b, double t) => a + (b - a) * t;

/// 多尺寸 ICO:PNG 条目(Vista+ 均支持)。
Uint8List _encodeIcoMulti(List<Image> images) {
  final pngs = images.map(encodePng).toList();
  final b = BytesBuilder();
  b.add([0, 0, 1, 0, images.length]); // reserved | type=icon | count
  var offset = 6 + 16 * images.length;
  for (var i = 0; i < images.length; i++) {
    final s = images[i].width;
    final dim = s >= 256 ? 0 : s;
    b.add([dim, dim, 0, 0, 1, 0, 32, 0]); // w | h | colors | rsv | planes | bpp
    b.add(_u32(pngs[i].length));
    b.add(_u32(offset));
    offset += pngs[i].length;
  }
  pngs.forEach(b.add);
  return b.toBytes();
}

List<int> _u32(int v) => [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];

Future<void> _write(String path, List<int> bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes);
}
