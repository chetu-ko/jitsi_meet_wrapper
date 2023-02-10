import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:jitsi_meet_wrapper_platform_interface/jitsi_meet_wrapper_platform_interface.dart';
import 'package:js/js.dart';

import 'jitsi_meet_wrapper_external_api.dart' as jitsi;

/// JitsiMeetPlugin Web version for Jitsi Meet plugin
class JitsiWrapperPlugin extends JitsiMeetWrapperPlatformInterface {
  // List<JitsiMeetingListener> _listeners = <JitsiMeetingListener>[];
  // Map<String, JitsiMeetingListener> _perMeetingListeners = {};

  /// `JitsiMeetExternalAPI` holder
  jitsi.JitsiWrapperAPI? api;

  ///Check the event initialiazer
  bool _eventChannelIsInitialized = false;

  /// Flag to indicate if external JS are already added
  /// used for extra scripts
  bool extraJSAdded = false;

  /// Regex to validate URL
  RegExp cleanDomain = RegExp(r"^https?:\/\/");

  JitsiWrapperPlugin._() {
     _setupScripts();
  }

  static final JitsiWrapperPlugin _instance = JitsiWrapperPlugin._();

  /// Registry web plugin
  static void registerWith(Registrar registrar) {
    JitsiMeetWrapperPlatformInterface.instance = _instance;
  }

  /// Joins a meeting based on the JitsiMeetingOptions passed in.
  /// A JitsiMeetingListener can be attached to this meeting
  /// that will automatically be removed when the meeting has ended
  @override
  Future<JitsiMeetingResponse> joinMeeting({
    required JitsiMeetingOptions options,
    JitsiMeetingListener? listener,
  }) async {
    // encode `options` Map to Json to avoid error
    // in interoperability conversions

    String webOptions = jsonEncode(options.webOptions);
    String serverURL = options.serverUrl ?? "meet.jit.si";
    serverURL = serverURL.replaceAll(cleanDomain, "");
    api = jitsi.JitsiWrapperAPI(serverURL, webOptions);

    // setup listeners
    if (listener != null) {
      // NOTE: `onConferenceWillJoin` is not supported or nof found event in web
      // add geeric listener
      _addGenericListeners(listener);

      // force to dispose view when close meeting
      // this is needed to allow create another room in
      // the same view without reload it
      api?.on("readyToClose", allowInterop((dynamic message) {
        api?.dispose();
      }));
    }

    return JitsiMeetingResponse(isSuccess: true);
  }

  // add generic lister over current session
  _addGenericListeners(JitsiMeetingListener? listener) {
    if (api == null) {
      debugPrint("Jistsi instance not exists event can't be attached");
      return;
    } else {
      initialize(listener);
    }
  }

  ///Initializing the listener
  void initialize(JitsiMeetingListener? listener) {
    api!.on("videoConferenceJoined", allowInterop((message) {
      Map<String, dynamic> data = {
        'roomName': message.roomName,
      };
      debugPrint("genericListeners ${listener!.onConferenceJoined}");
      listener?.onConferenceJoined?.call(data["roomName"]);
    }));
    api!.on("videoConferenceLeft", allowInterop((message) {
      Map<String, dynamic> data = {
        'roomName': message.roomName,
      };
      debugPrint("genericListeners ${listener!.onConferenceTerminated}");
      listener?.onConferenceTerminated
          ?.call(data["roomName"], 'Local User left the meeting');
    }));
    api!.on("audioMuteStatusChanged", allowInterop((message) {
      Map<String, dynamic> data = {
        'isMuted': message.isMuted,
      };
      debugPrint("genericListeners ${listener!.onAudioMutedChanged}");
      listener?.onAudioMutedChanged
          ?.call(parseBool(data["isMuted"].toString()));
    }));
    api!.on("videoMuteStatusChanged", allowInterop((message) {
      Map<String, dynamic> data = {
        'muted': message.muted,
      };
      debugPrint("genericListeners ${listener!.onVideoMutedChanged}");
      listener?.onVideoMutedChanged?.call(parseBool(data["muted"]));
    }));
    api!.on("screenSharingStatusChanged", allowInterop((message) {
      Map<String, dynamic> data = {
        'on': message.on,
      };
      debugPrint("genericListeners ${listener!.onScreenShareToggled}");
      listener?.onScreenShareToggled?.call(
          parseBool(data["on"]) == true ? 'Joined' : 'Not Joined', parseBool(data["on"]));
    }));
    api!.on("participantJoined", allowInterop((message) {
      Map<String, dynamic> data = {
        'id': message.id,
        'displayName': message.displayName,
      };
      debugPrint("genericListeners ${listener!.onParticipantJoined}");
      listener?.onParticipantJoined?.call(
        'No Email',
        data["displayName"],
        'Meeting Joined',
        data["id"],
      );
    }));
    api!.on("participantLeft", allowInterop((message) {
      Map<String, dynamic> data = {
        'id': message.id,
      };
      debugPrint("genericListeners ${listener!.onParticipantLeft}");
      listener?.onParticipantLeft?.call(data["id"]);
    }));
    api!.on("participantsInfoRetrieved", allowInterop((message) {
      Map<String, dynamic> data = {
        'participantsInfo': message.participantsInfo,
        'requestId': message.requestId,
      };
      debugPrint("genericListeners ${listener!.onParticipantsInfoRetrieved}");
      listener?.onParticipantsInfoRetrieved?.call(
        data["participantsInfo"],
        data["requestId"],
      );
    }));
    api!.on("incomingMessage", allowInterop((message) {
      Map<String, dynamic> data = {
        'from': message.from,
        'message': message.message,
        'privateMessage': message.privateMessage,
      };
      debugPrint("genericListeners ${listener!.onChatMessageReceived}");
      listener?.onChatMessageReceived?.call(
        data["from"],
        data["message"],
        data["privateMessage"],
      );
    }));
    api!.on("chatUpdated", allowInterop((message) {
      Map<String, dynamic> data = {
        'isOpen': message.isOpen,
      };
      debugPrint("genericListeners ${listener!.onChatToggled}");
      listener?.onChatToggled?.call(parseBool(data["isOpen"]));
    }));

    api!.on("readyToClose", allowInterop((message) {
      debugPrint("genericListeners ${listener!.onClosed}");
      listener?.onClosed?.call();
      listener = null;
    }));
    _eventChannelIsInitialized = true;
  }

  // Required because Android SDK returns boolean values as Strings
// and iOS SDK returns boolean values as Booleans.
// (Making this an extension does not work, because of dynamic.)
  bool parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value == 'true';
    // Check whether value is not 0, because true values can be any value
    // above 0 when coming from Jitsi.
    if (value is num) return value != 0;
    throw ArgumentError('Unsupported type: $value');
  }

  @override
  void executeCommand(String command, List<String> args) {
    api?.executeCommand(command, args);
  }

  closeMeeting() {
    debugPrint("Closing the meeting");
    api?.dispose();
    api = null;
  }

  /// Adds a JitsiMeetingListener that will broadcast conference events
  addListener(JitsiMeetingListener jitsiMeetingListener) {
    debugPrint("Adding listeners");
    _addGenericListeners(jitsiMeetingListener);
  }

  /// Remove JitsiListener
  /// Remove all list of listeners bassed on event name
  removeListener(JitsiMeetingListener jitsiMeetingListener) {
    debugPrint("Removing listeners");
    List<String> listeners = [];
    if (jitsiMeetingListener.onConferenceJoined != null) {
      listeners.add("videoConferenceJoined");
    } else if (jitsiMeetingListener.onConferenceTerminated != null) {
      listeners.add("videoConferenceLeft");
    }

    api?.removeEventListener(listeners);
  }

  @override
  Widget buildView(List<String> extraJS) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('jitsi-meet-wrapper-view',
        (int viewId) {
      final div = html.DivElement()
        ..id = "jitsi-meet-section"
        ..style.width = '100%'
        ..style.height = '100%';
      return div;
    });
    // add extraJS only once
    // this validation is needed because the view can be
    // rebuileded several times
    if (!extraJSAdded) {
      _setupExtraScripts(extraJS);
      extraJSAdded = true;
    }

    return HtmlElementView(viewType: 'jitsi-meet-wrapper-view');
  }

  // setu extra JS Scripts
  void _setupExtraScripts(List<String> extraJS) {
    extraJS.forEach((element) {
      RegExp regExp = RegExp(r"<script[^>]*>(.*?)<\/script[^>]*>");
      if (regExp.hasMatch(element)) {
        final html.NodeValidatorBuilder validator =
            html.NodeValidatorBuilder.common()
              ..allowElement('script',
                  attributes: ['type', 'crossorigin', 'integrity', 'src']);
        debugPrint("ADD script $element");
        html.Element script = html.Element.html(element, validator: validator);
        html.querySelector('head')?.children.add(script);
        // html.querySelector('head').appendHtml(element, validator: validator);
      } else {
        debugPrint("$element is not a valid script");
      }
    });
  }

  // Setup the `JitsiMeetExternalAPI` JS script
  void _setupScripts() {
    final html.ScriptElement script = html.ScriptElement()
      ..appendText(_clientJs());
    html.querySelector('head')?.children.add(script);
  }

  // Script to allow Jitsi interaction
  // To allow Flutter interact with `JitsiMeetExternalAPI`
  // extends and override the constructor is needed
  String _clientJs() => """
 class JitsiMeetAPI extends JitsiMeetExternalAPI {
    constructor(domain , options) {
      console.log(options);
      var _options = JSON.parse(options);
      if (!_options.hasOwnProperty("width")) {
        _options.width='100%';
      }
      if (!_options.hasOwnProperty("height")) {
        _options.height='100%';
      }
      // override parent to atach to view
      //_options.parentNode=document.getElementsByTagName('flt-platform-vw')[0].shadowRoot.getElementById('jitsi-meet-section');
      console.log(_options);
      _options.parentNode=document.querySelector("#jitsi-meet-section");
      super(domain, _options);
    }
}
var jitsi = { JitsiMeetAPI: JitsiMeetAPI };""";
}
