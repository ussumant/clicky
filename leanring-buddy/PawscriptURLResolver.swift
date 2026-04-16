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
        for candidate in urlCandidates(from: rawURLString) {
            let normalized = normalizeURLString(candidate, context: context)
            if let url = URL(string: normalized),
               ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                return url
            }
        }

        return nil
    }

    func normalizedNavigateURL(for step: SkillStep) -> URL? {
        let candidates = [step.target, step.value].compactMap { $0 }
        for candidate in candidates {
            if let url = normalizedURL(from: candidate, context: stepContext(step)) {
                return url
            }
        }

        return nil
    }

    func normalizeURLString(_ rawURLString: String, context: String) -> String {
        let trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased() else {
            return rawURLString
        }

        if host == "paper.design", url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "shaders" {
            return "https://paper.design/"
        }

        if host == "shaders.paper.design", url.path.isEmpty {
            return "https://paper.design/"
        }

        return rawURLString
    }

    func preflightNavigableSteps(in package: PawscriptSkillPackage) async -> [PawscriptURLPreflightIssue] {
        var issues: [PawscriptURLPreflightIssue] = []
        let steps = package.steps.sorted { $0.number < $1.number }

        for step in steps where step.action == "navigate" {
            guard let url = normalizedNavigateURL(for: step) else {
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

    private func urlCandidates(from rawURLString: String) -> [String] {
        let trimmed = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidates: [String] = trimmed.isEmpty ? [] : [trimmed]

        let pattern = #"https?://[^\s)"'<>,]+"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let matches = regex.matches(in: trimmed, range: range)
            for match in matches {
                guard let matchRange = Range(match.range, in: trimmed) else { continue }
                let urlString = String(trimmed[matchRange])
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
                candidates.append(urlString)
            }
        }

        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
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
