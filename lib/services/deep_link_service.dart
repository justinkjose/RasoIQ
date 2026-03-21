import 'dart:async';

import 'package:app_links/app_links.dart';

typedef LinkHandler = Future<void> Function(Uri uri);

class DeepLinkService {
  DeepLinkService({required LinkHandler onLink})
      : _onLink = onLink,
        _appLinks = AppLinks();

  final LinkHandler _onLink;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;

  Future<void> start() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      await _onLink(initial);
    }
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async {
        await _onLink(uri);
      },
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
