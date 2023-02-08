import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jitsi_meet_wrapper_platform_interface/jitsi_meet_wrapper_platform_interface.dart';

export 'package:jitsi_meet_wrapper_platform_interface/jitsi_meet_wrapper_platform_interface.dart'
    show
        JitsiMeetingOptions,
        JitsiMeetingResponse,
        FeatureFlag,
        JitsiMeetingListener;

class JitsiMeetWrapper {
  /// Joins a meeting based on the JitsiMeetingOptions passed in.
  /// A JitsiMeetingListener can be attached to this meeting that will automatically
  /// be removed when the meeting has ended
  static Future<JitsiMeetingResponse> joinMeeting({
    required JitsiMeetingOptions options,
    JitsiMeetingListener? listener,
  }) async {
    assert(options.roomNameOrUrl.trim().isNotEmpty, "room is empty");

    if (options.serverUrl?.isNotEmpty ?? false) {
      assert(Uri.parse(options.serverUrl!).isAbsolute,
          "URL must be of the format <scheme>://<host>[/path], like https://someHost.com");
    }

    return await JitsiMeetWrapperPlatformInterface.instance
        .joinMeeting(options: options, listener: listener);
  }

  static Future<JitsiMeetingResponse> setAudioMuted(bool isMuted) async {
    return await JitsiMeetWrapperPlatformInterface.instance
        .setAudioMuted(isMuted);
  }

  static Future<JitsiMeetingResponse> hangUp() async {
    return await JitsiMeetWrapperPlatformInterface.instance.hangUp();
  }
}

/// Allow create a interface for web view and attach it as a child
/// optional param `extraJS` allows setup another external JS libraries
/// or Javascript embebed code
class JitsiMeetConferencing extends StatelessWidget {
  final List<String>? extraJS;
  JitsiMeetConferencing({this.extraJS});

  @override
  Widget build(BuildContext context) {
    return JitsiMeetWrapperPlatformInterface.instance.buildView(extraJS!);
  }
}
