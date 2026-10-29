import Foundation
import SwiftData

/// One-way sync: every `.txt` file in the repo's `recipes/` folder becomes a recipe on the phone.
/// Recipes added on the phone are never touched. The repo is public, so no token is needed.
enum GitHubSync {
    static let owner = "mrrcactus"
    static let repo = "chefsecrets"
    static let branch = "main"
    static let folder = "recipes"

    struct Result {
        var added = 0
        var updated = 0
        var removed = 0

        var summary: String {
            if added + updated + removed == 0 { return "Already up to date." }
            return [
                added > 0 ? "\(added) added" : nil,
                updated > 0 ? "\(updated) updated" : nil,
                removed > 0 ? "\(removed) removed" : nil,
            ].compactMap { $0 }.joined(separator: ", ")
        }
    }

    enum SyncError: LocalizedError {
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .badResponse(403): "GitHub says slow down (60 syncs an hour max). Try again later."
            case .badResponse(let code): "GitHub returned error \(code)."
            }
        }
    }

    private struct RemoteFile: Decodable {
        let name: String
        let path: String
        let sha: String
        let type: String
    }

    @MainActor
    static func run(context: ModelContext) async throws -> Result {
        let listURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(folder)?ref=\(branch)")!
        let files = try JSONDecoder().decode([RemoteFile].self, from: try await fetch(listURL))
            .filter { $0.type == "file" && $0.name.lowercased().hasSuffix(".txt") }

        let all = try context.fetch(FetchDescriptor<Recipe>())
        var synced: [String: Recipe] = [:]
        for recipe in all {
            if let path = recipe.githubPath { synced[path] = recipe }
        }

        var result = Result()
        for file in files {
            let existing = synced[file.path]
            if existing?.githubSHA == file.sha { continue }

            // The blob endpoint is addressed by content hash, so it's never stale like raw file links can be.
            let blobURL = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/git/blobs/\(file.sha)")!
            let text = String(decoding: try await fetch(blobURL, raw: true), as: UTF8.self)
            var draft = RecipeParser.parse(text)
            guard !draft.title.isEmpty else { continue }
            // Keep the photo you added on the phone.
            if let existing { draft.photo = existing.photo }

            let recipe = RecipeStore.save(draft, into: existing, context: context)
            recipe.githubPath = file.path
            recipe.githubSHA = file.sha
            if existing == nil { result.added += 1 } else { result.updated += 1 }
        }

        // A file deleted from GitHub removes its recipe from the phone.
        let remotePaths = Set(files.map(\.path))
        for (path, recipe) in synced where !remotePaths.contains(path) {
            RecipeStore.delete(recipe, context: context)
            result.removed += 1
        }

        try context.save()
        return result
    }

    private static func fetch(_ url: URL, raw: Bool = false) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue(raw ? "application/vnd.github.raw+json" : "application/vnd.github+json",
                         forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw SyncError.badResponse(status) }
        return data
    }
}
