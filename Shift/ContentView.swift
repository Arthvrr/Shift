import SwiftUI
import SceneKit

// --- 1. LES ÉTATS DU JEU ---
enum AppState {
    case menu
    case playing
    case garage
    case gameOver
    case settings
}

// --- 2. LE MENU PRINCIPAL ---
struct MainMenuView: View {
    @Binding var appState: AppState
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Fond interactif invisible pour lancer le jeu en cliquant n'importe où
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    // On dit juste à l'App qu'on veut jouer !
                    // ContentView se chargera du reste.
                    appState = .playing
                }
            
            VStack {
                // Les Icônes du haut
                HStack {
                    Button(action: {
                        appState = .garage
                    }) {
                        Image(systemName: "car.2.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(15)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        appState = .settings // <-- L'action est maintenant connectée !
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(15)
                            .background(Color.gray)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.top, 40)
                
                Spacer()
                
                // Titre Stylisé
                Text("SHIFT")
                    .font(.system(size: 80, weight: .black, design: .default))
                    .italic()
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 5, x: 0, y: 5)
                    .overlay(
                        Text("SHIFT")
                            .font(.system(size: 80, weight: .black, design: .default))
                            .italic()
                            .foregroundColor(.clear)
                            .shadow(color: .yellow, radius: 2, x: -2, y: -2)
                            .offset(x: 2, y: 2)
                    )
                
                Spacer()
                
                // Texte clignotant
                Text("TAP ANYWHERE TO PLAY")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(isPulsing ? 0.3 : 1.0)
                    .animation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                    .onAppear {
                        isPulsing = true
                    }
                    .padding(.bottom, 80)
            }
        }
    }
}

// --- 3. LA VUE PRINCIPALE ---
struct ContentView: View {
    
    // NOUVEAU : La scène s'instancie en PAUSE pour le menu
    @State private var scene: GameScene = {
        let s = GameScene()
        s.isPaused = true
        return s
    }()
    
    @State private var appState: AppState = .menu // Le jeu démarre sur le Menu
    @State private var isGamePaused = false
    
    @State private var hasSwiped = false
    @State private var score = 0
    
    @AppStorage("highScore") private var highScore = 0
    @State private var isNewRecord = false
    @State private var recordScale: CGFloat = 1.0
    
    @AppStorage("totalCoins") private var totalCoins = 0
    @AppStorage("speedUnit") private var speedUnit = "km/h"
    @State private var speedKmH = 90
    @State private var distance: Float = 0.0
    @State private var nearMissOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // --- LE JEU 3D (Toujours en fond) ---
            SceneView(
                scene: scene,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        // NOUVEAU : On n'accepte les gestes QUE si on est en train de jouer
                        if appState == .playing && !isGamePaused {
                            scene.setBoost(active: true)
                            
                            if !hasSwiped {
                                if value.translation.width < -5 {
                                    scene.movePlayer(direction: -1)
                                    hasSwiped = true
                                } else if value.translation.width > 5 {
                                    scene.movePlayer(direction: 1)
                                    hasSwiped = true
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if appState == .playing && !isGamePaused {
                            scene.setBoost(active: false)
                            hasSwiped = false
                        }
                    }
            )
            .onChange(of: appState) { oldValue, newValue in
                
                if newValue == .menu {
                    // On recharge le décor et la nouvelle voiture choisie !
                    scene.displayLink?.invalidate() // <-- ON TUE LE ZOMBIE !
                    scene = GameScene()
                    scene.isPaused = true
                }
                
                
                else if newValue == .playing && score == 0 && distance == 0.0 {
                    // On recrée une scène totalement neuve
                    scene.displayLink?.invalidate() // <-- ON TUE LE ZOMBIE !
                    scene = GameScene()
                    scene.isPaused = false
                    
                    // On reconnecte tous les tuyaux d'interface
                    scene.onGameOver = {
                        if score > highScore { highScore = score; isNewRecord = true }
                        appState = .gameOver
                    }
                    scene.onScoreUpdate = { newScore in score = newScore }
                    scene.onCoinCollected = { totalCoins += 1 }
                    scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                    scene.onDistanceUpdate = { newDist in distance = newDist }
                    
                    scene.onNearMiss = {
                        nearMissOpacity = 0.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeOut(duration: 0.05)) { nearMissOpacity = 1.0 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeIn(duration: 0.15)) { nearMissOpacity = 0.0 }
                            }
                        }
                    }
                }
                // Si on sort juste d'une pause (le score n'est pas à 0)
                else if newValue == .playing {
                    scene.isPaused = false
                }
            }
            .onAppear {
                scene.onGameOver = {
                    if score > highScore {
                        highScore = score
                        isNewRecord = true
                    }
                    appState = .gameOver // NOUVEAU
                }
                
                scene.onScoreUpdate = { newScore in score = newScore }
                scene.onCoinCollected = { totalCoins += 1 }
                scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                scene.onDistanceUpdate = { newDist in distance = newDist }
                
                scene.onNearMiss = {
                    withAnimation(.easeOut(duration: 0.1)) {
                        nearMissOpacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeIn(duration: 0.5)) {
                            nearMissOpacity = 0.0
                        }
                    }
                }
            }
            
            // --- LE CONTRÔLEUR D'INTERFACE ---
            switch appState {
                
            case .menu:
                MainMenuView(appState: $appState)
                
            case .playing:
                // HUD
                VStack {
                    ZStack(alignment: .top) {
                        HStack {
                            Button(action: {
                                isGamePaused = true
                                scene.isPaused = true
                            }) {
                                Image(systemName: "pause.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                            Spacer()
                        }
                        
                        Text("\(score)")
                            .font(.system(size: 45, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                        
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                let displaySpeed = speedUnit == "mph" ? Int(Double(speedKmH) * 0.621371) : speedKmH
                                
                                Text("\(displaySpeed) \(speedUnit)")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(8)
                                
                                Text(String(format: "%.2f km", distance / 1000.0))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(8)
                                
                                HStack(spacing: 5) {
                                    Text("\(totalCoins)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Image(systemName: "c.circle.fill")
                                        .foregroundColor(.yellow)
                                        .font(.title3)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                
                // NEAR MISS
                Text("🔥 NEAR MISS ! 🔥\n+10")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .shadow(color: .red, radius: 5, x: 0, y: 0)
                    .opacity(nearMissOpacity)
                    .offset(y: -50)
                
                // MENU PAUSE
                if isGamePaused {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 30) {
                        Text("PAUSE")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Button(action: {
                            isGamePaused = false
                            scene.isPaused = false
                        }) {
                            Text("RESUME")
                                .font(.title2).bold()
                                .padding(.horizontal, 40)
                                .padding(.vertical, 15)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                        Button(action: {
                            appState = .menu
                            isGamePaused = false
                            
                            // On recrée une route propre en pause
                            scene.displayLink?.invalidate() // <-- ON TUE LE ZOMBIE !
                            scene = GameScene()
                            scene.isPaused = true
                            
                            // On reconnecte l'interface
                            scene.onGameOver = {
                                if score > highScore { highScore = score; isNewRecord = true }
                                appState = .gameOver
                            }
                            scene.onScoreUpdate = { newScore in score = newScore }
                            scene.onCoinCollected = { totalCoins += 1 }
                            scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                            scene.onDistanceUpdate = { newDist in distance = newDist }
                            
                            score = 0
                            distance = 0.0
                            speedKmH = 90
                        }) {
                            Text("MAIN MENU")
                                .font(.title2).bold()
                                .padding(.horizontal, 40)
                                .padding(.vertical, 15)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                    }
                }
                
            case .garage: GarageView(appState: $appState)
                
            case .settings: SettingsView(appState:$appState)
                
            case .gameOver:
                Color.black.opacity(0.8).ignoresSafeArea()
                
                // LA BOÎTE VERTICALE COMMENCE ICI
                VStack(spacing: 25) {
                    Text("GAME OVER")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text("Score : \(score)")
                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    if isNewRecord {
                        Text("🎉 NEW RECORD ! 🎉")
                            .font(.title2).bold()
                            .foregroundColor(.yellow)
                            .scaleEffect(recordScale)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                    recordScale = 1.2
                                }
                            }
                    } else {
                        Text("Best Score : \(highScore)")
                            .font(.title3).bold()
                            .foregroundColor(.gray)
                    }
                    
                    Spacer().frame(height: 20)
                    
                    // --- BOUTON 1 : REPLAY ---
                    Button(action: {
                        scene.displayLink?.invalidate() // <-- ON TUE LE ZOMBIE !
                        scene = GameScene()
                        scene.isPaused = false
                        
                        scene.onGameOver = {
                            if score > highScore { highScore = score; isNewRecord = true }
                            appState = .gameOver
                        }
                        
                        scene.onScoreUpdate = { newScore in score = newScore }
                        scene.onCoinCollected = { totalCoins += 1 }
                        scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                        scene.onDistanceUpdate = { newDist in distance = newDist }
                        
                        scene.onNearMiss = {
                            nearMissOpacity = 0.0
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeOut(duration: 0.05)) { nearMissOpacity = 1.0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    withAnimation(.easeIn(duration: 0.15)) { nearMissOpacity = 0.0 }
                                }
                            }
                        }
                        
                        score = 0
                        distance = 0.0
                        speedKmH = 90
                        isNewRecord = false
                        recordScale = 1.0
                        nearMissOpacity = 0.0
                        
                        appState = .playing
                    }) {
                        Text("REPLAY")
                            .font(.title2).bold()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(15)
                    }
                    
                    // --- BOUTON 2 : MAIN MENU (Maintenant bien à l'intérieur de la VStack !) ---
                    Button(action: {
                        appState = .menu
                        
                        scene.displayLink?.invalidate() // <-- ON TUE LE ZOMBIE !
                        scene = GameScene()
                        scene.isPaused = true
                        
                        scene.onGameOver = {
                            if score > highScore { highScore = score; isNewRecord = true }
                            appState = .gameOver
                        }
                        scene.onScoreUpdate = { newScore in score = newScore }
                        scene.onCoinCollected = { totalCoins += 1 }
                        scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                        scene.onDistanceUpdate = { newDist in distance = newDist }
                        
                        score = 0
                        distance = 0.0
                        speedKmH = 90
                        isNewRecord = false
                        recordScale = 1.0
                    }) {
                        Text("MAIN MENU")
                            .font(.title2).bold()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
                
            }
            
        }
    }
}
