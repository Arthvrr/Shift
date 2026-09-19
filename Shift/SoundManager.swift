import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    var bgmPlayer: AVAudioPlayer?
    var sfxPlayers: [AVAudioPlayer] = []
    
    // On mémorise quelle musique est en train de jouer pour ne pas la relancer pour rien
    var currentBGMFilename: String = ""
    
    private init() {}
    
    // --- MUSIQUE DE FOND ---
    func playBGM(filename: String, extensionType: String = "mp3") {
        // 1. On vérifie si la musique est activée dans les réglages (Par défaut : true)
        let isMusicEnabled = UserDefaults.standard.object(forKey: "isMusicEnabled") as? Bool ?? true
        guard isMusicEnabled else { return } // Si c'est sur OFF, on annule
        
        // 2. Si la musique demandée est DÉJÀ en train de jouer, on ne fait rien !
        if bgmPlayer?.isPlaying == true && currentBGMFilename == filename {
            return
        }
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: extensionType) else {
            print("Fichier musique \(filename) introuvable.")
            return
        }
        
        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = 0.8 // Ton volume à 80%
            bgmPlayer?.play()
            currentBGMFilename = filename // On enregistre ce qu'on écoute
        } catch {
            print("Erreur de lecture BGM : \(error.localizedDescription)")
        }
    }
    
    func stopBGM() {
        bgmPlayer?.stop()
        currentBGMFilename = ""
    }
    
    // --- EFFETS SONORES (SFX) ---
    func playSFX(filename: String, extensionType: String = "mp3") {
        // 1. On vérifie si les SFX sont activés (Par défaut : true)
        let isSfxEnabled = UserDefaults.standard.object(forKey: "isSfxEnabled") as? Bool ?? true
        guard isSfxEnabled else { return } // Si c'est sur OFF, on annule
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: extensionType) else {
            print("Fichier son \(filename) introuvable.")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0 // Volume à 100%
            player.play()
            
            sfxPlayers.append(player)
            sfxPlayers.removeAll { $0.isPlaying == false }
        } catch {
            print("Erreur de lecture SFX : \(error.localizedDescription)")
        }
    }
}
