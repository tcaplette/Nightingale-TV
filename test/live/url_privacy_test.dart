import 'package:flutter_test/flutter_test.dart';
import 'package:nightingale_tv/live/url_privacy.dart';

void main() {
  test("the spec's diagnostics example loses the user name and password", () {
    expect(scrubUrl('http://provider/get.php?username=a&password=b'), 'http://provider/get.php');
  });

  test('user information, ports, fragments', () {
    expect(scrubUrl('https://me:secret@iptv.example:8443/live/1.ts?token=x#f'), 'https://iptv.example:8443/live/1.ts');
    expect(scrubUrl('rtsp://cam.local/stream'), 'rtsp://cam.local/stream');
    expect(scrubUrl('not a url'), '(not a URL)');
  });

  test('masking for the UI keeps what identifies the source', () {
    expect(maskUrl('http://provider/get.php?username=a&password=b&type=m3u_plus'),
        'http://provider/get.php?username=a&password=••••&type=m3u_plus');
    expect(maskUrl('http://me:secret@host:81/list.m3u'), 'http://me:••••@host:81/list.m3u');
    expect(maskUrl('http://host/epg.xml?token=abc&key=k&api_key=z'), 'http://host/epg.xml?token=••••&key=••••&api_key=••••');
    expect(maskUrl('http://host/list.m3u'), 'http://host/list.m3u');
    expect(maskUrl('/home/me/list.m3u'), '/home/me/list.m3u');
  });

  test('URLs inside messages are scrubbed', () {
    expect(scrubUrlsIn('Failed to open http://p/get.php?username=a&password=b: 403'), 'Failed to open http://p/get.php: 403');
  });
}
