import Foundation
import PackagePlugin

/// SPM build-tool plugin that compiles every `.metal` source in a target's
/// `Shaders/` directory into a single `default.metallib` resource.
///
/// ## Convention
///
/// - Inputs: `Sources/<Target>/Shaders/*.metal`
/// - Output: `default.metallib` in the consuming target's resource bundle,
///   resolvable at runtime via `ShaderLibrary.bundle(.module)`.
///
/// If the `Shaders/` directory is missing or empty, the plugin emits no
/// commands — the build succeeds with no `.metallib` produced.
///
/// ## Toolchain
///
/// The Metal compiler lives at a cryptex-mounted path that changes between
/// OS updates, so the plugin shells out via `/usr/bin/xcrun metal` and
/// `/usr/bin/xcrun metallib` rather than resolving the tools through
/// `context.tool(named:)` (which can't find them on current macOS).
///
/// ## Usage
///
/// In your consuming package's `Package.swift`:
/// ```swift
/// dependencies: [
///     .package(url: "https://github.com/scalecode-solutions/scalecode-metal-plugin.git", from: "1.0.0"),
/// ],
/// targets: [
///     .target(
///         name: "MyGameUI",
///         dependencies: ["MyGameKit"],
///         path: "Sources/MyGameUI",
///         exclude: ["Shaders"],
///         plugins: [
///             .plugin(name: "MetalShadersPlugin", package: "scalecode-metal-plugin"),
///         ]
///     ),
/// ]
/// ```
///
/// Then drop your `.metal` files into `Sources/MyGameUI/Shaders/` and use
/// `ShaderLibrary.bundle(.module).myShader(...)` from SwiftUI at runtime.
@main
struct MetalShadersPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        let shadersDir = target.directoryURL.appending(path: "Shaders")
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: shadersDir.path(percentEncoded: false), isDirectory: &isDir),
              isDir.boolValue else {
            return []
        }

        guard let entries = try? fm.contentsOfDirectory(atPath: shadersDir.path(percentEncoded: false)) else {
            return []
        }
        let metalFiles = entries
            .filter { $0.hasSuffix(".metal") }
            .sorted()
            .map { shadersDir.appending(path: $0) }
        guard !metalFiles.isEmpty else { return [] }

        let xcrun = URL(fileURLWithPath: "/usr/bin/xcrun")
        let workDir = context.pluginWorkDirectoryURL

        var commands: [Command] = []
        var airFiles: [URL] = []

        for metalFile in metalFiles {
            let stem = metalFile.deletingPathExtension().lastPathComponent
            let airFile = workDir.appending(path: "\(stem).air")
            airFiles.append(airFile)

            commands.append(
                .buildCommand(
                    displayName: "Compile Metal shader \(metalFile.lastPathComponent)",
                    executable: xcrun,
                    arguments: [
                        "metal",
                        "-c",
                        metalFile.path(percentEncoded: false),
                        "-o",
                        airFile.path(percentEncoded: false),
                    ],
                    inputFiles: [metalFile],
                    outputFiles: [airFile]
                )
            )
        }

        let libFile = workDir.appending(path: "default.metallib")
        commands.append(
            .buildCommand(
                displayName: "Link Metal shaders → default.metallib",
                executable: xcrun,
                arguments: ["metallib", "-o", libFile.path(percentEncoded: false)]
                    + airFiles.map { $0.path(percentEncoded: false) },
                inputFiles: airFiles,
                outputFiles: [libFile]
            )
        )

        return commands
    }
}
