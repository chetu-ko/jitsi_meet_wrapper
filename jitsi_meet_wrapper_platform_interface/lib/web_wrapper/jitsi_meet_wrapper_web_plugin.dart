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
      api?.on("videoConferenceJoined", allowInterop((dynamic message) {
        listener.onConferenceJoined?.call(message.toString());
      }));
      api?.on("videoConferenceLeft", allowInterop((dynamic message) {
        listener.onConferenceTerminated?.call(message, '');
      }));
      api?.on("feedbackSubmitted", allowInterop((dynamic message) {
        debugPrint("feedbackSubmitted message: $message");
        listener.onClosed?.call();
      }));

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
    }
    if (listener != null) {
      debugPrint("genericListeners ${listener.onAudioMutedChanged}");
      debugPrint("genericListeners ${listener.onChatMessageReceived}");
      debugPrint("genericListeners ${listener.onChatToggled}");
      debugPrint("genericListeners ${listener.onClosed}");
      debugPrint("genericListeners ${listener.onConferenceJoined}");
      debugPrint("genericListeners ${listener.onConferenceTerminated}");
      debugPrint("genericListeners ${listener.onConferenceWillJoin}");
      debugPrint("genericListeners ${listener.onOpened}");
      debugPrint("genericListeners ${listener.onParticipantJoined}");
      debugPrint("genericListeners ${listener.onParticipantLeft}");
      debugPrint("genericListeners ${listener.onParticipantsInfoRetrieved}");
      debugPrint("genericListeners ${listener.onScreenShareToggled}");
      debugPrint("genericListeners ${listener.onVideoMutedChanged}");
    }
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

  /// Removes all JitsiMeetingListeners
  /// Not used for web
  removeAllListeners() {}

  void initialize() {}

  @override
  Widget buildView(List<String> extraJS) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory('jitsi-meet-view',
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

    return HtmlElementView(viewType: 'jitsi-meet-view');
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
