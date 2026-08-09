import Foundation
import ImageIO

let paths = CommandLine.arguments.dropFirst()
guard !paths.isEmpty else {
    FileHandle.standardError.write(Data("No GIF paths supplied.\n".utf8))
    exit(1)
}

var hasFailure = false
for path in paths {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        FileHandle.standardError.write(Data("Unreadable GIF: \(path)\n".utf8))
        hasFailure = true
        continue
    }

    let frameCount = CGImageSourceGetCount(source)
    guard frameCount > 1 else {
        FileHandle.standardError.write(
            Data("README GIF must be animated: \(path) (\(frameCount) frame)\n".utf8)
        )
        hasFailure = true
        continue
    }
}

if hasFailure {
    exit(1)
}
