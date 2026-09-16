import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var scene = GameScene()
    @State private var isGameOver = false
    
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
                        if !isGameOver {
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
                // 3. Le texte du score, centré et stylisé
                Text("\(score)")
                    .font(.system(size: 45, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    // Une petite ombre pour qu'il reste lisible même sur fond clair
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 2)
                    .padding(.top, 60) // Décale un peu sous la Dynamic Island/Encoche
                
                Spacer() // Pousse le score tout en haut
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
            }
        }
    }
}
