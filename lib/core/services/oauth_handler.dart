import 'dart:async';
import 'package:app_links/app_links.dart';

/// Global OAuth handler to manage OAuth callbacks
class OAuthHandler {
  static final OAuthHandler _instance = OAuthHandler._internal();
  factory OAuthHandler() => _instance;
  OAuthHandler._internal();

  final AppLinks _appLinks = AppLinks();
  Completer<String?>? _currentOAuthCompleter;
  StreamSubscription<Uri>? _uriSubscription;

  /// Initialize the OAuth handler and listen for deep links
  void initialize() {
    // Listen for URI links (when app is already running)
    _uriSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _handleUri(uri);
      },
      onError: (err) {
        if (_currentOAuthCompleter != null && !_currentOAuthCompleter!.isCompleted) {
          _currentOAuthCompleter!.completeError(err);
        }
      },
    );
  }

  /// Handle a URI callback
  void _handleUri(Uri uri) {
    if (uri.scheme == 'yantrium' && 
        uri.host == 'auth' && 
        uri.pathSegments.isNotEmpty && 
        uri.pathSegments[0] == 'trakt') {
      final code = uri.queryParameters['code'];
      if (code != null && _currentOAuthCompleter != null && !_currentOAuthCompleter!.isCompleted) {
        _currentOAuthCompleter!.complete(code);
      } else if (code != null) {
        // URI received but no active OAuth flow - this can happen if app was launched from callback
        // Just ignore it gracefully - the user can start a new OAuth flow if needed
        print('Received OAuth callback but no active OAuth flow. Ignoring.');
      }
    }
  }

  /// Start OAuth flow and return a future that completes with the authorization code
  Future<String?> startOAuthFlow() async {
    // Cancel any existing completer
    if (_currentOAuthCompleter != null && !_currentOAuthCompleter!.isCompleted) {
      _currentOAuthCompleter!.completeError('New OAuth flow started');
    }

    _currentOAuthCompleter = Completer<String?>();

    // Check for initial link (in case app was opened from callback)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      // Ignore errors when checking initial link
    }

    // Return the future that will complete when we get the callback
    return _currentOAuthCompleter!.future;
  }

  /// Cancel the current OAuth flow
  void cancelOAuthFlow() {
    if (_currentOAuthCompleter != null && !_currentOAuthCompleter!.isCompleted) {
      _currentOAuthCompleter!.complete(null);
    }
    _currentOAuthCompleter = null;
  }

  /// Dispose resources
  void dispose() {
    _uriSubscription?.cancel();
    _uriSubscription = null;
    cancelOAuthFlow();
  }
}


