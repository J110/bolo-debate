import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../constants/app_constants.dart';

class LiveKitService extends ChangeNotifier {
  Room? _room;
  LocalParticipant? _localParticipant;
  bool _isConnected = false;
  bool _isMuted = true;
  bool _isConnecting = false;
  String? _error;
  
  // Audio level for visualizer
  double _audioLevel = 0.0;
  StreamSubscription? _audioLevelSubscription;
  
  // Callbacks
  Function(List<RemoteParticipant>)? onParticipantsChanged;
  Function(double)? onAudioLevelChanged;

  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  double get audioLevel => _audioLevel;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;
  
  List<RemoteParticipant> get remoteParticipants => 
      _room?.remoteParticipants.values.toList() ?? [];

  Future<bool> connect(String token, String roomId) async {
    if (_isConnecting || _isConnected) return true;
    
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true,
          ),
        ),
      );

      // Setup event listeners
      _setupRoomListeners();

      // Connect to LiveKit
      await _room!.connect(
        AppConstants.livekitUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
        ),
      );

      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      _isConnecting = false;
      
      print('✅ Connected to LiveKit room: $roomId');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ LiveKit connection error: $e');
      _error = e.toString();
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  void _setupRoomListeners() {
    if (_room == null) return;

    _room!.addListener(_onRoomUpdate);
    
    // Listen for audio level changes
    _startAudioLevelMonitoring();
  }

  void _onRoomUpdate() {
    notifyListeners();
    onParticipantsChanged?.call(remoteParticipants);
  }

  void _startAudioLevelMonitoring() {
    // Monitor audio levels every 100ms
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = Stream.periodic(const Duration(milliseconds: 100))
        .listen((_) {
      if (_room == null || !_isConnected) return;
      
      // Get combined audio level from all participants
      double maxLevel = 0.0;
      
      // Check local participant audio
      if (_localParticipant != null && !_isMuted) {
        for (final track in _localParticipant!.audioTrackPublications) {
          if (track.track != null && !track.muted) {
            // Local audio is active
            maxLevel = 0.5; // Placeholder - actual level from audio track
          }
        }
      }
      
      // Check remote participants' audio levels
      for (final participant in _room!.remoteParticipants.values) {
        for (final track in participant.audioTrackPublications) {
          if (track.track != null && !track.muted) {
            // Remote audio is active
            maxLevel = 0.7; // Placeholder - actual level from audio track
          }
        }
      }
      
      if (_audioLevel != maxLevel) {
        _audioLevel = maxLevel;
        onAudioLevelChanged?.call(_audioLevel);
        notifyListeners();
      }
    });
  }

  Future<void> enableMicrophone() async {
    if (!_isConnected || _room == null) return;

    try {
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      _isMuted = false;
      print('🎤 Microphone enabled');
      notifyListeners();
    } catch (e) {
      print('❌ Error enabling microphone: $e');
      _error = 'Failed to enable microphone: $e';
      notifyListeners();
    }
  }

  Future<void> disableMicrophone() async {
    if (!_isConnected || _room == null) return;

    try {
      await _room!.localParticipant?.setMicrophoneEnabled(false);
      _isMuted = true;
      print('🔇 Microphone disabled');
      notifyListeners();
    } catch (e) {
      print('❌ Error disabling microphone: $e');
    }
  }

  Future<void> toggleMicrophone() async {
    if (_isMuted) {
      await enableMicrophone();
    } else {
      await disableMicrophone();
    }
  }

  Future<void> disconnect() async {
    _audioLevelSubscription?.cancel();
    _audioLevelSubscription = null;
    
    if (_room != null) {
      _room!.removeListener(_onRoomUpdate);
      await _room!.disconnect();
      _room = null;
    }
    
    _localParticipant = null;
    _isConnected = false;
    _isMuted = true;
    _audioLevel = 0.0;
    notifyListeners();
    print('🔌 Disconnected from LiveKit');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
