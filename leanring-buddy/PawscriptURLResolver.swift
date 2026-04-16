//
//  PawscriptURLResolver.swift
//  leanring-buddy
//
//  Normalizes stale tutorial URLs and lightly preflights browser steps.
//

import Foundation

struct PawscriptURLPreflightIssue: Hashable {
    var stepNumber: Int
    var url: String
    var reason: String
}

final class PawscriptURLResolver {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func normalizedPackage(_ package: PawscriptSkillPackage) -> PawscriptSkillPackage {
        var package = package
        package.steps = package.steps.map { step in
            var step = step
            if step.action == "navigate" {
                if let value = step.value {
                    step.value = normalizeURLString(value, context: stepContext(step))
                }
                if let target = step.target {
                    step.target = normalizeURLString(target, context: stepContext(step))
                }
            }
            return step
        }
        return package
    }

    func normalizedURL(from rawURLString: String, context: String) -> URL? {
        URL(string: normalizeURLString(rawURLString, context: context))
    }

    func normalizeURLString(_ rawURLString: String, context: String) -> String {
        let trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased() else {
            return rawURLString
        }

        if host == "paper.design", url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "shaders" {
            if let effectPath = paperShaderEffectPath(from: context) {
                return "https://shaders.paper.design/\(effectPath)"
            }
            return "https://shaders.paper.design/"
        }

        if host == "shaders.paper.design", url.path.isEmpty {
            return "https://shaders.paper.design/"
        }

        return rawURLString
    }

    func preflightNavigableSteps(in package: PawscriptSkillPackage) async -> [PawscriptURLPreflightIssue] {
        var issues: [PawscriptURLPreflightIssue] = []
        let steps = package.steps.sorted { $0.number < $1.number }

        for step in steps where step.action == "navigate" {
            let rawURL = step.value ?? step.target ?? ""
            guard let url = normalizedURL(from: rawURL, context: stepContext(step)),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                continue
            }

            do {
                let statusCode = try await statusCode(for: url)
                if statusCode == 404 {
                    issues.append(PawscriptURLPreflightIssue(
                        stepNumber: step.number,
                        url: url.absoluteString,
                        reason: "Page returned 404. This looks like a stale tutorial URL, not a sign-in requirement."
                    ))
                } else if statusCode >= 400 {
                    issues.append(PawscriptURLPreflightIssue(
                        stepNumber: step.number,
                        url: url.absoluteString,
                        reason: "Page returned HTTP \(statusCode)."
                    ))
                }
            } catch {
                issues.append(PawscriptURLPreflightIssue(
                    stepNumber: step.number,
                    url: url.absoluteString,
                    reason: "Could not validate URL before automation: \(error.localizedDescription)"
                ))
            }
        }

        return issues
    }

    private func statusCode(for url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return httpResponse.statusCode
    }

    private func paperShaderEffectPath(from context: String) -> String? {
        let lowered = context.lowercased()
        let knownEffects: [(needle: String, path: String)] = [
            ("fluted glass", "fluted-glass"),
            ("halftone", "halftone"),
            ("warp", "warp"),
            ("vintage", "vintage")
        ]
        return knownEffects.first { lowered.contains($0.needle) }?.path
    }

    private func stepContext(_ step: SkillStep) -> String {
        [
            step.title,
            step.target,
            step.value,
            step.description,
            step.verification,
            step.gotchaText
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}
