import Foundation

struct PlayerCar: Identifiable {
    let id: Int
    let name: String
    let modelName: String
    let price: Int
    
    let baseSpeed: Float
    let boostSpeed: Float
    let acceleration: Float
    let braking: Float
    let laneChangeSpeed: TimeInterval
}

let carCatalog: [PlayerCar] = [
    // TIER 1 (Lourdes, freins fatigués, esquive lente)
    PlayerCar(id: 1, name: "La Citadine", modelName: "voiture1", price: 0, baseSpeed: 36.0, boostSpeed: 48.0, acceleration: 8.0, braking: 20.0, laneChangeSpeed: 0.22),
    PlayerCar(id: 2, name: "Street Evo", modelName: "voiture2", price: 500, baseSpeed: 36.5, boostSpeed: 50.0, acceleration: 10.0, braking: 24.0, laneChangeSpeed: 0.20),
    
    // TIER 2 (Un peu plus vives)
    PlayerCar(id: 3, name: "Red Venom", modelName: "voiture3", price: 1500, baseSpeed: 37.0, boostSpeed: 53.0, acceleration: 12.0, braking: 28.0, laneChangeSpeed: 0.18),
    PlayerCar(id: 4, name: "Blue Legend", modelName: "voiture4", price: 3000, baseSpeed: 37.5, boostSpeed: 56.0, acceleration: 14.5, braking: 34.0, laneChangeSpeed: 0.16),
    
    // TIER 3 (Le boost commence à pousser fort)
    PlayerCar(id: 5, name: "Onyx", modelName: "voiture5", price: 6000, baseSpeed: 38.0, boostSpeed: 59.0, acceleration: 17.0, braking: 42.0, laneChangeSpeed: 0.14),
    PlayerCar(id: 6, name: "Golden Muscle", modelName: "voiture6", price: 10000, baseSpeed: 38.5, boostSpeed: 62.0, acceleration: 19.5, braking: 50.0, laneChangeSpeed: 0.12),
    
    // TIER 4 (Freins très puissants, esquive rapide)
    PlayerCar(id: 7, name: "Sunset Drifter", modelName: "voiture7", price: 15000, baseSpeed: 39.0, boostSpeed: 66.0, acceleration: 22.0, braking: 58.0, laneChangeSpeed: 0.10),
    PlayerCar(id: 8, name: "Shadow GT", modelName: "voiture8", price: 25000, baseSpeed: 39.5, boostSpeed: 69.0, acceleration: 25.0, braking: 68.0, laneChangeSpeed: 0.09),
    PlayerCar(id: 9, name: "Solar Sting", modelName: "voiture9", price: 40000, baseSpeed: 40.0, boostSpeed: 72.0, acceleration: 28.0, braking: 78.0, laneChangeSpeed: 0.08),
    
    // TIER 5 (Des karts sous stéroïdes : pile sur place, esquive instantanée)
    PlayerCar(id: 10, name: "Rosso Veloce", modelName: "voiture10", price: 60000, baseSpeed: 40.5, boostSpeed: 75.0, acceleration: 32.0, braking: 90.0, laneChangeSpeed: 0.07),
    PlayerCar(id: 11, name: "Yellow Cyclone", modelName: "voiture11", price: 85000, baseSpeed: 41.0, boostSpeed: 78.0, acceleration: 36.0, braking: 105.0, laneChangeSpeed: 0.06),
    PlayerCar(id: 12, name: "Violet Storm", modelName: "voiture12", price: 120000, baseSpeed: 42.0, boostSpeed: 82.0, acceleration: 40.0, braking: 120.0, laneChangeSpeed: 0.05)
]

class GarageManager {
    static func isUnlocked(id: Int) -> Bool {
        if id == 1 { return true } // La première est toujours débloquée
        let unlocked = UserDefaults.standard.string(forKey: "unlockedCars") ?? "1"
        // On utilise components(separatedBy:) pour avoir des vrais String
        return unlocked.components(separatedBy: ",").contains(String(id))
    }
    
    static func unlock(id: Int) {
        let unlocked = UserDefaults.standard.string(forKey: "unlockedCars") ?? "1"
        UserDefaults.standard.set(unlocked + ",\(id)", forKey: "unlockedCars")
    }
}
