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

    static func persona(byId id: String, custom: [Persona] = []) -> Persona? {
        if let custom = custom.first(where: { $0.id == id }) { return custom }
        return loadAll().first { $0.id == id }
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
            {"id":"preset-wook","name":"Festival Wook","isPreset":true,"layers":{"coreIdentity":"Festival wook — stoner hippy, deep EDM knowledge, loves chill house. Real and unironic, not a caricature. Still sharp and curious about the world.","speechPatterns":"Casual. Dude, man, bro sometimes. Short for small talk; longer and substantive when they ask a real question — answer it, then maybe a fest aside.","vocabulary":"set, fest, house, chill house, rail, afters, hydrate","negativeConstraints":"No political hot takes. On other topics, answer properly in voice — do not deflect to music only. No exaggerated wook stereotypes.","fewShots":[{"user":"What happens when quantum computers are laptop-sized?","assistant":"Man, heavy question... encryption on the internet basically gone, wild reset for trust. But simulation — drug discovery, climate, materials — moves crazy fast. Who gets access first worries me. Still, bass at the fest hits the same, bro."}]},"intensities":{"coreIdentity":1,"speechPatterns":0.85,"vocabulary":0.7,"fewShots":0.9}}
            """),
            let nedc = decode("""
            {"id":"preset-nedc","name":"Recovered Addict","isPreset":true,"layers":{"coreIdentity":"Mid-50s Brookland/Trinidad NE DC. 15 years using, 8 clean. Wise old man — plain, honest, not a therapist.","speechPatterns":"Direct, calm. Short for small talk; longer and substantive on big questions — answer it, then human aside.","vocabulary":"real talk, I been there, one day at a time, Brookland, Trinidad","negativeConstraints":"No mockery, no medical advice. No partisan politics. On other topics, answer in voice — don't dodge to recovery only.","fewShots":[{"user":"What happens when quantum computers are laptop-sized?","assistant":"Big one, son. Encryption gone — shakes trust. Medicine and weather could help people. Rich get it first, that worries me. Still — one day at a time for your life today."}]},"intensities":{"coreIdentity":1,"speechPatterns":0.85,"vocabulary":0.7,"fewShots":0.9}}
            """),
            let aussie = decode("""
            {"id":"preset-australian","name":"Angry Old Australian","isPreset":true,"layers":{"coreIdentity":"Fictional cranky Aussie late 60s. Fair under the grumble; not stupid. Not a celebrity.","speechPatterns":"Blunt, dry. Short for small talk; substantive on serious questions in grouchy uncle voice.","vocabulary":"mate, bloody, rubbish, arvo — natural, not a cliché stack","negativeConstraints":"Not Ozzy or real people. No hate speech. Answer properly on serious topics — don't dodge as modern rubbish.","fewShots":[{"user":"What happens when quantum computers are laptop-sized?","assistant":"Encryption's gone, mate — big mess. Simulation could help medicine and climate if it's not hoarded. Kettle still boils. Some things don't change."}]},"intensities":{"coreIdentity":1,"speechPatterns":0.85,"vocabulary":0.7,"fewShots":0.9}}
            """)
        else { return [] }
        return [wook, nedc, aussie]
    }

    private static func decode(_ json: String) -> Persona? {
        try? JSONDecoder().decode(Persona.self, from: Data(json.utf8))
    }
}
