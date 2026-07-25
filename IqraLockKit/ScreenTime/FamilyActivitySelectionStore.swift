import Foundation

#if canImport(FamilyControls)
import FamilyControls

/// Persists `FamilyActivitySelection` into the App Group for extensions + relaunch.
public enum FamilyActivitySelectionStore {
    public static func save(_ selection: FamilyActivitySelection, to store: AppGroupStore = .shared) throws {
        let data = try JSONEncoder().encode(selection)
        store.selectedAppsData = data
        store.selectedAppsCount = selection.applicationTokens.count + selection.categoryTokens.count
    }

    public static func load(from store: AppGroupStore = .shared) -> FamilyActivitySelection? {
        guard let data = store.selectedAppsData else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
#endif
