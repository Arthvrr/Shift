import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var scene = GameScene()
    @State private var isGameOver = false
    @State private var isGamePaused = false
    
    // 1. On ajoute une variable d'état pour le score
    @State private var score = 0
    
    var body: some View {
        ZStack {
            SceneView(
                scene: scene,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        if !isGameOver && !isGamePaused {
                            if value.translation.width < 0 {
                                scene.movePlayer(direction: -1)
                            } else if value.translation.width > 0 {
                                scene.movePlayer(direction: 1)
                            }
                        }
                    }
            )
            .onAppear {
                scene.onGameOver = { isGameOver = true }
                
                // 2. On écoute les mises à jour du score envoyées par la 3D !
                scene.onScoreUpdate = { newScore in
                    score = newScore
                }
            }
            
            // --- HUD (L'affichage au dessus du jeu) ---
            VStack {
                ZStack {
                    // Bouton Pause aligné à gauche
                    HStack {
                        Button(action: {
                            isGamePaused = true
                            scene.isPaused = true // Magie SceneKit : fige tout l'univers 3D !
                        }) {
                            Image(systemName: "pause.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .shadow(radius: 3)
                        }
                        Spacer()
                    }
                    
                    // Score parfaitement centré
                    Text("\(score)")
                        .font(.system(size: 45, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer() // Pousse le bloc de HUD vers le haut
            }
            
            // --- MENU GAME OVER ---
            if isGameOver {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 30) {
                    Text("GAME OVER")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                    
                    // On affiche le score final !
                    Text("KMs Reached : \(score)")
                        .font(.title).bold()
                        .foregroundColor(.white)
                    
                    Button(action: {
                        scene = GameScene()
                        scene.onGameOver = { isGameOver = true }
                        
                        // 4. IMPORTANT : On reconnecte le score pour la nouvelle partie
                        scene.onScoreUpdate = { newScore in
                            score = newScore
                        }
                        
                        // On remet le score à zéro
                        score = 0
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
            }go
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
                        Text("REPRENDRE")
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
