import SwiftUI
import SceneKit

struct GarageView: View {
    @Binding var appState: AppState
    
    // Variables sauvegardées
    @AppStorage("totalCoins") private var totalCoins = 0
    @AppStorage("selectedCarId") private var selectedCarId = 1
    
    // Navigation dans le catalogue
    @State private var currentIndex = 0
    
    var currentCar: PlayerCar {
        carCatalog[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.darkGray).ignoresSafeArea() // Fond du garage
            
            VStack {
                // --- EN-TÊTE ---
                HStack {
                    Button(action: { appState = .menu }) {
                        Image(systemName: "chevron.left")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("GARAGE").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundColor(.white)
                    Spacer()
                    HStack {
                        Text("\(totalCoins)")
                            .font(.title2).bold().foregroundColor(.white)
                        Image(systemName: "c.circle.fill").foregroundColor(.yellow)
                    }
                    .padding().background(Color.black.opacity(0.5)).cornerRadius(15)
                }
                .padding()
                
                // --- VISUALISEUR 3D INTERACTIF ---
                SceneView(
                    scene: makeGarageScene(for: currentCar.modelName),
                    options: [.autoenablesDefaultLighting, .allowsCameraControl] // <-- Déplacé ici !
                )
                .frame(height: 300)
                
                // --- SÉLECTEUR GAUCHE/DROITE ---
                HStack {
                    Button(action: { if currentIndex > 0 { currentIndex -= 1 } }) {
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.largeTitle).foregroundColor(currentIndex > 0 ? .white : .gray)
                    }
                    Spacer()
                    Text(currentCar.name)
                        .font(.system(size: 35, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { if currentIndex < carCatalog.count - 1 { currentIndex += 1 } }) {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.largeTitle).foregroundColor(currentIndex < carCatalog.count - 1 ? .white : .gray)
                    }
                }
                .padding(.horizontal, 40)
                
                // --- STATISTIQUES (JAUGES) ---
                VStack(spacing: 15) {
                    StatBar(title: "Vitesse", value: currentCar.baseSpeed, max: 70.0, color: .blue)
                    StatBar(title: "Boost", value: currentCar.boostSpeed, max: 110.0, color: .orange)
                    StatBar(title: "Maniabilité", value: Float(0.20 - currentCar.laneChangeSpeed), max: 0.15, color: .green)
                }
                .padding(.horizontal, 30)
                .padding(.top, 20)
                
                Spacer()
                
                // --- BOUTON D'ACHAT / SÉLECTION ---
                if GarageManager.isUnlocked(id: currentCar.id) {
                    if selectedCarId == currentCar.id {
                        Text("SÉLECTIONNÉE")
                            .font(.title2).bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                            .padding(.horizontal, 30)
                    } else {
                        Button(action: { selectedCarId = currentCar.id }) {
                            Text("CHOISIR")
                                .font(.title2).bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .padding(.horizontal, 30)
                        }
                    }
                } else {
                    Button(action: {
                        if totalCoins >= currentCar.price {
                            totalCoins -= currentCar.price
                            GarageManager.unlock(id: currentCar.id)
                            selectedCarId = currentCar.id
                        }
                    }) {
                        HStack {
                            Text("ACHETER - \(currentCar.price)")
                            Image(systemName: "c.circle.fill")
                        }
                        .font(.title2).bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(totalCoins >= currentCar.price ? Color.yellow : Color.gray)
                        .foregroundColor(totalCoins >= currentCar.price ? .black : .white)
                        .cornerRadius(15)
                        .padding(.horizontal, 30)
                    }
                    .disabled(totalCoins < currentCar.price)
                }
                
                Spacer()
            }
        }
    }
    
    // Fonction qui génère une scène 3D propre juste pour afficher la voiture
    func makeGarageScene(for modelName: String) -> SCNScene {
        let scene = SCNScene()
        
        // 1. Fond transparent pour laisser passer le gris de SwiftUI
        scene.background.contents = UIColor.clear
        
        // 2. On ajoute explicitement une caméra (Essentiel pour allowsCameraControl !)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 1, 5) // On recule pour bien voir la voiture
        scene.rootNode.addChildNode(cameraNode)
        
        // 3. On charge la voiture
        if let carScene = SCNScene(named: "art.scnassets/\(modelName).usdz"),
           let carModel = carScene.rootNode.childNodes.first {
            
            carModel.scale = SCNVector3(x: 0.015, y: 0.015, z: 0.015)
            carModel.position = SCNVector3(0, -0.5, 0)
            carModel.eulerAngles = SCNVector3(x: 0.2, y: -Float.pi / 6, z: 0)
            
            scene.rootNode.addChildNode(carModel)
        }
        
        return scene
    }
}

// Petit composant UI pour les jauges
struct StatBar: View {
    var title: String
    var value: Float
    var max: Float
    var color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline).bold()
                .foregroundColor(.white)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().frame(height: 12).foregroundColor(Color.gray.opacity(0.5))
                    Capsule()
                        .frame(width: geometry.size.width * CGFloat(value / max), height: 12)
                        .foregroundColor(color)
                }
            }
            .frame(height: 12)
        }
    }
}
