import Foundation
import SwiftData

/// Clearly labelled sample content for exploring the app.
///
/// Every demo object has `isDemo = true` and a "DEMO" marker in its title, is
/// excluded from journal backups and exports, and is removed in one step.
/// Nothing here is ever inserted automatically.
@MainActor
enum DemoData {
    static func insert(into context: ModelContext) {
        let cal = Calendar.current
        func day(_ offset: Int, hour: Int = 10) -> Date {
            let d = cal.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d) ?? d
        }
        let categories = (try? context.fetch(FetchDescriptor<JournalCategory>())) ?? []
        func cat(_ name: String) -> JournalCategory? { categories.first { $0.name == name } }

        let e1 = JournalEntry(title: "DEMO · Morning by the water", body: "The tide was low and the light came in sideways across the rocks.\n\nThis is **sample text** to show how entries look.", date: day(0, hour: 8))
        e1.mood = .calm; e1.tags = ["demo", "sea"]; e1.category = cat("Personal Diary"); e1.isDemo = true
        let e2 = JournalEntry(title: "DEMO · Three good things", body: "1. Warm bread\n2. A long call with a friend\n3. Finishing a sketch", date: day(-1, hour: 21))
        e2.mood = .grateful; e2.tags = ["demo", "gratitude"]; e2.category = cat("Gratitude Journal"); e2.isDemo = true
        let e3 = JournalEntry(title: "DEMO · A year ago", body: "Sample entry dated one year ago to show On This Day.", date: cal.date(byAdding: .year, value: -1, to: Date()) ?? Date())
        e3.mood = .inspired; e3.tags = ["demo"]; e3.isImportant = true; e3.isDemo = true
        for e in [e1, e2, e3] { context.insert(e) }

        let trip = TravelTrip(title: "DEMO · Coastal week", destination: "Sample coast", startDate: day(40), endDate: day(47), status: .planned)
        trip.itinerary = "Day 1: arrive\nDay 2: cliffs and waterfalls\nDay 3: market"
        trip.isDemo = true
        context.insert(trip)
        let place = TravelDestination(name: "DEMO · Lighthouse", kind: .place, status: .wishlist)
        place.latitude = 38.69; place.longitude = -9.42; place.isDemo = true
        context.insert(place); place.trip = trip

        let project = CreativeProject(name: "DEMO · Tide-world sketchbook", summary: "Sample creative project.", category: "Art", status: .inProgress)
        project.isDemo = true
        context.insert(project)
        for (i, t) in ["Gather references", "Thumbnail sketches", "Final piece"].enumerated() {
            let m = ProjectMilestone(title: t, sortOrder: i); m.isDone = i == 0; context.insert(m); m.project = project
        }

        let goal = LearningGoal(skillName: "DEMO · Conversational Japanese", category: .languages)
        goal.progress = 0.3; goal.isDemo = true
        context.insert(goal)
        let session = StudySession(subject: "Hiragana review", date: day(-2), durationMinutes: 25)
        session.isDemo = true; session.learned = "Sample session."
        context.insert(session); session.goal = goal

        let person = Person(name: "DEMO · Sample Friend", relationship: "Friend")
        person.birthday = day(12); person.isDemo = true
        context.insert(person)

        let workout = Workout(name: "DEMO · Gentle mobility", date: day(-1))
        workout.isCompleted = true; workout.durationMinutes = 20; workout.isDemo = true
        context.insert(workout)
        let ex = Exercise(name: "Cat-cow", sets: 2, reps: 10); context.insert(ex); ex.workout = workout

        let memory = Memory(title: "DEMO · First sea swim of the year", text: "Sample memory.", kind: .reflection, date: day(-30))
        memory.isFavorite = true; memory.isDemo = true; memory.collection = "Summer"
        context.insert(memory)

        let task = TaskItem(title: "DEMO · Water the plants", dueDate: cal.startOfDay(for: Date()))
        task.isDemo = true; context.insert(task)
        let event = LifeEvent(title: "DEMO · Concert", date: day(5, hour: 20)); event.isDemo = true; context.insert(event)

        try? context.save()
        UserDefaults.standard.set(true, forKey: AppSettings.Keys.demoModeActive)
    }

    static func remove(from context: ModelContext) {
        func purge<T: PersistentModel>(_ type: T.Type, _ isDemo: (T) -> Bool) {
            for item in (try? context.fetch(FetchDescriptor<T>())) ?? [] where isDemo(item) { context.delete(item) }
        }
        purge(JournalEntry.self) { $0.isDemo }
        purge(TravelDestination.self) { $0.isDemo }
        purge(TravelTrip.self) { $0.isDemo }
        purge(CreativeProject.self) { $0.isDemo }
        purge(StudySession.self) { $0.isDemo }
        purge(LearningGoal.self) { $0.isDemo }
        purge(Person.self) { $0.isDemo }
        purge(Workout.self) { $0.isDemo }
        purge(Memory.self) { $0.isDemo }
        purge(TaskItem.self) { $0.isDemo }
        purge(LifeEvent.self) { $0.isDemo }
        try? context.save()
        UserDefaults.standard.set(false, forKey: AppSettings.Keys.demoModeActive)
    }
}
