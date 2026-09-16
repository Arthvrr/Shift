import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var scene = GameScene()
    @State private var isGameOver = false
    @State private var isGamePaused = false
    
    @State private var hasSwiped = false
    
    @State private var score = 0
    
    @AppStorage("highScore") private var highScore = 0
    @State private var isNewRecord = false
    @State private var recordScale: CGFloat = 1.0
    
    @AppStorage("totalCoins") private var totalCoins = 0 // Sauvegarde magique sur l'iPhone !
    @State private var speedKmH = 90 // Vitesse de base affichée
    
    @State private var distance: Float = 0.0
    
    var body: some View {
        ZStack {
            SceneView(
                scene: scene,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if !isGameOver && !isGamePaused {
                            // 1. BOOM ! On active le Boost dès que le doigt est là
                            scene.setBoost(active: true)
                            
                            // 2. On swipe si le joueur fait un mouvement fort
                            if !hasSwiped {
                                if value.translation.width < -10 {
                                    scene.movePlayer(direction: -1)
                                    hasSwiped = true
                                } else if value.translation.width > 10 {
                                    scene.movePlayer(direction: 1)
                                    hasSwiped = true
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if !isGameOver && !isGamePaused {
                            // 3. On relâche, vitesse normale et on réarme le swipe
                            scene.setBoost(active: false)
                            hasSwiped = false
                        }
                    }
            )
            .onAppear {
                scene.onGameOver = {
                    if score > highScore {
                        highScore = score
                        isNewRecord = true
                    }
                    isGameOver = true
                }
                
                scene.onScoreUpdate = { newScore in score = newScore }
                scene.onCoinCollected = { totalCoins += 1 }
                scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                scene.onDistanceUpdate = { newDist in distance = newDist } // Connexion !
            }
            
            // --- HUD (L'affichage au dessus du jeu) ---
            VStack {
                ZStack(alignment: .top) {
                    // Bouton Pause à gauche
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
                    
                    // Score au centre
                    Text("\(score)")
                        .font(.system(size: 45, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    
                    // --- Vitesse, Distance et Pièces à droite ---
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 5) {
                            Text("\(speedKmH) km/h")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                            
                            // NOUVEAU : Affichage de la distance en km (ex: "1.24 km")
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
                
                Spacer() // Pousse le bloc de HUD vers le haut
            }
            
            // --- MENU GAME OVER ---
            if isGameOver {
                Color.black.opacity(0.8).ignoresSafeArea() // Un peu plus sombre pour faire ressortir les couleurs
                
                VStack(spacing: 25) {
                    Text("GAME OVER")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                        .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    // Score de la partie
                    Text("Score : \(score)")
                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    // --- AFFICHAGE DU RECORD ---
                    if isNewRecord {
                        Text("🎉 NEW RECORD ! 🎉")
                            .font(.title2).bold()
                            .foregroundColor(.yellow)
                            .scaleEffect(recordScale) // Utilise notre variable d'animation
                            .onAppear {
                                // Animation : grossir et rétrécir à l'infini
                                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                    recordScale = 1.2
                                }
                            }
                    } else {
                        // S'il n'a pas battu le record, on lui rappelle son meilleur score
                        Text("Best Score : \(highScore)")
                            .font(.title3).bold()
                            .foregroundColor(.gray)
                    }
                    
                    Spacer().frame(height: 20)
                    
                    Button(action: {
                        scene = GameScene()
                        scene.onGameOver = {
                            if score > highScore {
                                highScore = score
                                isNewRecord = true
                            }
                            isGameOver = true
                        }
                        
                        scene.onScoreUpdate = { newScore in score = newScore }
                        
                        // LES VOICI ! On reconnecte tout à la nouvelle scène
                        scene.onCoinCollected = { totalCoins += 1 }
                        scene.onSpeedUpdate = { newSpeed in speedKmH = newSpeed }
                        scene.onDistanceUpdate = { newDist in distance = newDist }
                        
                        // On remet l'interface à zéro pour la nouvelle partie
                        score = 0
                        distance = 0.0
                        speedKmH = 90
                        isNewRecord = false
                        recordScale = 1.0
                        isGameOver = false
                    }) {
                        Text("REPLAY")
                            .font(.title2).bold()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(15)
                    }
                }
            }
            // --- MENU PAUSE ---
            if isGamePaused && !isGameOver {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 30) {
                    Text("PAUSE")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Button(action: {
                        isGamePaused = false
                        scene.isPaused = false // Relance le moteur 3D exactement où il s'était arrêté
                    }) {
                        Text("RESUME")
                            .font(.title2).bold()
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
            }
        }
    }
}
