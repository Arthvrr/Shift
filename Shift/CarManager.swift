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
    // TIER 1
    PlayerCar(id: 1, name: "La Citadine", modelName: "voiture1", price: 0, baseSpeed: 40.0, boostSpeed: 60.0, acceleration: 10.0, braking: 45.0, laneChangeSpeed: 0.15),
    PlayerCar(id: 2, name: "Street Evo", modelName: "voiture2", price: 500, baseSpeed: 42.0, boostSpeed: 64.0, acceleration: 12.0, braking: 48.0, laneChangeSpeed: 0.14),
    // TIER 2
    PlayerCar(id: 3, name: "Red Venom", modelName: "voiture3", price: 1500, baseSpeed: 44.0, boostSpeed: 68.0, acceleration: 14.0, braking: 52.0, laneChangeSpeed: 0.13),
    PlayerCar(id: 4, name: "Blue Legend", modelName: "voiture4", price: 3000, baseSpeed: 46.0, boostSpeed: 72.0, acceleration: 16.0, braking: 56.0, laneChangeSpeed: 0.12),
    // TIER 3
    PlayerCar(id: 5, name: "Onyx", modelName: "voiture5", price: 6000, baseSpeed: 48.0, boostSpeed: 76.0, acceleration: 18.0, braking: 60.0, laneChangeSpeed: 0.11),
    PlayerCar(id: 6, name: "Golden Muscle", modelName: "voiture6", price: 10000, baseSpeed: 52.0, boostSpeed: 82.0, acceleration: 22.0, braking: 65.0, laneChangeSpeed: 0.09),
    // TIER 4
    PlayerCar(id: 7, name: "Sunset Drifter", modelName: "voiture7", price: 15000, baseSpeed: 54.0, boostSpeed: 85.0, acceleration: 24.0, braking: 68.0, laneChangeSpeed: 0.085),
    PlayerCar(id: 8, name: "Shadow GT", modelName: "voiture8", price: 25000, baseSpeed: 56.0, boostSpeed: 88.0, acceleration: 26.0, braking: 72.0, laneChangeSpeed: 0.08),
    PlayerCar(id: 9, name: "Solar Sting", modelName: "voiture9", price: 40000, baseSpeed: 58.0, boostSpeed: 92.0, acceleration: 28.0, braking: 76.0, laneChangeSpeed: 0.075),
    // TIER 5
    PlayerCar(id: 10, name: "Rosso Veloce", modelName: "voiture10", price: 60000, baseSpeed: 60.0, boostSpeed: 96.0, acceleration: 30.0, braking: 80.0, laneChangeSpeed: 0.07),
    PlayerCar(id: 11, name: "Yellow Cyclone", modelName: "voiture11", price: 85000, baseSpeed: 62.0, boostSpeed: 100.0, acceleration: 32.0, braking: 85.0, laneChangeSpeed: 0.065),
    PlayerCar(id: 12, name: "Violet Storm", modelName: "voiture12", price: 120000, baseSpeed: 65.0, boostSpeed: 105.0, acceleration: 35.0, braking: 90.0, laneChangeSpeed: 0.06)
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
