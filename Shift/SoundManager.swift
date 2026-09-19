import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    var bgmPlayer: AVAudioPlayer?
    var sfxPlayers: [AVAudioPlayer] = []
    
    private init() {}
    
    // --- MUSIQUE DE FOND ---
    func playBGM(filename: String, extensionType: String = "mp3") {
        guard let url = Bundle.main.url(forResource: filename, withExtension: extensionType) else {
            print("Fichier musique \(filename) introuvable.")
            return
        }
        
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1 // Boucle infinie
            bgmPlayer?.volume = 0.8       // VOLUME BAISSÉ (30%) pour ne pas être trop fort
            bgmPlayer?.play()
        } catch {
            print("Erreur de lecture BGM : \(error.localizedDescription)")
        }
    }
    
    func stopBGM() {
        bgmPlayer?.stop()
    }
    
    // --- EFFETS SONORES (SFX) ---
    func playSFX(filename: String, extensionType: String = "mp3") { // J'ai mis "mp3" par défaut car c'est ce que tu as importé
        guard let url = Bundle.main.url(forResource: filename, withExtension: extensionType) else {
            print("Fichier son \(filename) introuvable.")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0 // VOLUME MAX (100%)
            player.play()
            
            sfxPlayers.append(player)
            sfxPlayers.removeAll { $0.isPlaying == false }
        } catch {
            print("Erreur de lecture SFX : \(error.localizedDescription)")
        }
    }
}
