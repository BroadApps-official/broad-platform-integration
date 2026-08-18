#!/usr/bin/env swift

import AVFoundation
import ImageIO
import UniformTypeIdentifiers

private struct Arguments {
    let inputURL: URL
    let outputURL: URL
    let start: Double
    let duration: Double?
    let width: CGFloat
    let framesPerSecond: Double

    init() throws {
        let values = CommandLine.arguments
        guard values.count >= 3 else {
            throw ExportError.invalidArguments
        }

        inputURL = URL(fileURLWithPath: values[1])
        outputURL = URL(fileURLWithPath: values[2])
        start = values.count > 3 ? Double(values[3]) ?? 0 : 0
        duration = values.count > 4 ? Double(values[4]) : nil
        width = values.count > 5 ? CGFloat(Double(values[5]) ?? 320) : 320
        framesPerSecond = values.count > 6 ? Double(values[6]) ?? 5 : 5

        guard start >= 0, width > 0, framesPerSecond > 0 else {
            throw ExportError.invalidArguments
        }
    }
}

private enum ExportError: Error, CustomStringConvertible {
    case invalidArguments
    case invalidVideoDuration
    case cannotCreateDestination
    case cannotFinalize

    var description: String {
        switch self {
        case .invalidArguments:
            return "Usage: export_video_gif.swift <input> <output> [start] [duration] [width] [fps]"
        case .invalidVideoDuration:
            return "The selected video range is empty."
        case .cannotCreateDestination:
            return "Cannot create the GIF destination."
        case .cannotFinalize:
            return "Cannot finalize the GIF file."
        }
    }
}

private func exportGIF(using arguments: Arguments) throws {
    let asset = AVURLAsset(url: arguments.inputURL)
    let videoDuration = CMTimeGetSeconds(asset.duration)
    let availableDuration = videoDuration - arguments.start
    let selectedDuration = min(arguments.duration ?? availableDuration, availableDuration)
    guard selectedDuration > 0, selectedDuration.isFinite else {
        throw ExportError.invalidVideoDuration
    }

    let frameCount = max(1, Int((selectedDuration * arguments.framesPerSecond).rounded(.down)))
    guard let destination = CGImageDestinationCreateWithURL(
        arguments.outputURL as CFURL,
        UTType.gif.identifier as CFString,
        frameCount,
        nil
    ) else {
        throw ExportError.cannotCreateDestination
    }

    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.maximumSize = CGSize(width: arguments.width, height: arguments.width * 3)
    imageGenerator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 30)
    imageGenerator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 30)

    CGImageDestinationSetProperties(
        destination,
        [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary
    )

    let frameProperties = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: 1 / arguments.framesPerSecond,
            kCGImagePropertyGIFUnclampedDelayTime: 1 / arguments.framesPerSecond
        ]
    ] as CFDictionary

    for frameIndex in 0..<frameCount {
        autoreleasepool {
            let offset = Double(frameIndex) / arguments.framesPerSecond
            let seconds = min(
                arguments.start + offset,
                arguments.start + selectedDuration - 0.001
            )
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            if let image = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
                CGImageDestinationAddImage(destination, image, frameProperties)
            }
        }
    }

    guard CGImageDestinationFinalize(destination) else {
        throw ExportError.cannotFinalize
    }
}

do {
    try exportGIF(using: Arguments())
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(EXIT_FAILURE)
}
