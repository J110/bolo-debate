import 'dart:async';
import 'dart:math' as math;
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
  
  // Audio level for visualizer (0.0 - 1.0)
  double _audioLevel = 0.0;
  Timer? _audioLevelTimer;
  EventsListener<RoomEvent>? _roomListener;
  
  // Frequency bands for visualizer (simulated from audio level)
  // We'll create 20 frequency bands that respond to the audio level
  List<double> _frequencyBands = List.filled(20, 0.0);
  
  // Store speaking states per participant
  final Map<String, bool> _speakingStates = {};
  
  // For smooth frequency animation
  final math.Random _random = math.Random();
  double _lastAudioLevel = 0.0;
  int _frameCount = 0;
  
  // Callbacks
  Function(List<RemoteParticipant>)? onParticipantsChanged;
  Function(double)? onAudioLevelChanged;
  Function(List<double>)? onFrequencyDataChanged;

  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  double get audioLevel => _audioLevel;
  List<double> get frequencyBands => _frequencyBands;
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

      // Setup event listeners BEFORE connecting
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

    // Create events listener for room events
    _roomListener = _room!.createListener();
    
    // Listen for active speaker changes - this gives us real audio levels
    _roomListener!.on<ActiveSpeakersChangedEvent>((event) {
      _handleActiveSpeakers(event.speakers);
    });
    
    // Listen for track subscribed events
    _roomListener!.on<TrackSubscribedEvent>((event) {
      _onRoomUpdate();
    });
    
    // Listen for track unsubscribed events
    _roomListener!.on<TrackUnsubscribedEvent>((event) {
      _onRoomUpdate();
    });
    
    // Listen for participant connected
    _roomListener!.on<ParticipantConnectedEvent>((event) {
      _onRoomUpdate();
    });
    
    // Listen for participant disconnected
    _roomListener!.on<ParticipantDisconnectedEvent>((event) {
      _speakingStates.remove(event.participant.identity);
      _onRoomUpdate();
    });
    
    // Start polling for audio levels as backup
    _startAudioLevelPolling();
  }
  
  void _handleActiveSpeakers(List<Participant> speakers) {
    // Update speaking states
    _speakingStates.clear();
    
    double maxLevel = 0.0;
    for (final speaker in speakers) {
      _speakingStates[speaker.identity] = true;
      // Active speakers have audio level - use it
      if (speaker.audioLevel > maxLevel) {
        maxLevel = speaker.audioLevel;
      }
    }
    
    if (maxLevel != _audioLevel) {
      _audioLevel = maxLevel;
      onAudioLevelChanged?.call(_audioLevel);
      notifyListeners();
    }
  }
  
  void _startAudioLevelPolling() {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 33), (_) { // ~30fps
      if (_room == null || !_isConnected) return;
      
      double maxLevel = 0.0;
      
      // Check local participant audio level
      if (_localParticipant != null && !_isMuted) {
        final localLevel = _localParticipant!.audioLevel;
        if (localLevel > maxLevel) {
          maxLevel = localLevel;
        }
      }
      
      // Check remote participants' audio levels
      for (final participant in _room!.remoteParticipants.values) {
        final level = participant.audioLevel;
        if (level > maxLevel) {
          maxLevel = level;
        }
      }
      
      // Smooth the audio level
      _audioLevel = _audioLevel * 0.6 + maxLevel * 0.4;
      
      // Generate frequency-like bands based on audio level
      _generateFrequencyBands(maxLevel);
      
      _lastAudioLevel = maxLevel;
      _frameCount++;
      
      onAudioLevelChanged?.call(_audioLevel);
      onFrequencyDataChanged?.call(_frequencyBands);
      notifyListeners();
    });
  }
  
  // Generate simulated frequency bands that look like voice spectrum
  void _generateFrequencyBands(double level) {
    // Voice frequencies are typically concentrated in lower-mid range
    // We'll create a spectrum that responds realistically to voice
    
    final isActive = level > 0.05;
    final normalizedLevel = (level * 2.0).clamp(0.0, 1.0);
    
    for (int i = 0; i < 20; i++) {
      double targetHeight;
      
      if (isActive) {
        // Voice frequency distribution - most energy in low-mid frequencies
        // Band 0-5: Low frequencies (bass, fundamental)
        // Band 6-12: Mid frequencies (voice harmonics, most energy)
        // Band 13-19: High frequencies (consonants, sibilance)
        
        double baseEnergy;
        if (i < 5) {
          // Low frequencies - moderate energy, slow movement
          baseEnergy = 0.4 + (_random.nextDouble() * 0.3);
        } else if (i < 13) {
          // Mid frequencies - highest energy for voice
          baseEnergy = 0.6 + (_random.nextDouble() * 0.4);
        } else {
          // High frequencies - lower energy, fast movement
          baseEnergy = 0.2 + (_random.nextDouble() * 0.5);
        }
        
        // Add time-based variation for natural movement
        final timeVariation = math.sin((_frameCount * 0.15) + (i * 0.5)) * 0.15;
        final randomVariation = (_random.nextDouble() - 0.5) * 0.2;
        
        targetHeight = (baseEnergy + timeVariation + randomVariation) * normalizedLevel;
        targetHeight = targetHeight.clamp(0.05, 1.0);
      } else {
        // When silent, bars should be at minimum
        targetHeight = 0.05 + (_random.nextDouble() * 0.03);
      }
      
      // Smooth transition to target
      // Different smoothing for rise vs fall (faster rise, slower fall)
      if (targetHeight > _frequencyBands[i]) {
        // Rising - faster response
        _frequencyBands[i] = _frequencyBands[i] * 0.3 + targetHeight * 0.7;
      } else {
        // Falling - slower decay
        _frequencyBands[i] = _frequencyBands[i] * 0.7 + targetHeight * 0.3;
      }
    }
  }

  void _onRoomUpdate() {
    notifyListeners();
    onParticipantsChanged?.call(remoteParticipants);
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
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;
    _roomListener?.dispose();
    _roomListener = null;
    
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
    
    _localParticipant = null;
    _isConnected = false;
    _isMuted = true;
    _audioLevel = 0.0;
    _speakingStates.clear();
    notifyListeners();
    print('🔌 Disconnected from LiveKit');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
