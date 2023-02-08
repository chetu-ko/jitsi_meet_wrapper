import 'package:flutter/material.dart';
import 'package:jitsi_meet_wrapper_platform_interface/jitsi_meeting_listener.dart';
import 'package:jitsi_meet_wrapper_platform_interface/method_channel_jitsi_meet_wrapper.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'jitsi_meeting_options.dart';
import 'jitsi_meeting_response.dart';

export 'feature_flag.dart';
export 'jitsi_meeting_options.dart';
export 'jitsi_meeting_response.dart';
export 'jitsi_meeting_listener.dart';

abstract class JitsiMeetWrapperPlatformInterface extends PlatformInterface {
  JitsiMeetWrapperPlatformInterface() : super(token: _token);

  static final Object _token = Object();

  static JitsiMeetWrapperPlatformInterface _instance = MethodChannelJitsiMeetWrapper();

  /// The default instance of [JitsiMeetWrapperPlatformInterface] to use.
  ///
  /// Defaults to [MethodChannelJitsiMeetWrapper].
  static JitsiMeetWrapperPlatformInterface get instance => _instance;

  static set instance(JitsiMeetWrapperPlatformInterface instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Joins a meeting based on the [JitsiMeetingOptions] passed in.
  Future<JitsiMeetingResponse> joinMeeting({
    required JitsiMeetingOptions options,
    JitsiMeetingListener? listener,
  }) async {
    throw UnimplementedError('joinMeeting has not been implemented.');
  }

  Future<JitsiMeetingResponse> setAudioMuted(bool isMuted) async {
    throw UnimplementedError('setAudioMuted has not been implemented.');
  }

  Future<JitsiMeetingResponse> hangUp() async {
    throw UnimplementedError('hangUp has not been implemented.');
  }

   /// execute command interface, use only in web
  void executeCommand(String command, List<String> args) {
    throw UnimplementedError('executeCommand has not been implemented.');
  }

  /// buildView
  /// Method added to support Web plugin, the main purpose is return a <div>
  /// to contain the conferencing screen when start
  /// additionally extra JS can be added usin `extraJS` argument
  /// for mobile is not need because the conferecing view get all device screen
  Widget buildView(List<String> extraJS) {
    throw UnimplementedError('_buildView has not been implemented.');
  }
}
