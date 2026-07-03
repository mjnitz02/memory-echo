//
//  MemoryGlyph.swift
//  MemoryEchoCore
//
//  Pure function: title -> a white SF Symbol that hints at the *type* of
//  activity. NOT user-configurable ("you get what you get"). This is the only
//  channel that conveys category — color is reserved for effort × staleness.
//
//  `GlyphCategory` is the single source of truth: each case carries its SF
//  Symbol and the keywords that trigger it in the fast offline matcher. The
//  on-device model (GlyphResolver) chooses from the SAME case set, so the LLM
//  can never name a symbol that doesn't exist — it picks a slot, we map the
//  slot to its symbol. ~130 buckets give the model real range without needing
//  a third-party icon library. Glyph is derived, never stored (ShortTermMemory
//  caches the model's pick separately), so re-tuning needs no migration.
//
//  Every `symbol` is validated against the live SF Symbol catalog by a unit
//  test, so a typo fails CI rather than rendering blank on device.
//

import Foundation

/// The category vocabulary shared by the offline keyword matcher and the
/// on-device model. Declaration order is also match priority: earlier (more
/// specific) categories win a keyword tie in the offline fallback.
public enum GlyphCategory: String, CaseIterable, Sendable {
    /// Communication
    case call, videoCall, email, message, social, send, announce, contact
    /// Money & admin
    case payment, finance, bank, tax, insurance, subscription, transfer, receipt, password, security
    /// Shopping & delivery
    case shopping, errands, delivery, returns, giftcard, gift, wishlist
    /// Documents & writing
    case writing, document, sign, print, form, notes, bookmark, folder
    /// Work & productivity
    case work, project, meeting, presentation, deadline, idea, goal, review
    /// Tech & digital
    case computer, device, software, code, wifi, backup, cloud, settings
    /// Home & chores
    case cleaning, laundry, dishes, trash, repair, build, paint, plumbing, maintenance, home, furniture, bed, plants
    /// Food & drink
    case cooking, baking, coffee, alcohol, restaurant
    /// Health & body
    case health, medication, doctor, mentalHealth, fitness, walk, yoga, sleep, wellbeing
    /// Kids & play
    case play, hygiene, bathTime, playground, outing
    /// Sports & outdoors
    case sports, soccer, basketball, baseball, swimming, martialArts, skiing, dance, hiking, camping, fishing, beach,
         picnic, outdoors, puzzle
    /// Family & social
    case kids, school, people, family, date, pets, celebration, volunteer
    /// Travel & places
    case travel, packTrip, hotel, directions, location, transit, train, bike, vehicle, carpool, fuel
    /// Leisure & learning
    case reading, study, music, instrument, movie, tv, game, art, photo
    /// General
    case haircut, weather, event, reminder

    /// The white SF Symbol drawn on the band for this category.
    public var symbol: String {
        switch self {
        case .call: "phone.fill"
        case .videoCall: "video.fill"
        case .email: "envelope.fill"
        case .message: "message.fill"
        case .social: "bubble.left.and.bubble.right.fill"
        case .send: "paperplane.fill"
        case .announce: "megaphone.fill"
        case .contact: "person.crop.circle.fill"
        case .payment: "creditcard.fill"
        case .finance: "dollarsign.circle.fill"
        case .bank: "building.columns.fill"
        case .tax: "percent"
        case .insurance: "shield.fill"
        case .subscription: "arrow.triangle.2.circlepath"
        case .transfer: "arrow.left.arrow.right"
        case .receipt: "doc.plaintext.fill"
        case .password: "key.fill"
        case .security: "lock.fill"
        case .shopping: "cart.fill"
        case .errands: "bag.fill"
        case .delivery: "shippingbox.fill"
        case .returns: "arrow.uturn.backward.circle.fill"
        case .giftcard: "giftcard.fill"
        case .gift: "gift.fill"
        case .wishlist: "star.fill"
        case .writing: "pencil"
        case .document: "doc.text.fill"
        case .sign: "signature"
        case .print: "printer.fill"
        case .form: "checklist"
        case .notes: "note.text"
        case .bookmark: "bookmark.fill"
        case .folder: "folder.fill"
        case .work: "briefcase.fill"
        case .project: "list.bullet.rectangle.fill"
        case .meeting: "calendar.badge.clock"
        case .presentation: "chart.bar.fill"
        case .deadline: "alarm.fill"
        case .idea: "lightbulb.fill"
        case .goal: "target"
        case .review: "checkmark.seal.fill"
        case .computer: "laptopcomputer"
        case .device: "iphone"
        case .software: "arrow.down.circle.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .wifi: "wifi"
        case .backup: "externaldrive.fill"
        case .cloud: "icloud.fill"
        case .settings: "gearshape.fill"
        case .cleaning: "sparkles"
        case .laundry: "washer.fill"
        case .dishes: "dishwasher.fill"
        case .trash: "trash.fill"
        case .repair: "wrench.and.screwdriver.fill"
        case .build: "hammer.fill"
        case .paint: "paintbrush.fill"
        case .plumbing: "drop.fill"
        case .maintenance: "wrench.adjustable.fill"
        case .home: "house.fill"
        case .furniture: "sofa.fill"
        case .bed: "bed.double.fill"
        case .plants: "leaf.fill"
        case .cooking: "fork.knife"
        case .baking: "oven.fill"
        case .coffee: "cup.and.saucer.fill"
        case .alcohol: "wineglass.fill"
        case .restaurant: "fork.knife.circle.fill"
        case .health: "cross.case.fill"
        case .medication: "pills.fill"
        case .doctor: "stethoscope"
        case .mentalHealth: "brain.head.profile"
        case .fitness: "figure.run"
        case .walk: "figure.walk"
        case .yoga: "figure.yoga"
        case .sleep: "zzz"
        case .wellbeing: "heart.fill"
        case .play: "teddybear.fill"
        case .hygiene: "hands.and.sparkles.fill"
        case .bathTime: "shower.fill"
        case .playground: "figure.play"
        case .outing: "figure.2.and.child.holdinghands"
        case .sports: "sportscourt.fill"
        case .soccer: "soccerball"
        case .basketball: "basketball.fill"
        case .baseball: "baseball.fill"
        case .swimming: "figure.pool.swim"
        case .martialArts: "figure.martial.arts"
        case .skiing: "figure.skiing.downhill"
        case .dance: "figure.socialdance"
        case .hiking: "figure.hiking"
        case .camping: "tent.fill"
        case .fishing: "fish.fill"
        case .beach: "beach.umbrella.fill"
        case .picnic: "basket.fill"
        case .outdoors: "mountain.2.fill"
        case .puzzle: "puzzlepiece.fill"
        case .kids: "figure.and.child.holdinghands"
        case .school: "graduationcap.fill"
        case .people: "person.2.fill"
        case .family: "person.3.fill"
        case .date: "heart.circle.fill"
        case .pets: "pawprint.fill"
        case .celebration: "balloon.fill"
        case .volunteer: "hands.clap.fill"
        case .travel: "airplane"
        case .packTrip: "suitcase.fill"
        case .hotel: "building.2.fill"
        case .directions: "map.fill"
        case .location: "mappin.and.ellipse"
        case .transit: "bus.fill"
        case .train: "tram.fill"
        case .bike: "bicycle"
        case .vehicle: "car.fill"
        case .carpool: "car.2.fill"
        case .fuel: "fuelpump.fill"
        case .reading: "book.fill"
        case .study: "book.closed.fill"
        case .music: "music.note"
        case .instrument: "guitars.fill"
        case .movie: "film.fill"
        case .tv: "tv.fill"
        case .game: "gamecontroller.fill"
        case .art: "paintpalette.fill"
        case .photo: "camera.fill"
        case .haircut: "scissors"
        case .weather: "cloud.sun.fill"
        case .event: "calendar"
        case .reminder: "bell.fill"
        }
    }

    /// Words/phrases that trigger this category in the offline matcher.
    public var keywords: [String] {
        switch self {
        case .call: ["call", "phone", "dial", "ring", "voicemail"]
        case .videoCall: ["facetime", "video call", "zoom", "video chat"]
        case .email: ["email", "inbox", "reply", "forward"]
        case .message: ["text", "message", "whatsapp", "dm"]
        case .social: ["post", "tweet", "instagram", "social", "comment"]
        case .send: ["send", "submit", "dispatch"]
        case .announce: ["announce", "broadcast", "promote"]
        case .contact: ["contact", "add contact", "save number"]
        case .payment: ["pay", "bill", "rent", "invoice", "mortgage", "card", "due"]
        case .finance: ["budget", "save", "invest", "savings", "money"]
        case .bank: ["bank", "atm", "deposit", "withdraw"]
        case .tax: ["tax", "irs", "hmrc", "refund", "deduction"]
        case .insurance: ["insurance", "policy", "claim", "coverage"]
        case .subscription: ["subscription", "renew", "cancel plan", "billing"]
        case .transfer: ["transfer", "wire", "venmo", "send money"]
        case .receipt: ["receipt", "expense", "reimburse"]
        case .password: ["password", "login", "passcode", "2fa", "credentials"]
        case .security: ["lock", "secure", "encrypt", "unlock"]
        case .shopping: ["buy", "grocery", "groceries", "shop", "store", "milk", "order"]
        case .errands: ["errand", "pick up", "drop off", "run out for"]
        case .delivery: ["package", "delivery", "parcel", "ship", "courier"]
        case .returns: ["return", "send back", "refund item"]
        case .giftcard: ["gift card", "voucher", "top up"]
        case .gift: ["gift", "present", "wrap"]
        case .wishlist: ["wishlist", "wish list", "add to wishlist", "save for later", "favorite"]
        case .writing: ["write", "note", "jot", "draft", "journal"]
        case .document: ["document", "paperwork", "scan", "file", "contract"]
        case .sign: ["sign", "signature", "initial"]
        case .print: ["print", "printout"]
        case .form: ["form", "fill out", "application", "survey", "checklist"]
        case .notes: ["notes", "memo", "sticky note"]
        case .bookmark: ["bookmark", "save link", "read later"]
        case .folder: ["organize files", "folder", "sort docs"]
        case .work: ["work", "job", "office"]
        case .project: ["project", "task list", "milestone"]
        case .meeting: ["meeting", "standup", "sync", "1:1"]
        case .presentation: ["presentation", "slides", "deck", "pitch", "report"]
        case .deadline: ["deadline", "urgent", "asap"]
        case .idea: ["idea", "brainstorm", "think about", "concept"]
        case .goal: ["goal", "objective", "target", "aim"]
        case .review: ["review", "approve", "sign off", "verify"]
        case .computer: ["laptop", "computer", "pc", "mac"]
        case .device: ["device", "screen time", "set up phone"]
        case .software: ["download", "install", "update app"]
        case .code: ["code", "bug", "deploy", "commit", "dev"]
        case .wifi: ["wifi", "router", "internet", "network"]
        case .backup: ["backup", "hard drive", "external drive", "storage"]
        case .cloud: ["icloud", "cloud", "sync", "upload"]
        case .settings: ["settings", "configure", "setup", "preferences"]
        case .cleaning: ["clean", "tidy", "declutter", "vacuum", "dust", "scrub"]
        case .laundry: ["laundry", "wash clothes", "fold laundry", "washer", "dryer", "clothes"]
        case .dishes: [
                "dishes",
                "wash dishes",
                "do the dishes",
                "dishwasher",
                "load the dishwasher",
                "unload the dishwasher"
            ]
        case .trash: ["trash", "garbage", "bins", "recycle", "rubbish"]
        case .repair: ["fix", "repair", "mend", "tighten", "assemble"]
        case .build: ["build", "hang", "mount", "drill", "shelf"]
        case .paint: ["paint", "decorate", "repaint", "wall"]
        case .plumbing: ["leak", "plumbing", "faucet", "pipe", "drain"]
        case .maintenance: [
                "maintenance",
                "upkeep",
                "tune up",
                "service the",
                "routine service",
                "change the filter",
                "change filter"
            ]
        case .home: ["house", "home", "apartment", "move", "landlord"]
        case .furniture: ["furniture", "sofa", "couch", "ikea"]
        case .bed: ["bed", "mattress", "bedroom"]
        case .plants: [
                "water plant",
                "garden",
                "lawn",
                "mow",
                "weed",
                "flowers",
                "rake",
                "leaves",
                "yard work",
                "yardwork"
            ]
        case .cooking: [
                "cook",
                "dinner",
                "lunch",
                "breakfast",
                "supper",
                "meal",
                "meal prep",
                "recipe",
                "food",
                "eat",
                "snack",
                "pack lunch",
                "lunchbox"
            ]
        case .baking: ["bake", "baking", "cookies", "cupcakes", "muffins", "cake batter", "brownies"]
        case .coffee: ["coffee", "tea", "cafe", "brew"]
        case .alcohol: ["wine", "beer", "drinks", "bar"]
        case .restaurant: ["restaurant", "dine out", "reservation", "takeout"]
        case .health: ["health", "clinic", "gp", "medical"]
        case .medication: ["prescription", "pills", "medicine", "refill", "pharmacy"]
        case .doctor: ["doctor", "checkup", "physical", "dentist", "pediatrician", "well visit", "vaccine", "shots"]
        case .mentalHealth: ["therapy", "meditate", "mental health", "mindfulness"]
        case .fitness: ["gym", "run", "jog", "workout", "exercise", "train"]
        case .walk: ["walk", "steps", "stroll"]
        case .yoga: ["yoga", "stretch", "pilates"]
        case .sleep: ["sleep", "nap", "rest", "bedtime"]
        case .wellbeing: ["self care", "relax", "unwind", "wellbeing"]
        case .play: [
                "pretend play",
                "imaginative play",
                "play pretend",
                "make believe",
                "dress up",
                "dolls",
                "action figures",
                "toys",
                "legos",
                "building blocks",
                "tea party",
                "playdate",
                "play date"
            ]
        case .hygiene: [
                "teeth",
                "brush teeth",
                "brushing teeth",
                "floss",
                "toothbrush",
                "toothpaste",
                "wash hands",
                "wash up",
                "hand washing",
                "hygiene"
            ]
        case .bathTime: ["bath", "bath time", "bathtub", "shower", "wash hair", "rinse off"]
        case .playground: ["playground", "swings", "monkey bars", "play structure", "play outside", "slide at the park"]
        case .outing: [
                "outing",
                "day out",
                "field trip",
                "zoo",
                "museum",
                "aquarium",
                "children's museum",
                "play place"
            ]
        case .sports: [
                "sports",
                "team practice",
                "sports practice",
                "game day",
                "the game",
                "tryouts",
                "scrimmage",
                "tournament"
            ]
        case .soccer: ["soccer", "soccer practice", "soccer game", "soccer match"]
        case .basketball: ["basketball", "hoops", "basketball practice"]
        case .baseball: ["baseball", "tee ball", "t-ball", "little league", "softball", "batting practice"]
        case .swimming: ["swim", "swimming", "swim lesson", "swim practice", "pool time"]
        case .martialArts: ["karate", "taekwondo", "martial arts", "jiu jitsu", "judo", "dojo"]
        case .skiing: ["skiing", "snowboard", "sledding", "snow day", "snow play", "tubing"]
        case .dance: ["dance", "dancing", "ballet", "recital", "dance class"]
        case .hiking: ["hike", "hiking", "trail", "nature walk"]
        case .camping: ["camp", "camping", "campsite", "campfire", "s'mores"]
        case .fishing: ["fishing", "go fishing", "cast a line", "bait"]
        case .beach: ["beach", "seaside", "sandcastle", "ocean", "boardwalk"]
        case .picnic: ["picnic", "picnic lunch"]
        case .outdoors: ["outside", "outdoors", "nature", "fresh air", "the park", "go to the park", "backyard"]
        case .puzzle: ["puzzle", "jigsaw", "board game", "card game", "crossword"]
        case .kids: ["kid", "child", "daycare", "homework", "son", "daughter"]
        case .school: ["school", "class", "exam", "tuition", "university"]
        case .people: ["friend", "meet", "catch up", "visit", "hang out"]
        case .family: ["family", "parents", "relatives", "reunion"]
        case .date: ["date night", "anniversary", "partner", "romantic"]
        case .pets: ["dog", "cat", "pet", "vet", "litter", "feed the"]
        case .celebration: ["party", "celebrate", "rsvp", "birthday"]
        case .volunteer: ["volunteer", "charity", "donate", "fundraiser", "give back", "food bank", "donation drive"]
        case .travel: ["flight", "fly", "trip", "vacation", "airport"]
        case .packTrip: ["pack", "luggage", "suitcase", "packing"]
        case .hotel: ["hotel", "accommodation", "airbnb", "check in"]
        case .directions: ["directions", "map", "route", "navigate"]
        case .location: ["location", "address", "place", "pin"]
        case .transit: ["bus", "transit", "commute", "subway"]
        case .train: ["train", "rail", "metro"]
        case .bike: ["bike", "cycle", "ride bikes", "training wheels", "balance bike", "scooter", "skateboard"]
        case .vehicle: ["car", "drive", "mot", "parking", "garage"]
        case .carpool: ["carpool", "school run", "school pickup", "car line", "pickup line"]
        case .fuel: ["gas", "fuel", "petrol", "fill up", "charge car"]
        case .reading: ["read", "book", "chapter", "novel", "bedtime story", "story time", "storytime", "read to"]
        case .study: ["study", "revise", "course", "learn"]
        case .music: ["music", "song", "playlist", "listen to music"]
        case .instrument: ["guitar", "piano", "band", "instrument"]
        case .movie: ["movie", "cinema", "netflix"]
        case .tv: ["tv", "show", "stream", "episode"]
        case .game: ["game", "gaming", "xbox", "playstation"]
        case .art: ["art", "draw", "sketch", "craft", "coloring", "stickers", "playdough", "play doh"]
        case .photo: ["photo", "picture", "camera", "shoot"]
        case .haircut: ["haircut", "barber", "trim", "salon"]
        case .weather: ["weather", "forecast", "rain check"]
        case .event: ["event", "appointment", "schedule", "book", "rsvp", "reschedule", "calendar"]
        case .reminder: ["reminder", "remember", "don't forget", "follow up"]
        }
    }

    /// All category names — the constrained vocabulary handed to the model.
    public static var allRawValues: [String] {
        allCases.map(\.rawValue)
    }

    /// First category whose keywords appear in the (already-lowercased) text.
    static func firstMatch(in lowered: String) -> GlyphCategory? {
        allCases.first { category in
            category.keywords.contains { lowered.contains($0) }
        }
    }
}

public enum MemoryGlyph {
    /// Neutral fallback — a 4-point spark — when nothing matches.
    public static let fallback = "sparkle"

    /// The fast, offline SF Symbol for a title (keyword matcher). Used for the
    /// live preview and as the instant value before / when the on-device model
    /// in GlyphResolver isn't available.
    public static func symbol(for title: String) -> String {
        GlyphCategory.firstMatch(in: title.lowercased())?.symbol ?? fallback
    }
}
