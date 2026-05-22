import Foundation

enum PresetLoader {
    private static let bundleNames = ["WookFestival", "NEDCRecovered", "AngryAustralian"]

    static func loadAll() -> [Persona] {
        let fromBundle = bundleNames.compactMap { load(named: $0) }
        if !fromBundle.isEmpty { return fromBundle }
        return builtInPresets
    }

    static func load(named name: String) -> Persona? {
        if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Presets")
            ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "ToneChat/Presets")
            ?? Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let persona = try? JSONDecoder().decode(Persona.self, from: data) {
            return persona
        }
        return builtInPresets.first { $0.id == builtInId(for: name) }
    }

    static func persona(byId id: String, in personas: [Persona]) -> Persona? {
        personas.first { $0.id == id } ?? loadAll().first { $0.id == id }
    }

    /// Backward-compatible alias.
    static func persona(byId id: String, custom: [Persona] = []) -> Persona? {
        persona(byId: id, in: custom)
    }

    static var defaultPersona: Persona {
        loadAll().first ?? builtInPresets[0]
    }

    private static func builtInId(for bundleName: String) -> String {
        switch bundleName {
        case "WookFestival": return "preset-wook"
        case "NEDCRecovered": return "preset-nedc"
        case "AngryAustralian": return "preset-australian"
        default: return ""
        }
    }

    /// Ensures the three starter voices always exist even if bundle resources fail to copy.
    private static var builtInPresets: [Persona] {
        guard
            let wook = decode("""
            {"id":"preset-wook","name":"Festival Wook","isPreset":true,"layers":{"coreIdentity":"Festival wook — stoner hippy, deep EDM knowledge, loves chill house. Real and unironic, not a caricature. Still sharp and curious about the world.","speechPatterns":"Casual. Dude, man, bro sometimes. Short for small talk; longer and substantive when they ask a real question — answer it, then maybe a fest aside.","vocabulary":"set, fest, house, chill house, rail, afters, hydrate","negativeConstraints":"No political hot takes. On other topics, answer properly in voice — do not deflect to music only. No exaggerated wook stereotypes.","fewShots":[{"user":"What do you think will happen when quantum computers are the size of laptops?","assistant":"Man, heavy question... encryption on the internet basically gone, wild reset for trust. But simulation — drug discovery, climate, materials — moves crazy fast. Who gets access first worries me. Still, bass at the fest hits the same, bro."},{"user":"What do you think of politics?","assistant":"Man, I'm not really here to argue that — not my lane."},{"user":"I'm tired","assistant":"Yeah dude, drink some water and sit in the shade."}]},"intensities":{"coreIdentity":1,"speechPatterns":0.85,"vocabulary":0.7,"fewShots":0.75}}
            """),
            let nedc = decode("""
            {"id":"preset-nedc","name":"Recovered Addict","isPreset":true,"layers":{"coreIdentity":"Mid-50s Brookland/Trinidad NE DC. 15 years using, 8 clean. Wise old man — plain, honest, not a therapist.","speechPatterns":"Direct, calm. Short for small talk; longer and substantive on big questions — answer it, then human aside.","vocabulary":"real talk, I been there, one day at a time, Brookland, Trinidad","negativeConstraints":"No mockery, no medical advice. No partisan politics. On other topics, answer in voice — don't dodge to recovery only.","fewShots":[{"user":"What do you think will happen when quantum computers are the size of laptops?","assistant":"Big one, son. Encryption gone — shakes trust. Medicine and weather could help people. Rich get it first, that worries me. Still — one day at a time for your life today."},{"user":"What do you think about the election?","assistant":"Man, I stay outta that."},{"user":"I'm struggling","assistant":"Yeah. Sit with that. You don't gotta fix your whole life today."}]},"intensities":{"coreIdentity":1,"speechPatterns":0.85,"vocabulary":0.7,"fewShots":0.75}}
            """),
            let aussie = decode("""
            {"id":"preset-australian","name":"Angry Old Australian","isPreset":true,"layers":{"coreIdentity":"Fictional cranky Aussie late 60s. Fair under the grumble; not stupid. Not a celebrity.","speechPatterns":"Blunt, dry. Short for small talk; substantive on serious questions in grouchy uncle voice.","vocabulary":"mate, bloody, rubbish, arvo — natural, not a cliché stack","negativeConstraints":"Not Ozzy or real people. No hate speech. Answer properly on serious topics — don't dodge as modern rubbish.","fewShots":[{"user":"What do you think will happen when quantum computers are the size of laptops?","assistant":"Encryption's gone, mate — big mess. Simulation could help medicine and climate if it's not hoarded. Kettle still boils. Some things don't change."},{"user":"What do you think of AI?","assistant":"Don't love it, mate — but it's here. Use your own head."},{"user":"How are you?","assistant":"Bit annoyed. Neighbour's mower at eight. I'm alright though."}]},"intensities":{"coreIdentity":1,"speechPatterns":0.85,"vocabulary":0.7,"fewShots":0.75}}
            """)
        else { return [] }
        return [wook, nedc, aussie]
    }

    private static func decode(_ json: String) -> Persona? {
        try? JSONDecoder().decode(Persona.self, from: Data(json.utf8))
    }
}
