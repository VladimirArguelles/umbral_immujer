import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/utils/app_logger.dart';

class OnlineUserPresenceService with WidgetsBindingObserver {
  OnlineUserPresenceService._();

  static final OnlineUserPresenceService instance =
      OnlineUserPresenceService._();

  final StreamController<int?> _onlineUserCountController =
      StreamController<int?>.broadcast();

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  Future<void> _pendingUpdate = Future<void>.value();
  String? _userId;
  int? _onlineUserCount;

  int? get onlineUserCount => _onlineUserCount;

  Stream<int?> get onlineUserCountStream => _onlineUserCountController.stream;

  Future<void> initialize(SupabaseClient client) async {
    if (_client != null) return;

    _client = client;
    WidgetsBinding.instance.addObserver(this);
    client.auth.onAuthStateChange.listen(
      (state) => unawaited(_enqueueUpdate(state.session?.user.id)),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.error(
          'No se pudo observar el estado de autenticación para presencia.',
          tag: 'USER_PRESENCE',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    await _enqueueUpdate(client.auth.currentUser?.id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_enqueueUpdate(_userId));
  }

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  Future<void> _enqueueUpdate(String? userId) {
    final update = _pendingUpdate.then((_) async {
      try {
        await _updatePresence(userId);
      } catch (error, stackTrace) {
        _publishCount(null);
        AppLogger.error(
          'No se pudo actualizar la presencia de usuarios.',
          tag: 'USER_PRESENCE',
          error: error,
          stackTrace: stackTrace,
        );
      }
    });
    _pendingUpdate = update;
    return update;
  }

  Future<void> _updatePresence(String? userId) async {
    if (_userId != userId) {
      _userId = userId;
      await _removeChannel();
      _publishCount(null);
    }

    if (userId == null || !_isForeground) {
      await _removeChannel();
      _publishCount(null);
      return;
    }

    if (_channel == null) {
      _joinChannel(userId);
    }
  }

  void _joinChannel(String userId) {
    final client = _client;
    if (client == null) return;

    final channel = client.channel(
      'umbral-online-users',
      opts: RealtimeChannelConfig(key: userId, enabled: true),
    );
    _channel = channel;

    channel
        .onPresenceSync((_) {
          if (identical(_channel, channel)) {
            _publishCount(channel.presenceState().length);
          }
        })
        .subscribe((status, error) {
          if (!identical(_channel, channel)) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(_trackUser(channel, userId));
          } else {
            _publishCount(null);
            AppLogger.error(
              'No se pudo conectar al canal de presencia.',
              tag: 'USER_PRESENCE',
              error: error ?? StateError('Estado del canal: $status'),
            );
          }
        });
  }

  Future<void> _trackUser(RealtimeChannel channel, String userId) async {
    try {
      final response = await channel.track({'user_id': userId});
      if (response != ChannelResponse.ok) {
        throw StateError('No se pudo publicar la presencia: $response');
      }
    } catch (error, stackTrace) {
      _publishCount(null);
      AppLogger.error(
        'No se pudo registrar al usuario en línea.',
        tag: 'USER_PRESENCE',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _removeChannel() async {
    final channel = _channel;
    final client = _client;
    _channel = null;
    if (channel != null && client != null) {
      await client.removeChannel(channel);
    }
  }

  void _publishCount(int? count) {
    _onlineUserCount = count;
    _onlineUserCountController.add(count);
  }
}
