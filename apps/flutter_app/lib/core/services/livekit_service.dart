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

  Future<bool> connect(String token, String roomId, {String? url}) async {
    if (_isConnecting || _isConnected) return true;
    
    _isConnecting = true;
    _error = null;
    notifyListeners();

    // Use URL from API if provided, otherwise fall back to constant
    final livekitUrl = url ?? AppConstants.livekitUrl;

    try {
      print('🔄 Connecting to LiveKit: $livekitUrl');
      
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
        livekitUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout - LiveKit server may be unavailable');
        },
      );

      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      _isConnecting = false;
      
      print('✅ Connected to LiveKit room: $roomId');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ LiveKit connection error: $e');
      _error = 'Audio server unavailable: ${e.toString().split(':').last.trim()}';
      _isConnecting = false;
      _room = null;
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
    // Poll at 60fps for minimal lag
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
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
      
      // Minimal smoothing for near-instant response
      _audioLevel = _audioLevel * 0.3 + maxLevel * 0.7;
      
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
  // Optimized for minimal lag - near real-time response
  void _generateFrequencyBands(double level) {
    final isActive = level > 0.03;
    final normalizedLevel = (level * 2.5).clamp(0.0, 1.0);
    
    for (int i = 0; i < 20; i++) {
      double targetHeight;
      
      if (isActive) {
        // Voice frequency distribution
        // Band 0-4: Low frequencies (bass, fundamental)
        // Band 5-12: Mid frequencies (voice harmonics, most energy)
        // Band 13-19: High frequencies (consonants, sibilance)
        
        double baseEnergy;
        double variance;
        
        if (i < 5) {
          // Low frequencies - moderate energy
          baseEnergy = 0.5;
          variance = _random.nextDouble() * 0.25;
        } else if (i < 13) {
          // Mid frequencies - highest energy for voice
          baseEnergy = 0.7;
          variance = _random.nextDouble() * 0.3;
        } else {
          // High frequencies - responsive to consonants
          baseEnergy = 0.35;
          variance = _random.nextDouble() * 0.4;
        }
        
        // Minimal time variation for more direct voice response
        final timeVariation = math.sin((_frameCount * 0.3) + (i * 0.4)) * 0.08;
        
        targetHeight = (baseEnergy + variance + timeVariation) * normalizedLevel;
        targetHeight = targetHeight.clamp(0.05, 1.0);
      } else {
        // When silent, bars at minimum
        targetHeight = 0.05;
      }
      
      // Near-instant response - minimal smoothing
      if (targetHeight > _frequencyBands[i]) {
        // Rising - almost instant (95% of target)
        _frequencyBands[i] = _frequencyBands[i] * 0.05 + targetHeight * 0.95;
      } else {
        // Falling - quick decay (80% toward target)
        _frequencyBands[i] = _frequencyBands[i] * 0.2 + targetHeight * 0.8;
      }
    }
  }

  void _onRoomUpdate() {
    notifyListeners();
    onParticipantsChanged?.call(remoteParticipants);
  }

  Future<bool> enableMicrophone() async {
    if (_room == null) {
      print('❌ Cannot enable mic: room is null');
      _error = 'Not connected to room';
      notifyListeners();
      return false;
    }
    
    if (!_isConnected) {
      print('❌ Cannot enable mic: not connected');
      _error = 'Not connected to LiveKit';
      notifyListeners();
      return false;
    }

    try {
      print('🎤 Requesting microphone access...');
      
      // On web, this will trigger the browser's permission dialog
      // The LiveKit SDK handles getUserMedia internally
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      // Verify the mic was actually enabled
      final audioTracks = _room!.localParticipant?.audioTrackPublications;
      if (audioTracks == null || audioTracks.isEmpty) {
        print('⚠️ No audio track published after enabling mic');
        // Try publishing a new audio track
        await _room!.localParticipant?.publishAudioTrack(
          await LocalAudioTrack.create(const AudioCaptureOptions()),
        );
      }
      
      _isMuted = false;
      _error = null;
      print('✅ Microphone enabled successfully');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error enabling microphone: $e');
      _error = 'Microphone access denied or unavailable';
      _isMuted = true;
      notifyListeners();
      return false;
    }
  }

  Future<bool> disableMicrophone() async {
    if (!_isConnected || _room == null) return false;

    try {
      await _room!.localParticipant?.setMicrophoneEnabled(false);
      _isMuted = true;
      print('🔇 Microphone disabled');
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error disabling microphone: $e');
      return false;
    }
  }

  Future<bool> toggleMicrophone() async {
    if (_isMuted) {
      return await enableMicrophone();
    } else {
      await disableMicrophone();
      return true;
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
