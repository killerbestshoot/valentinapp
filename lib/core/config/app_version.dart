import 'package:flutter/foundation.dart';

/// Vèsyon app la. DWE menm ak `version:` nan pubspec.yaml (yon tès verifye l).
///
/// Chak apèl voye [appBuild] bay sèvè a (`X-App-Build`): anba vèsyon minimòm
/// lan, sèvè a reponn 426 epi app la montre ekran "Mete ajou" a.
const appVersion = '1.3.1';
const appBuild = 9;

String get appPlatform => kIsWeb ? 'web' : defaultTargetPlatform.name;
