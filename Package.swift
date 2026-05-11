// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "scalecode-metal-plugin",
    products: [
        .plugin(name: "MetalShadersPlugin", targets: ["MetalShadersPlugin"]),
    ],
    targets: [
        .plugin(
            name: "MetalShadersPlugin",
            capability: .buildTool(),
            path: "Plugins/MetalShadersPlugin"
        ),
    ]
)
