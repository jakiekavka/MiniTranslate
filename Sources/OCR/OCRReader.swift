import Cocoa
import Vision

enum OCRError: Error {
    case invalidImage
    case recognitionFailed(Error)
}

private struct TextObservation {
    let text: String
    let confidence: Float
    let boundingBox: CGRect

    /// Jaccard-like overlap ratio with another observation
    func overlapRatio(with other: TextObservation) -> CGFloat {
        let intersection = boundingBox.intersection(other.boundingBox)
        guard !intersection.isNull else { return 0 }
        let union = boundingBox.union(other.boundingBox)
        guard union.width * union.height > 0 else { return 0 }
        return (intersection.width * intersection.height) / (union.width * union.height)
    }
}

final class OCRReader {
    func recognize(image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.invalidImage
        }

        // Run CJK and Latin recognition concurrently.
        // A single VNRecognizeTextRequest with mixed language families causes the
        // Latin model to dominate — Chinese/Korean text gets recognized as gibberish.
        // Splitting into two requests and merging by confidence fixes this.
        async let cjkObservations = recognizeText(in: cgImage, languages: ["zh-Hans", "zh-Hant", "ko", "ja"])
        async let latinObservations = recognizeText(in: cgImage, languages: ["en", "fr", "de", "es", "pt", "ru"])

        let (cjk, latin) = await (cjkObservations, latinObservations)

        // Merge: for overlapping boxes, keep the higher-confidence reading
        let merged = mergeByConfidence(all: cjk + latin)
        let sorted = sortByPosition(merged)
        let text = sorted.map(\.text).joined(separator: "\n")
        return text
    }

    // MARK: - Private

    private func recognizeText(in cgImage: CGImage, languages: [String]) async -> [TextObservation] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.revision = VNRecognizeTextRequestRevision3
                request.recognitionLanguages = languages
                request.usesLanguageCorrection = true
                request.minimumTextHeight = 0.0

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    guard let results = request.results else {
                        continuation.resume(returning: [])
                        return
                    }
                    let observations: [TextObservation] = results.compactMap { obs in
                        guard let candidate = obs.topCandidates(1).first, candidate.confidence > 0.2 else {
                            return nil
                        }
                        return TextObservation(
                            text: candidate.string,
                            confidence: candidate.confidence,
                            boundingBox: obs.boundingBox
                        )
                    }
                    continuation.resume(returning: observations)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Merge two lists of observations: when bounding boxes overlap,
    /// keep only the one with higher confidence.
    private func mergeByConfidence(all observations: [TextObservation]) -> [TextObservation] {
        guard !observations.isEmpty else { return [] }

        // Sort by confidence descending — higher confidence wins ties
        let sorted = observations.sorted { $0.confidence > $1.confidence }
        var kept: [TextObservation] = []

        for obs in sorted {
            // Check if this observation significantly overlaps any already-kept one
            let isDuplicate = kept.contains { keptObs in
                obs.overlapRatio(with: keptObs) > 0.5
            }
            if !isDuplicate {
                kept.append(obs)
            }
        }

        return kept
    }

    /// Sort observations top-to-bottom, left-to-right (natural reading order).
    private func sortByPosition(_ observations: [TextObservation]) -> [TextObservation] {
        // Group into lines: observations whose vertical centers are close
        let lineTolerance: CGFloat = 0.02
        var lines: [[TextObservation]] = []

        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        for obs in sorted {
            let midY = obs.boundingBox.midY
            if let idx = lines.firstIndex(where: { line in
                guard let first = line.first else { return false }
                return abs(first.boundingBox.midY - midY) < lineTolerance
            }) {
                lines[idx].append(obs)
            } else {
                lines.append([obs])
            }
        }

        // Sort each line left-to-right
        for i in 0..<lines.count {
            lines[i].sort { $0.boundingBox.minX < $1.boundingBox.minX }
        }

        return lines.flatMap { $0 }
    }
}
