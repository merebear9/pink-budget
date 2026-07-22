import Foundation
import SwiftData

@Model
final class BudgetCategory {
    var id: UUID
    var name: String
    var icon: String
    var monthlyLimit: Double
    var colorHex: String
    var sortOrder: Int
    var isActive: Bool
    var matchKeywords: [String]
    var plaidCategories: [String]
    
    init(
        name: String,
        icon: String,
        monthlyLimit: Double,
        colorHex: String,
        sortOrder: Int = 0,
        matchKeywords: [String] = [],
        plaidCategories: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.monthlyLimit = monthlyLimit
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isActive = true
        self.matchKeywords = matchKeywords
        self.plaidCategories = plaidCategories
    }
}

// MARK: - $4,000/mo Budget (based on 12 months of actual data)
//
// ┌─────────────────────────────────────────────────────┐
// │ FIXED BILLS                              $1,874/mo  │
// │   Rent .......................... $1,500             │
// │   Electric ....................... $100              │
// │   Internet ........................ $60              │
// │   Phone ........................... $50              │
// │   Planet Fitness .................. $25              │
// │   Medications ..................... $50              │
// │   Car Insurance ................... $89              │
// │                                                     │
// │ VARIABLE SPENDING                        $2,126/mo  │
// │   Groceries ...................... $250              │
// │   Gas & Tolls .................... $175              │
// │   Dining & Coffee ................ $200              │
// │   Shopping ....................... $175              │
// │   Cat Care ....................... $110              │
// │   Subscriptions ................... $55              │
// │   Travel & Hotels ................ $100              │
// │   Entertainment ................... $75              │
// │   Medical copays .................. $75              │
// │   Personal Care ................... $60              │
// │   Misc ............................ $51              │
// │                                                     │
// │ TOTAL                                    $4,000/mo  │
// │                                                     │
// │ Actual 12-month avg (adjusted): $4,910/mo           │
// │ This budget cuts ~$910/mo, mainly from dining       │
// │ and shopping. Achievable with daily alerts.          │
// │                                                     │
// │ RETIREMENT (from take-home):     $2,000/mo target   │
// │   (TSP + 401k already pre-paycheck)                 │
// │   Roth IRA: $583/mo                                 │
// │   Brokerage: remainder                              │
// │                                                     │
// │ Income $6,400 - Budget $4,000 = $2,400 for retire   │
// │ Surplus: $400/mo buffer                             │
// └─────────────────────────────────────────────────────┘

extension BudgetCategory {
    static func defaultCategories() -> [BudgetCategory] {
        [
            // ── FIXED ──
            BudgetCategory(
                name: "Rent",
                icon: "house.fill",
                monthlyLimit: 1500,
                colorHex: "E91E8C",
                sortOrder: 0,
                matchKeywords: ["foundry", "buckingham", "rent", "lease", "apts mccl"],
                plaidCategories: ["RENT"]
            ),
            BudgetCategory(
                name: "Utilities",
                icon: "bolt.fill",
                monthlyLimit: 210,
                colorHex: "8B5CF6",
                sortOrder: 1,
                matchKeywords: [
                    "comcast", "amer elect", "aep", "ameren", "cwlp",
                    "at&t prepaid", "vesta", "planet fitness",
                    "auto. funds transfer"
                ],
                plaidCategories: [
                    "UTILITIES_ELECTRIC", "UTILITIES_INTERNET",
                    "UTILITIES_TELEPHONE"
                ]
            ),
            BudgetCategory(
                name: "Car Insurance",
                icon: "car.circle.fill",
                monthlyLimit: 89,
                colorHex: "6366F1",
                sortOrder: 2,
                matchKeywords: ["natl gen ins", "national general", "allstate"],
                plaidCategories: ["INSURANCE_AUTO"]
            ),
            BudgetCategory(
                // Actual 12mo avg: $180/mo (includes one-time Medvi $399)
                // Recurring: ~$75/mo (meds + copays)
                name: "Medical",
                icon: "cross.case.fill",
                monthlyLimit: 75,
                colorHex: "EF4444",
                sortOrder: 3,
                matchKeywords: [
                    "walgreens", "cvs", "pharmacy", "medical",
                    "dermatolog", "clinic", "hospital", "grow therapy",
                    "medvi", "callondoc"
                ],
                plaidCategories: [
                    "MEDICAL_PHARMACIES_AND_SUPPLEMENTS",
                    "MEDICAL_SERVICES"
                ]
            ),

            // ── VARIABLE ──
            BudgetCategory(
                // Actual 12mo avg: $224/mo
                // Budget: $250 (small buffer, you're naturally disciplined here)
                name: "Groceries",
                icon: "cart.fill",
                monthlyLimit: 250,
                colorHex: "10B981",
                sortOrder: 4,
                matchKeywords: [
                    "walmart", "wm supercenter", "kroger", "aldi", "meijer",
                    "grocery", "dollar general", "dollar tree",
                    "costco"
                ],
                plaidCategories: [
                    "FOOD_AND_DRINK_GROCERIES",
                    "GENERAL_MERCHANDISE_SUPERSTORES"
                ]
            ),
            BudgetCategory(
                // Actual 12mo avg: ~$150/mo gas + $15/mo tolls
                // Budget: $175 (drill months will be higher, normal months lower)
                name: "Gas & Tolls",
                icon: "fuelpump.fill",
                monthlyLimit: 175,
                colorHex: "F59E0B",
                sortOrder: 5,
                matchKeywords: [
                    "shell", "circle k", "marathon", "phillips", "sunoco",
                    "speedway", "bp", "casey", "kwik trip", "thorntons",
                    "love's", "love s", "one9", "pilot", "flying j",
                    "indiana toll", "kt mini mart"
                ],
                plaidCategories: [
                    "TRANSPORTATION_GAS", "TRANSPORTATION_TOLLS"
                ]
            ),
            BudgetCategory(
                // Actual 12mo avg: $391/mo (biggest problem area)
                // Starbucks alone: $56/mo, Mad Goat: $19/mo, fast food: $100+/mo
                // Budget: $200 (a $191 cut -- make coffee at home, halve restaurant visits)
                // This is where the daily alerts will help most
                name: "Dining & Coffee",
                icon: "cup.and.saucer.fill",
                monthlyLimit: 200,
                colorHex: "06B6D4",
                sortOrder: 6,
                matchKeywords: [
                    "starbucks", "mcdonald", "panera", "chipotle",
                    "mad goat", "zion coffee", "intuition coffee",
                    "coffee hound", "smoothie king", "jimmy john",
                    "uber eats", "doordash", "grubhub", "denny",
                    "taco bell", "wendy", "chick-fil-a", "subway",
                    "potosina", "bar and grill", "restaurant",
                    "bresee", "that bar", "richs family",
                    "elas eatery", "twin peaks"
                ],
                plaidCategories: [
                    "FOOD_AND_DRINK_RESTAURANT",
                    "FOOD_AND_DRINK_COFFEE",
                    "FOOD_AND_DRINK_FAST_FOOD",
                    "FOOD_AND_DRINK_FOOD_DELIVERY"
                ]
            ),
            BudgetCategory(
                // Actual 12mo avg: $2,098/mo (massively inflated by Empower dupes,
                // one-time purchases, and Walmart being categorized as shopping)
                // Real recurring after cleanup: ~$200-250/mo
                // Budget: $175 (achievable with 24-hour rule on non-essentials)
                name: "Shopping",
                icon: "bag.fill",
                monthlyLimit: 175,
                colorHex: "EC4899",
                sortOrder: 7,
                matchKeywords: [
                    "amazon", "ebay", "target", "asics", "nike",
                    "exchange service", "aafes",
                    "bath & body", "old navy", "tjmaxx", "t.j.maxx",
                    "marshall", "kohl", "temu", "mercari",
                    "wolf forest"
                ],
                plaidCategories: [
                    "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES",
                    "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES",
                    "GENERAL_MERCHANDISE_OTHER"
                ]
            ),
            BudgetCategory(
                // Actual 12mo avg: $222/mo (includes Litter-Robot $1,496)
                // Without Litter-Robot: $107/mo (Chewy ~$35 + vet visits)
                // Budget: $110 (buffer for unexpected vet visits)
                name: "Cat Care",
                icon: "pawprint.fill",
                monthlyLimit: 110,
                colorHex: "F472B6",
                sortOrder: 8,
                matchKeywords: [
                    "chewy", "petco", "petsmart", "litter-robot",
                    "litter robot", "veterinar", "animal medical",
                    "tender care", "rover.com", "pet"
                ],
                plaidCategories: [
                    "GENERAL_MERCHANDISE_PET_SUPPLIES",
                    "MEDICAL_VETERINARY_SERVICES"
                ]
            ),
            BudgetCategory(
                // After cuts (ElevenLabs, ngrok, Microsoft, Substack):
                // Claude Pro $20 + Spotify $7 + Kindle $12 + Rocket Money $7 + Apple Dev $8 = $54
                name: "Subscriptions",
                icon: "tv.fill",
                monthlyLimit: 55,
                colorHex: "A855F7",
                sortOrder: 9,
                matchKeywords: [
                    "anthropic", "claude", "spotify", "kindle",
                    "rocket money", "apple.com/bill", "icloud",
                    "netflix", "hulu", "youtube", "adobe"
                ],
                plaidCategories: [
                    "GENERAL_MERCHANDISE_SUBSCRIPTION"
                ]
            ),
            BudgetCategory(
                // Actual 12mo avg: $857/mo (includes cruise, NYC, flights)
                // Recurring: just drill travel hotels ~$75-100/mo
                // Budget: $100 (covers drill weekends, AT is per diem)
                name: "Travel & Hotels",
                icon: "bed.double.fill",
                monthlyLimit: 100,
                colorHex: "14B8A6",
                sortOrder: 10,
                matchKeywords: [
                    "hotel", "econo lodge", "best western", "super.com",
                    "hotels.com", "motel", "airbnb", "holiday inn",
                    "courtyard", "quality inn", "baymont",
                    "opera house hotel"
                ],
                plaidCategories: ["TRAVEL_LODGING"]
            ),
            BudgetCategory(
                // Actual 12mo avg: $115/mo
                // Budget: $75 (cut back on impulse stuff, keep Kickapoo etc)
                name: "Entertainment",
                icon: "gamecontroller.fill",
                monthlyLimit: 75,
                colorHex: "F97316",
                sortOrder: 11,
                matchKeywords: [
                    "kickapoo", "cinema", "movie", "bowling", "museum",
                    "preservation hall", "sleepy creek",
                    "grapevine liquors", "wollman park"
                ],
                plaidCategories: [
                    "ENTERTAINMENT_OTHER",
                    "ENTERTAINMENT_SPORTING_EVENTS"
                ]
            ),
            BudgetCategory(
                // Actual 12mo avg: $89/mo (nails, salon, personal)
                // Budget: $60 (every other month on nails saves ~$30)
                name: "Personal Care",
                icon: "sparkles",
                monthlyLimit: 60,
                colorHex: "FB923C",
                sortOrder: 12,
                matchKeywords: [
                    "rooted salon", "alexz nails", "sd nails",
                    "salon", "nails", "spa", "haircut", "beauty",
                    "laundromat"
                ],
                plaidCategories: [
                    "PERSONAL_CARE_HAIR_AND_BEAUTY",
                    "PERSONAL_CARE_LAUNDRY_AND_DRY_CLEANING"
                ]
            ),
            BudgetCategory(
                name: "Misc",
                icon: "ellipsis.circle.fill",
                monthlyLimit: 51,
                colorHex: "9CA3AF",
                sortOrder: 13,
                matchKeywords: [],
                plaidCategories: []
            ),
        ]
    }
}
