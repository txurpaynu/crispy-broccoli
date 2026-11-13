import SceneKit

/// Interactable components for the apartment. Each one has a real consequence:
/// state changes, flags, inventory, journal entries or world reactions.
@MainActor
enum ApartmentInteractables {
    static func register(in world: ApartmentWorld) {
        let r = world.interaction

        r.register(ActionInteractable(id: "computer", prompt: { _ in "Use computer" }) { ctx in
            AudioManager.shared.play(.mouseClick)
            ctx.world.sitAtComputer { ctx.session.enterDesktop() }
        })

        r.register(ActionInteractable(id: "bed", prompt: { ctx in
            ctx.session.canSleep ? "Go to sleep" : "Bed"
        }) { ctx in
            let s = ctx.session
            if s.canSleep {
                AudioManager.shared.play(.bedSheets)
                s.sleep()
            } else if s.has("vexley_refused_exit") {
                s.say("Not with that thing still running on my computer. I should at least scan it.")
            } else if s.has("old_decrypted") {
                s.say("Not now. I want to see what's in that file.")
            } else if s.has("remaster_purchased") {
                s.say("Not until I've sorted out this game.")
            } else {
                s.say("I'm not tired yet. That's the problem.")
            }
        })

        r.register(ActionInteractable(id: "lamp", prompt: { ctx in
            ctx.world.lampOn ? "Turn off lamp" : "Turn on lamp"
        }) { ctx in
            let on = !ctx.world.lampOn
            ctx.world.setLamp(on)
            if on { ctx.session.unset("lamp_off") } else { ctx.session.set("lamp_off") }
            if !on && ctx.session.has("vexley_refused_exit") {
                ctx.session.say("The monitor's the only light now. I wish it wasn't.")
            }
        })

        r.register(ActionInteractable(id: "door", prompt: { _ in "Open door" }) { ctx in
            ctx.world.rattleDoor()
            let n = ctx.session.increment("door_tries")
            switch n {
            case 1: ctx.session.say("Stuck again. The landlord said he'd fix it in March.")
            case 2: ctx.session.say("It's one in the morning anyway. Where would I even go?")
            default: ctx.session.say("Fine. Stay stuck.")
            }
        })

        r.register(ActionInteractable(id: "window", prompt: { _ in "Look outside" }) { ctx in
            let s = ctx.session
            if s.has("vexley_refused_exit") {
                s.say("For a second I saw the monitor reflected in the glass. Something pink on it.")
                AudioManager.shared.play(.heartbeat)
            } else if s.has("old_launched") {
                s.say("Every other window in the building is dark.")
            } else {
                s.say("The city's quiet. A few people still awake. Like me.")
            }
            s.set("looked_outside")
        })

        r.register(ActionInteractable(id: "poster", prompt: { _ in "Look at poster" }) { ctx in
            AudioManager.shared.play(.paper)
            ctx.session.inspect("poster")
        })

        r.register(ActionInteractable(id: "gamebox", prompt: { ctx in
            ctx.session.hasItem("gamebox") ? nil : "Take PAPERLIGHT box"
        }) { ctx in
            AudioManager.shared.play(.pickup)
            ctx.node?.removeFromParentNode()
            ctx.session.addItem("gamebox")
            ctx.session.say("My old copy. There's still something rattling around inside it.")
        })

        r.register(ActionInteractable(id: "phone", prompt: { _ in "Check phone" }) { ctx in
            AudioManager.shared.play(.uiClick)
            ctx.session.inspect("phone_theo")
            ctx.session.set("read_phone")
        })

        r.register(ActionInteractable(id: "wardrobe", prompt: { _ in "Open wardrobe" }) { ctx in
            AudioManager.shared.play(.doorRattle)
            ctx.session.say(ctx.session.counter("wardrobe") == 0
                            ? "Clothes I don't wear and a box of cables I'll never need."
                            : "Still just clothes.")
            ctx.session.increment("wardrobe")
        })

        r.register(ActionInteractable(id: "mug", prompt: { ctx in
            ctx.session.has("mug_empty") ? "Empty mug" : "Drink coffee"
        }) { ctx in
            if ctx.session.has("mug_empty") {
                ctx.session.say("Empty. I should wash it. I won't.")
            } else {
                ctx.session.set("mug_empty")
                ctx.session.say("Cold. Why do I keep doing this.")
            }
        })

        r.register(ActionInteractable(id: "books", prompt: { _ in "Look at books" }) { ctx in
            ctx.session.say("Strategy guides, mostly. I kept every single one.")
        })

        r.register(ActionInteractable(id: "trash", prompt: { _ in "Look in the trash" }) { ctx in
            AudioManager.shared.play(.paper)
            ctx.session.inspect("todo_crumpled")
        })
    }
}
