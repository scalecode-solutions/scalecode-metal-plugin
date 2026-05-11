# scalecode-metal-plugin

Swift Package Manager build-tool plugin that compiles a target's `.metal`
shader sources into a `default.metallib` resource, ready for
`ShaderLibrary.bundle(.module)` at runtime.

> One plugin so every game in the stack stops re-inventing the same
> 80 lines.

## What it does

Per consuming target:

1. Scans `Sources/<Target>/Shaders/*.metal`
2. Compiles each one to `.air` via `/usr/bin/xcrun metal -c`
3. Links them into `default.metallib` via `/usr/bin/xcrun metallib`
4. The library lands in the target's resource bundle so
   `ShaderLibrary.bundle(.module)` resolves it at runtime

If the `Shaders/` directory is missing or empty, the plugin emits no
build commands and the build succeeds normally — no `.metallib` produced.

## Why a shell-out

The Metal compiler ships at a cryptex-mounted path that changes between
OS updates. `context.tool(named: "metal")` can't find it on current
macOS, so the plugin invokes `/usr/bin/xcrun metal` and
`/usr/bin/xcrun metallib` directly. `xcrun` is stable, the cryptex path
is not.

## Requirements

- Swift tools version 5.9+ (uses `Target.directoryURL` /
  `PluginContext.pluginWorkDirectoryURL`)
- macOS host with Xcode command-line tools installed (any recent Xcode)

The plugin itself is host-side only — your consuming target can ship to
any Apple platform that supports Metal at runtime.

## Install

In your consuming package's `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyGame",
    platforms: [.iOS(.v17), .macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/scalecode-solutions/scalecode-metal-plugin.git",
            from: "1.0.0"
        ),
    ],
    targets: [
        .target(
            name: "MyGameUI",
            dependencies: ["MyGameKit"],
            path: "Sources/MyGameUI",
            // Stop SPM from also treating the .metal files as raw
            // resources — the plugin owns them.
            exclude: ["Shaders"],
            plugins: [
                .plugin(name: "MetalShadersPlugin", package: "scalecode-metal-plugin"),
            ]
        ),
    ]
)
```

Drop your `.metal` files into `Sources/MyGameUI/Shaders/` and reference
them from SwiftUI like any other shader:

```swift
Rectangle()
    .colorEffect(
        ShaderLibrary.bundle(.module).myShader(.float2(width, height))
    )
```

## Convention, not configuration

The plugin is intentionally zero-config:

- **Input dir:** `Shaders/` under the consuming target
- **Output:** a single `default.metallib`

If you need a different layout, you don't need this plugin — write your
own build command. Keeping the surface tiny is the point.

## Used by

- [BallSort](https://github.com/scalecode-solutions/BallSort) — Ball
  Sort Puzzle as a Swift Package for iOS 26

## License

[MIT](LICENSE). Use it freely.
