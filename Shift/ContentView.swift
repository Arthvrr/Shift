import SwiftUI
import SceneKit

struct ContentView: View {
    
    @State private var scene = GameScene()
    // Booléen pour savoir si on affiche l'écran de fin
    @State private var isGameOver = false
    
    var body: some View {
        ZStack {
            // La vue 3D qui prend tout l'écran
            // Remplace ta SceneView actuelle par celle-ci
            SceneView(
                scene: scene,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        // On empêche le joueur de bouger s'il a perdu
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
                // Dès que la vue apparaît, on branche le messager !
                scene.onGameOver = {
                    isGameOver = true
                }
            }
            
            if isGameOver {
                // Fond semi-transparent
                Color.black.opacity(0.7).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("GAME OVER")
                        .font(.system(size: 60, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                    
                    Button(action: {
                        // Action du bouton REJOUER : On recrée une scène neuve
                        scene = GameScene()
                        // On reconnecte le messager
                        scene.onGameOver = { isGameOver = true }
                        // On cache le menu
                        isGameOver = false
                    }) {
                        Text("REJOUER")
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
