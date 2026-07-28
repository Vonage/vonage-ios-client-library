# IPv6 Diagnostics — Tester Integration Guide

This branch (`ipv6-diagnostics`) adds **temporary trace logging** to help us diagnose why
silent auth is reporting 0% conversion on T-Mobile (requests appear to go over IPv4 when the
carrier requires IPv6).

It makes **no behavior change** — no IP-version preference is set. It only adds `IP-DIAG`
trace lines so we can see, on a real affected device, whether traffic lands on IPv4 or IPv6
and why.

> ⚠️ This is a throwaway diagnostic branch. Do **not** ship it to production — the traces
> include resolved IP addresses.

---

## 1. Prerequisites

- A **physical iOS device** with a **T-Mobile SIM** (the issue does not reproduce on the
  simulator, which has no cellular interface — the SDK skips the cellular checks there).
- **Wi-Fi turned OFF** and **Cellular Data ON** for the test app, so the request is actually
  forced over cellular.
- Xcode 15+ and the ability to run the app on the device.

---

## 2. Add the SDK from this branch

You do **not** need a published release. Pick whichever is convenient:

### Swift Package Manager — by branch (recommended while iterating)

In Xcode: **File ▸ Add Package Dependencies…**, enter the repo URL, then set
**Dependency Rule ▸ Branch ▸ `ipv6-diagnostics`**.

Or in `Package.swift`:

```swift
.package(url: "https://github.com/Vonage/vonage-ios-client-library.git", branch: "ipv6-diagnostics")
```

### Swift Package Manager — by exact commit (fully reproducible)

```swift
.package(url: "https://github.com/Vonage/vonage-ios-client-library.git", revision: "144f815")
```

### CocoaPods

```ruby
pod 'VonageClientLibrary', :git => 'https://github.com/Vonage/vonage-ios-client-library.git', :branch => 'ipv6-diagnostics'
```

> If we tag an alpha (e.g. `1.3.0-alpha.1`), you can pin it instead:
> SPM `exact: "1.3.0-alpha.1"` or CocoaPods `:tag => '1.3.0-alpha.1'`.

---

## 3. Run a request with diagnostics enabled

The trace is **runtime-gated** — there is no special build configuration. Enable it in one
of two ways (you can use both).

### Option A — `debug: true` (traces returned in the response)

```swift
import VonageClientLibrary

let client = VGCellularRequestClient()

let params = VGCellularRequestParameters(
    url: "<THE SILENT AUTH / CHECK URL YOU ARE TESTING>",
    headers: [:],
    queryParameters: [:]
)

let response = try await client.startCellularGetRequest(params: params, debug: true)

// The IP-DIAG lines are inside the url_trace string:
if let debug = response["debug"] as? [String: Any],
   let urlTrace = debug["url_trace"] as? String {
    print(urlTrace)
}
```

### Option B — attach a `VGLogger` (traces streamed live, even without `debug`)

```swift
import VonageClientLibrary

final class DiagLogger: NSObject, VGLogger {
    func log(_ message: String, level: VGLogLevel) {
        // Print only the diagnostic lines, or forward everything to your logging stack.
        if message.contains("IP-DIAG") {
            print("[\(level)] \(message)")
        }
    }
}

let client = VGCellularRequestClient()
client.logger = DiagLogger()

let response = try await client.startCellularGetRequest(params: params, debug: true)
```

---

## 4. What to capture and send back

Grab everything tagged `IP-DIAG` from the run (and ideally the full `url_trace`). You'll see
lines like:

```
IP-DIAG target host 'auth.example-operator.com' is a hostname; IP-version preference: any (default, no preference set)
IP-DIAG path supportsIPv4=true supportsIPv6=true usesCellular=true
IP-DIAG resolved remote endpoint: IPv4 100.64.12.34 :443
IP-DIAG redirect Location host 'step2.example-operator.com' is a hostname
...
```

Please include, for each test run:

1. The **full sequence** of `IP-DIAG` lines (there is one set per redirect hop).
2. The device model + iOS version (already at the top of `url_trace`).
3. Whether the silent auth **succeeded or failed** (conversion outcome).
4. Confirmation that **Wi-Fi was off / cellular on** during the run.

---

## 5. How to read the output (what we're looking for)

| Line | What it tells us |
|------|------------------|
| `target host … is a hostname` | The host was DNS-resolved, so IP-version selection applies. We can potentially influence this. |
| `target host … is a IPv4-literal` | The operator handed us a hard IPv4 address. **No SDK change can move this to IPv6** — this points to an operator/backend redirect config issue. |
| `resolved remote endpoint: IPv4 …` | The socket actually connected over **IPv4** — this is the smoking gun for the T-Mobile symptom. |
| `resolved remote endpoint: IPv6 …` | The socket connected over **IPv6** (note: a `64:ff9b::` / carrier prefix indicates a NAT64-synthesized address). |
| `path supportsIPv6=false` | The cellular path itself had no IPv6 at request time. |
| `redirect Location host … is a IPv4-literal` | A specific redirect hop forced IPv4 via a literal — again, operator-side, not SDK-addressable. |

The key question this data answers: **are we landing on IPv4 because the operator hands us
IPv4 literals (operator/backend fix), or because a hostname is resolving to IPv4 over
cellular (potentially an SDK IP-version-preference fix)?** Please run a few times on the
affected T-Mobile device so we can see whether it's consistent.
