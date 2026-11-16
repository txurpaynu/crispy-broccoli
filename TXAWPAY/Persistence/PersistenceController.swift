import Foundation
import SwiftData

/// Builds the SwiftData container.
///
/// The store always lives on the device. When the user turns on
/// "Sync with iCloud" (Profile → Privacy & Data), the next launch opens the
/// same store with a CloudKit private database attached. Switching requires
/// a relaunch because SwiftData can't reconfigure a live container.
enum PersistenceController {
    static let cloudKitContainerID = "iCloud.com.txawpay.app"

    static let schema = Schema([
        JournalEntry.self,
        JournalAttachment.self,
        JournalCategory.self,
        Memory.self,
        TravelTrip.self,
        TravelDestination.self,
        CreativeProject.self,
        ProjectMilestone.self,
        ProjectUpdate.self,
        LearningGoal.self,
        StudySession.self,
        Person.self,
        ImportantDate.self,
        Workout.self,
        Exercise.self,
        WellbeingLog.self,
        Routine.self,
        TaskItem.self,
        Reminder.self,
        LifeEvent.self,
        BackupRecord.self,
        UserSettings.self
    ])

    /// Result of building the container, including whether CloudKit is active.
    struct Result {
        let container: ModelContainer
        let cloudKitActive: Bool
        let warning: String?
    }

    static func makeContainer(inMemory: Bool = false) -> Result {
        let wantsCloud = UserDefaults.standard.bool(forKey: AppSettings.Keys.cloudSyncEnabled) && !inMemory
        if wantsCloud {
            do {
                let config = ModelConfiguration("TXAWPAY", schema: schema, isStoredInMemoryOnly: false,
                                                cloudKitDatabase: .private(cloudKitContainerID))
                let container = try ModelContainer(for: schema, configurations: [config])
                return Result(container: container, cloudKitActive: true, warning: nil)
            } catch {
                // Most common cause: the build has no iCloud entitlement (e.g. a
                // free Apple ID). Fall back to the local store; data is unaffected.
                let local = makeLocal(inMemory: false)
                return Result(container: local, cloudKitActive: false,
                              warning: "iCloud sync couldn't start (\(error.localizedDescription)). TXAWPAY is using on-device storage.")
            }
        }
        return Result(container: makeLocal(inMemory: inMemory), cloudKitActive: false, warning: nil)
    }

    private static func makeLocal(inMemory: Bool) -> ModelContainer {
        let config = ModelConfiguration("TXAWPAY", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A store that can't be opened is unrecoverable at this level; the
            // journal's Markdown backups remain the way to recover content.
            fatalError("Unable to open the TXAWPAY data store: \(error)")
        }
    }

    /// Creates built-in journal categories and the profile record on first launch.
    @MainActor
    static func seedEssentials(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<JournalCategory>())) ?? []
        for (index, def) in JournalCategory.builtInDefinitions.enumerated()
        where !existing.contains(where: { $0.name == def.0 }) {
            context.insert(JournalCategory(name: def.0, symbol: def.1, colorHex: def.2, isBuiltIn: true, sortOrder: index))
        }
        if ((try? context.fetchCount(FetchDescriptor<UserSettings>())) ?? 0) == 0 {
            context.insert(UserSettings())
        }
        try? context.save()
    }
}
