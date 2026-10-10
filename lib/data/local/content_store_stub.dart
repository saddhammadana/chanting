import 'content_store.dart';

/// The web has nowhere to keep a fetched prayer book, and its build is
/// redeployed with the bundle anyway.
Future<ContentStore> openContentStore({required int bundledVersion}) async =>
    ContentStore(bundledVersion: bundledVersion);
