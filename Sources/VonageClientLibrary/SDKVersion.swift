//
//  SDKVersion.swift
//
//
//  Created for VNASUP-686 - single source of truth for the SDK version.
//

/// Single source of truth for the SDK's released version.
///
/// Both SPM and CocoaPods consumers need the real version at runtime for the
/// `User-Agent` header, and `Bundle`/`Info.plist` lookups are unreliable across
/// both distribution mechanisms (SPM generates no `Info.plist`; CocoaPods
/// auto-generates one but hardcodes "1.0"). This constant sidesteps both by
/// being read directly - the podspec parses this file at `pod spec lint`/publish
/// time to keep `s.version` in sync.
///
/// - Important: Update `current` at release time. Nothing else needs to change.
enum SDKVersion {
    static let current = "1.2.0"
}
