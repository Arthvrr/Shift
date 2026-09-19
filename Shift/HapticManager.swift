import UIKit // On utilise UIKit pour accéder au moteur haptique d'Apple

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // Propriété calculée qui vérifie en direct si les réglages autorisent les vibrations
    private var isHapticsEnabled: Bool {
        return UserDefaults.standard.object(forKey: "isHapticsEnabled") as? Bool ?? true
    }
    
    // 1. NEAR MISS : Une vibration moyenne et courte (comme un souffle)
    func playNearMiss() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // 2. BOOST : Un choc sec et mécanique (comme un passage de vitesse agressif)
    func playBoost() {
        guard isHapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // 3. CRASH : Une double vibration lourde (qui signale un échec/choc)
    func playCrash() {
        guard isHapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error) // Le mode .error fait "Toum-Toum" de façon très lourde
    }
}
