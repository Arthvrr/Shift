import SceneKit

enum TrafficCondition {
    case clear       // Autoroute dégagée
    case normal      // Trafic habituel
    case heavy       // Embouteillage (très dense !)
}

struct CollisionCategory {
    static let player = 1 << 0
    static let obstacle = 1 << 1
    static let coin = 1 << 2
}

class ObstacleNode: SCNNode {
    var drivingSpeed: Float = 0.0
    var currentLaneIndex: Int = 0        // Sur quelle bande je suis
    var hasDecidedToTurn: Bool = false   // Est-ce que j'ai déjà checké pour tourner ?
    var targetX: Float? = nil            // L'objectif X si je tourne
    var hasScoredNearMiss: Bool = false
}

class GameScene: SCNScene {
    
    var onGameOver: (() -> Void)?
    var onScoreUpdate: ((Int) -> Void)?
    var score: Int = 0
    
    var playerNode: SCNNode!
    let lanes: [Float] = [-0.9, -0.3, 0.3, 0.9]
    var currentLaneIndex = 1
    
    // --- LE NOUVEAU MOTEUR DU JEU ---
    var displayLink: CADisplayLink?
    var gameSpeed: Float = 40.0    // Vitesse actuelle (en temps réel)
    var targetSpeed: Float = 40.0  // Vitesse que l'on cherche à atteindre (30 ou 60)
    var accelerationRate: Float = 10.0
    var decelerationRate : Float = 45.0
    var distanceTraveled: Float = 0
    
    // Les compteurs kilométriques pour faire apparaître de nouveaux objets
    var nextLineDistance: Float = 0
    var nextObstacleDistance: Float = 30.0
    var nextCloudDistance: Float = 0.0
    var nextScoreDistance: Float = 3.0 // +1 point tous les 3 mètres
    
    var currentTraffic: TrafficCondition = .normal
    var carsLeftInWave: Int = 10
    
    var onCoinCollected: (() -> Void)?     // Signal envoyé quand on ramasse une pièce
    var onSpeedUpdate: ((Int) -> Void)?    // Signal envoyé pour afficher les km/h
    var lastReportedSpeed: Int = 0
    
    var onDistanceUpdate: ((Float) -> Void)?
    var lastReportedDistance: Float = 0.0

    var nextCoinDistance: Float = 100.0     // Kilométrage de la prochaine pièce
    
    //var onNearMiss: (() -> Void)?
    
    var lastLaneChangeTime: TimeInterval = 0.0
    
    var carTemplates: [SCNNode] = []
    
    var isCrashed: Bool = false
    
    var carStats: PlayerCar!
    
    var isBoosting: Bool = false
    
    // --- VARIABLES DE COMBO NEAR MISS ---
    var nearMissCombo: Int = 0
    var lastNearMissTime: TimeInterval = 0.0
    let comboTimeout: TimeInterval = 4.0 // 4 secondes pour enchaîner
    var onNearMiss: ((Int, Int) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
        setupPlayer()
        setupEnvironment()
        prefillLineDashes()
        preloadObstacles()
        
        self.physicsWorld.contactDelegate = self
        
        // On lance le métronome du jeu à 60 images par seconde !
        displayLink = CADisplayLink(target: self, selector: #selector(gameLoop(displayLink:)))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        
        cameraNode.camera?.zFar = 500.0
        
        cameraNode.position = SCNVector3(x: 0, y: 3, z: 5)
        cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 8, y: 0, z: 0)
        self.rootNode.addChildNode(cameraNode)
    }
    
    func setupPlayer() {
        // 1. Lire la voiture choisie dans le Garage
        let savedId = UserDefaults.standard.integer(forKey: "selectedCarId")
        let carId = savedId == 0 ? 1 : savedId // Sécurité : on charge la 1 par défaut
        
        // 2. Récupérer ses caractéristiques depuis ton catalogue
        self.carStats = carCatalog.first(where: { $0.id == carId }) ?? carCatalog[0]
        
        // 3. Initialiser les vitesses de départ avec les stats de la voiture !
        self.gameSpeed = carStats.baseSpeed
        self.targetSpeed = carStats.baseSpeed
        
        // 4. Charger le bon fichier 3D dynamique (au lieu de "voiture1" en dur)
        if let carScene = SCNScene(named: "art.scnassets/\(carStats.modelName).usdz"),
           let carModel = carScene.rootNode.childNodes.first {
            
            // ... GARDE TON CODE ACTUEL ICI POUR L'ÉCHELLE, LA ROTATION, ET LE PHYSICSBODY ...
            
            playerNode = carModel
            
            // 2. RÉGLAGE DE L'ÉCHELLE
            // On divise la taille par 2 par rapport à ton image
            playerNode.scale = SCNVector3(x: 0.0025, y: 0.0025, z: 0.0025)
            
            // 3. ORIENTATION
            // On décommente cette ligne pour faire pivoter la voiture de 180° sur l'axe Y
            playerNode.eulerAngles = SCNVector3(x: 0, y: Float.pi, z: 0)
            
            // 4. POSITION
            playerNode.position = SCNVector3(x: lanes[currentLaneIndex], y: 0.0, z: 2)
            
            // 5. HITBOX (On garde la détection physique parfaite de l'ancien cube)
            let hitboxGeo = SCNBox(width: 0.4, height: 1, length: 0.8, chamferRadius: 0)
            let physicsShape = SCNPhysicsShape(geometry: hitboxGeo, options: nil)
            
            playerNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
            playerNode.physicsBody?.categoryBitMask = CollisionCategory.player
            playerNode.physicsBody?.contactTestBitMask = CollisionCategory.obstacle | CollisionCategory.coin
            
            self.rootNode.addChildNode(playerNode)
        }
    }
    
    func movePlayer(direction: Int) {
        let newIndex = currentLaneIndex + direction
        if newIndex >= 0 && newIndex < lanes.count {
            currentLaneIndex = newIndex
            
            // --- NOUVEAU : On enregistre le moment exact du coup de volant ---
            lastLaneChangeTime = CACurrentMediaTime()
            
            let targetPosition = SCNVector3(x: lanes[currentLaneIndex], y: playerNode.position.y, z: playerNode.position.z)
            // On utilise directement targetPosition au lieu de recréer un vecteur avec "newX" :
            let moveAction = SCNAction.move(to: targetPosition, duration: carStats.laneChangeSpeed)
            moveAction.timingMode = .easeOut
            playerNode.runAction(moveAction)
        }
    }
    
    func setBoost(active: Bool) {
        if active {
            targetSpeed = carStats.boostSpeed
            accelerationRate = carStats.acceleration
            
            // On déclenche le "coup de pied" haptique uniquement au moment où on touche l'écran
            if !isBoosting {
                isBoosting = true
                HapticManager.shared.playBoost() // <-- NOUVEAU (Le petit choc sec)
            }
        } else {
            targetSpeed = carStats.baseSpeed
            decelerationRate = carStats.braking
            isBoosting = false
        }
    }
    
    func setupEnvironment() {
        // 1. Le ciel (Tu peux changer la couleur selon l'ambiance que tu veux)
        self.background.contents = UIColor.systemTeal
        
        // 2. Le soleil (On le recule à Z = -450 pour qu'il soit derrière la ville !)
        let sunGeo = SCNSphere(radius: 15.0)
        sunGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        sunGeo.firstMaterial?.emission.contents = UIColor.systemYellow
        let sunNode = SCNNode(geometry: sunGeo)
        sunNode.position = SCNVector3(x: 30, y: 40, z: -450)
        self.rootNode.addChildNode(sunNode)
        
        // --- 3. NOUVEAU : LE DÉCOR "HORIZON CHASE" ---
        // On crée un écran géant de 400m de large sur 100m de haut
        let horizonGeo = SCNPlane(width: 400.0, height: 100.0)
        
        // On lui applique ton image PNG
        if let bgImage = UIImage(named: "horizon") {
            horizonGeo.firstMaterial?.diffuse.contents = bgImage
        } else {
            // Si Xcode ne trouve pas l'image, il affichera un mur gris pour tester
            horizonGeo.firstMaterial?.diffuse.contents = UIColor.darkGray
        }
        
        let horizonNode = SCNNode(geometry: horizonGeo)
        
        // On le place très loin (Z = -400) pour respecter la limite de vision de ta caméra (Z = 500)
        // La valeur Y = 30 surélève la ville pour qu'elle se pose sur la ligne d'horizon
        horizonNode.position = SCNVector3(x: 0, y: 30, z: -400)
        
        // Petite astuce : on l'incline très légèrement vers l'arrière pour qu'il soit
        // bien perpendiculaire au regard de notre caméra qui penche vers le bas
        horizonNode.eulerAngles = SCNVector3(x: -Float.pi / 16, y: 0, z: 0)
        
        self.rootNode.addChildNode(horizonNode)
        // ---------------------------------------------
        
        // 4. Le sol infini
        let floorGeometry = SCNFloor()
        // Tu peux changer la couleur ici si tu veux faire un désert ou de la neige !
        floorGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen
        floorGeometry.reflectivity = 0.0
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.position = SCNVector3(x: 0, y: 0, z: 0)
        self.rootNode.addChildNode(floorNode)
        
        // 5. La route en asphalte
        let roadGeo = SCNBox(width: 2.4, height: 0.005, length: 200.0, chamferRadius: 0)
        roadGeo.firstMaterial?.diffuse.contents = UIColor.darkGray
        let roadNode = SCNNode(geometry: roadGeo)
        roadNode.position = SCNVector3(x: 0, y: 0.005, z: -45)
        self.rootNode.addChildNode(roadNode)
        
        // 6. Les lignes blanches sur le bord de route
        let edgeXPositions: [Float] = [-1.2, 1.2]
        for x in edgeXPositions {
            let edgeLineGeo = SCNBox(width: 0.05, height: 0.01, length: 100.0, chamferRadius: 0)
            edgeLineGeo.firstMaterial?.diffuse.contents = UIColor.white
            let edgeLineNode = SCNNode(geometry: edgeLineGeo)
            edgeLineNode.position = SCNVector3(x: x, y: 0.01, z: -45)
            self.rootNode.addChildNode(edgeLineNode)
        }
    }
    
    func preloadObstacles() {
        // NOUVEAU DICTIONNAIRE : Il contient maintenant (Rotation, Échelle) !
        // J'ai passé l'échelle de 0.0025 à 0.006 pour grossir les obstacles.
        let carConfigs: [String: (rotation: Float, scale: Float)] = [
            "car1":  (Float.pi / 2, 0.005),
            "car2":  (Float.pi / 2, 0.005),
            "car3":  (Float.pi / 2, 0.005),
            "car4":  (Float.pi / 2, 0.005),
            "car5":  (Float.pi / 2, 0.005),
            "car6":  (Float.pi, 0.0035),
            "car7":  (Float.pi, 0.0035),
            "car8":  (Float.pi, 0.0035),
            "car9":  (Float.pi, 0.0035),
            "car10": (Float.pi, 0.003),
            "car11":  (Float.pi / 2, 0.0035),
            "car12":  (Float.pi / 2, 0.005),
            "car13": (Float.pi, 0.0015),
            "car14": (Float.pi, 0.0015),
            "car15": (Float.pi, 0.008)
        ]
        
        for (fileName, config) in carConfigs {
            if let scene = SCNScene(named: "art.scnassets/\(fileName).usdz"),
               let carModel = scene.rootNode.childNodes.first {
                
                // On applique la taille SUR-MESURE pour cette voiture
                carModel.scale = SCNVector3(x: config.scale, y: config.scale, z: config.scale)
                
                // On applique la rotation SUR-MESURE pour cette voiture
                carModel.eulerAngles = SCNVector3(x: 0, y: config.rotation, z: 0)
                
                carTemplates.append(carModel)
            }
        }
    }
    
    func spawnObstacle() {
        
        // --- 0. SÉCURITÉ ANTI-MUR (Toujours laisser une issue) ---
        var occupiedLanes = Set<Int>()
        
        for node in self.rootNode.childNodes {
            if let obstacle = node as? ObstacleNode {
                // On scanne les voitures récemment apparues (entre -50m et -35m)
                if obstacle.position.z < -35.0 {
                    occupiedLanes.insert(obstacle.currentLaneIndex)
                }
            }
        }
        
        // Si 3 bandes (ou plus) sont déjà bloquées dans ce périmètre,
        // on annule cette apparition pour laisser une porte de sortie au joueur !
        if occupiedLanes.count >= 3 {
            return
        }
        
        // --- 1. CHOIX DE LA BANDE ---
        let randomLaneIndex = Int.random(in: 0..<lanes.count)
        let randomLaneX = lanes[randomLaneIndex]
        
        // --- 2. SÉCURITÉ ANTI-COLLISION AU DÉPART ---
        var lastCarInLane: ObstacleNode? = nil
        var minZ: Float = 100.0
        
        for node in self.rootNode.childNodes {
            // On vérifie avec l'index de bande pour détecter même les voitures en train de tourner !
            if let obstacle = node as? ObstacleNode, obstacle.currentLaneIndex == randomLaneIndex {
                if obstacle.position.z < minZ {
                    minZ = obstacle.position.z
                    lastCarInLane = obstacle
                }
            }
        }
        
        var newSpeed = Float.random(in: 5.0...30.0)
        if let carAhead = lastCarInLane {
            if newSpeed < carAhead.drivingSpeed {
                newSpeed = carAhead.drivingSpeed
            }
        }
        
        // --- 3. CRÉATION DE L'OBSTACLE ---
        let obstacleNode = ObstacleNode()
        obstacleNode.drivingSpeed = newSpeed
        obstacleNode.currentLaneIndex = randomLaneIndex
        
        // On pioche une voiture au hasard dans notre mémoire et on la clone (.clone()) !
        if !carTemplates.isEmpty, let randomTemplate = carTemplates.randomElement() {
            let clonedCar = randomTemplate.clone()
            obstacleNode.addChildNode(clonedCar)
        }
        
        // --- 4. PHYSIQUE ET HITBOX ---
        // TRÈS IMPORTANT : On crée une boîte invisible très simple pour les collisions.
        // Si on laissait le moteur calculer la hitbox sur le modèle 3D complexe, le jeu laggerait.
        let hitboxGeo = SCNBox(width: 0.4, height: 0.4, length: 0.8, chamferRadius: 0)
        let physicsShape = SCNPhysicsShape(geometry: hitboxGeo, options: nil)
        
        obstacleNode.position = SCNVector3(x: randomLaneX, y: 0.2, z: -50)
        obstacleNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
        obstacleNode.physicsBody?.categoryBitMask = CollisionCategory.obstacle
        obstacleNode.name = "obstacle"
        
        self.rootNode.addChildNode(obstacleNode)
    }
    
    func spawnLineDashes() {
        let lineXPositions: [Float] = [-0.6, 0.0, 0.6]
        for x in lineXPositions {
            let lineGeo = SCNBox(width: 0.05, height: 0.01, length: 1.0, chamferRadius: 0)
            lineGeo.firstMaterial?.diffuse.contents = UIColor.white
            let lineNode = SCNNode(geometry: lineGeo)
            lineNode.position = SCNVector3(x: x, y: 0.01, z: -50)
            
            lineNode.name = "line"
            self.rootNode.addChildNode(lineNode)
        }
    }
    
    func prefillLineDashes() {
        let lineXPositions: [Float] = [-0.6, 0.0, 0.6]
        for startZ in stride(from: -2.0, through: -50.0, by: -6.0) {
            for x in lineXPositions {
                let lineGeo = SCNBox(width: 0.05, height: 0.01, length: 1.0, chamferRadius: 0)
                lineGeo.firstMaterial?.diffuse.contents = UIColor.white
                let lineNode = SCNNode(geometry: lineGeo)
                lineNode.position = SCNVector3(x: x, y: 0.01, z: Float(startZ))
                
                lineNode.name = "line"
                self.rootNode.addChildNode(lineNode)
            }
        }
    }
    
    func spawnCloud() {
        let cloudGeo = SCNCapsule(capRadius: 1.5, height: 6.0)
        cloudGeo.firstMaterial?.diffuse.contents = UIColor.white
        let cloudNode = SCNNode(geometry: cloudGeo)
        cloudNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 2)
        let randomX = Float.random(in: -20...20)
        let randomY = Float.random(in: 5...12)
        cloudNode.position = SCNVector3(x: randomX, y: randomY, z: -100)
        
        cloudNode.name = "cloud"
        self.rootNode.addChildNode(cloudNode)
    }
    
    
    func spawnCoin() {
        guard let randomLane = lanes.randomElement() else { return }
        
        // On crée un cylindre fin (une pièce)
        let coinGeo = SCNCylinder(radius: 0.2, height: 0.05)
        coinGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        coinGeo.firstMaterial?.emission.contents = UIColor.systemYellow // Pour qu'elle brille
        
        let coinNode = SCNNode(geometry: coinGeo)
        // On la couche sur la route et on la surélève un peu
        coinNode.position = SCNVector3(x: randomLane, y: 0.3, z: -50)
        
        coinNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        coinNode.physicsBody?.categoryBitMask = CollisionCategory.coin
        coinNode.name = "coin" // Très important pour la reconnaître !
        
        // On la fait tourner indéfiniment sur elle-même pour attirer l'œil
        let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 1.0)
        coinNode.runAction(SCNAction.repeatForever(spin))
        
        self.rootNode.addChildNode(coinNode)
    }
    
    // ==========================================
    // LA BOUCLE DE RENDU (S'exécute à chaque frame)
    // ==========================================
    @objc func gameLoop(displayLink: CADisplayLink) {
        if isPaused { return }
        
        // 1. Calcul du déplacement selon la vitesse de croisière actuelle
        let deltaTime = Float(displayLink.targetTimestamp - displayLink.timestamp)
        
        if gameSpeed < targetSpeed {
            gameSpeed += accelerationRate * deltaTime
            // Sécurité : on ne dépasse pas la cible
            if gameSpeed > targetSpeed { gameSpeed = targetSpeed }
        } else if gameSpeed > targetSpeed {
            gameSpeed -= decelerationRate * deltaTime
            // Sécurité : on ne freine pas plus bas que la cible
            if gameSpeed < targetSpeed { gameSpeed = targetSpeed }
        }
        
        
        let distance = gameSpeed * deltaTime
        distanceTraveled += distance
        
        // 2. Déplacer physiquement tous les objets du décor vers nous
        for node in self.rootNode.childNodes {
            
            // --- NOUVEAU : Si le nœud est une voiture ennemie ---
            if let obstacle = node as? ObstacleNode {
                // 1. Déplacement vers l'avant (Vitesse relative)
                let relativeSpeed = gameSpeed - obstacle.drivingSpeed
                obstacle.position.z += relativeSpeed * deltaTime
                
                // --- 2. IA AVANCÉE : RADAR ET COMPORTEMENT ---
                                
                // A. Le Radar : On scanne ce qui se passe devant notre voiture
                var carAhead: ObstacleNode? = nil
                var distanceToCarAhead: Float = 100.0
                
                for otherNode in self.rootNode.childNodes {
                    if let otherCar = otherNode as? ObstacleNode, otherCar != obstacle {
                        if otherCar.currentLaneIndex == obstacle.currentLaneIndex {
                            // Si otherCar est devant nous (Z plus proche de 0)
                            let dist = otherCar.position.z - obstacle.position.z
                            if dist > 0 && dist < distanceToCarAhead {
                                distanceToCarAhead = dist
                                carAhead = otherCar
                            }
                        }
                    }
                }
                
                // B. L'Anti-Collision (Freinage)
                if let ahead = carAhead, distanceToCarAhead < 25.0 {
                    // Rappel de ta logique : drivingSpeed élevé = voiture lente.
                    // Donc si notre voiture est plus rapide (drivingSpeed < ahead.drivingSpeed), on freine !
                    if obstacle.drivingSpeed < ahead.drivingSpeed {
                        obstacle.drivingSpeed += 15.0 * deltaTime // On ralentit progressivement
                    }
                }
                
                // C. Décision de changement de voie (Dépassement)
                if obstacle.position.z > -40.0 && !obstacle.hasDecidedToTurn {
                    obstacle.hasDecidedToTurn = true // Décision prise une seule fois
                    
                    // La magie est ici :
                    // - Route dégagée = 15% de chance de tourner (flânerie)
                    // - Bloqué par une voiture à moins de 35m = 85% de chance de forcer le passage !
                    var chanceToTurn = 15
                    if let _ = carAhead, distanceToCarAhead < 35.0 {
                        chanceToTurn = 85
                    }
                    
                    if Int.random(in: 1...100) <= chanceToTurn {
                        var possibleDirections: [Int] = []
                        if obstacle.currentLaneIndex > 0 { possibleDirections.append(-1) }
                        if obstacle.currentLaneIndex < lanes.count - 1 { possibleDirections.append(1) }
                        
                        if let dir = possibleDirections.randomElement() {
                            let targetIndex = obstacle.currentLaneIndex + dir
                            
                            // SÉCURITÉ : Vérifier si la bande cible est libre (Ton super code anti-ghosting)
                            var isSafe = true
                            for otherNode in self.rootNode.childNodes {
                                if let otherCar = otherNode as? ObstacleNode, otherCar != obstacle {
                                    if otherCar.currentLaneIndex == targetIndex {
                                        let distanceDiff = otherCar.position.z - obstacle.position.z
                                        
                                        if abs(distanceDiff) < 22.0 { isSafe = false; break }
                                        if distanceDiff < 0 && otherCar.drivingSpeed < obstacle.drivingSpeed { isSafe = false; break }
                                        if distanceDiff > 0 && otherCar.drivingSpeed > obstacle.drivingSpeed { isSafe = false; break }
                                    }
                                }
                            }
                            
                            if isSafe {
                                obstacle.currentLaneIndex = targetIndex
                                obstacle.targetX = lanes[targetIndex]
                            }
                        }
                    }
                }
                
                // 3. Déportement latéral fluide (si un changement de bande est en cours)
                if let targetX = obstacle.targetX {
                    let slideSpeed: Float = 1.5 * deltaTime // Vitesse du coup de volant
                    if obstacle.position.x < targetX {
                        obstacle.position.x += slideSpeed
                        if obstacle.position.x >= targetX { obstacle.position.x = targetX; obstacle.targetX = nil }
                    } else if obstacle.position.x > targetX {
                        obstacle.position.x -= slideSpeed
                        if obstacle.position.x <= targetX { obstacle.position.x = targetX; obstacle.targetX = nil }
                    }
                }
                
                // --- 4. DÉTECTION DU NEAR MISS (AVEC COMBO) ---
                let dz = abs(obstacle.position.z - playerNode.position.z)
                let dx = abs(obstacle.position.x - playerNode.position.x)
                let currentTime = CACurrentMediaTime()
                let isDodging = (currentTime - lastLaneChangeTime) < 0.15
                
                if dz < 0.7 && dx > 0.45 && dx < 0.75 && !obstacle.hasScoredNearMiss && isDodging {
                    obstacle.hasScoredNearMiss = true
                    
                    // 1. GESTION DU TIMEOUT DU COMBO
                    if currentTime - lastNearMissTime > comboTimeout {
                        nearMissCombo = 0 // On réinitialise si on a été trop lent
                    }
                    
                    // 2. INCRÉMENTATION DU COMBO
                    nearMissCombo += 1
                    lastNearMissTime = currentTime
                    
                    // 3. CALCUL DES POINTS (La base + le multiplicateur)
                    let baseBonus = (targetSpeed > 40.0) ? 20 : 10
                    let totalBonus = baseBonus * nearMissCombo
                    
                    score += totalBonus
                    
                    DispatchQueue.main.async {
                        self.onScoreUpdate?(self.score)
                        // On envoie le numéro du combo et les points gagnés à l'interface !
                        self.onNearMiss?(self.nearMissCombo, totalBonus)
                    }
                }
                
                if obstacle.position.z > 10 { obstacle.removeFromParentNode() }
                
            
            } else if node.name == "coin" {
                // Les pièces sont posées sur la route, elles se rapprochent à la vitesse du jeu
                node.position.z += distance
                if node.position.z > 10 { node.removeFromParentNode() }
                
            } else if node.name == "line" {
                // La route, elle, défile toujours à la vitesse max (gameSpeed)
                node.position.z += distance
                if node.position.z > 10 { node.removeFromParentNode() }
                
            } else if node.name == "cloud" {
                node.position.z += distance * 0.2
                if node.position.z > 10 { node.removeFromParentNode() }
            }
        }
        
        // 3. Apparition des éléments basée sur les kilomètres
        if distanceTraveled >= nextLineDistance {
            spawnLineDashes()
            nextLineDistance += 6.0
        }
        
        // --- LE NOUVEAU GÉNÉRATEUR DE TRAFIC ---
        if distanceTraveled >= nextObstacleDistance {
            spawnObstacle()
            
            // 1. On décrémente la vague actuelle
            carsLeftInWave -= 1
            
            // 2. Si la vague est finie, on tire au sort le prochain état du trafic
            if carsLeftInWave <= 0 {
                let randomVal = Int.random(in: 1...100)
                
                if randomVal <= 15 {
                    currentTraffic = .clear // 15% de chance d'avoir une route vide pour souffler
                    carsLeftInWave = Int.random(in: 5...10)
                } else if randomVal <= 50 {
                    currentTraffic = .normal // 35% de chance de trafic normal
                    carsLeftInWave = Int.random(in: 15...25)
                } else {
                    currentTraffic = .heavy // 50% de chance d'embouteillage !
                    carsLeftInWave = Int.random(in: 30...50)
                }
            }
            
            // 3. On définit la distance jusqu'à la PROCHAINE voiture selon l'état actuel
            switch currentTraffic {
            case .clear:
                nextObstacleDistance += Float.random(in: 50.0...90.0) // Loin
            case .normal:
                nextObstacleDistance += Float.random(in: 20.0...35.0) // Moyen
            case .heavy:
                // Embouteillage : Les voitures s'enchaînent tous les 6 à 12 mètres !
                nextObstacleDistance += Float.random(in: 6.0...12.0)
            }
        }
        
        // --- NOUVEAU : Apparition des pièces ---
        if distanceTraveled >= nextCoinDistance {
            spawnCoin()
            nextCoinDistance += Float.random(in: 100.0...500.0)
        }
        
        // --- LE "FAUX" CALCUL DE LA VITESSE (L'illusion d'arcade) ---
        // Le ratio magique de 2.25 permet d'afficher 90km/h quand le jeu tourne à 40m/s
        let magicMultiplier: Float = 3.2
        let currentKmH = Int(gameSpeed * magicMultiplier)
        
        if currentKmH != lastReportedSpeed {
            lastReportedSpeed = currentKmH
            DispatchQueue.main.async { self.onSpeedUpdate?(currentKmH) }
        }
        
        // --- LE "FAUX" CALCUL DE LA DISTANCE ---
        // Pour que les kilomètres parcourus soient mathématiquement logiques avec
        // ce faux compteur de vitesse, on applique un ratio inverse à la distance.
        // Ratio de 0.625 (soit 90/144)
        let virtualDistance = distanceTraveled * 0.625
        
        if virtualDistance - lastReportedDistance >= 10.0 {
            lastReportedDistance = virtualDistance
            DispatchQueue.main.async { self.onDistanceUpdate?(virtualDistance) }
        }
        
        if distanceTraveled >= nextCloudDistance {
            spawnCloud()
            // Un nuage apparaît tous les 80 à 150 mètres
            nextCloudDistance += Float.random(in: 80.0...150.0)
        }
        
        // 4. Score lié à la distance (Corrigé pour les très hautes vitesses)
        var didScoreUpdate = false
        while distanceTraveled >= nextScoreDistance {
            score += 1
            nextScoreDistance += 3.0
            didScoreUpdate = true
        }
        
        // On n'envoie la mise à jour à l'interface qu'une seule fois par frame !
        if didScoreUpdate {
            DispatchQueue.main.async { self.onScoreUpdate?(self.score) }
        }
    }
}

extension GameScene: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        // 1. Gestion des pièces
        if nodeA.name == "coin" || nodeB.name == "coin" {
            let coinNode = nodeA.name == "coin" ? nodeA : nodeB
            coinNode.removeFromParentNode()
            DispatchQueue.main.async { self.onCoinCollected?() }
            return
        }
        
        // --- LE CRASH SIMPLE ET EFFICACE ---
        guard !isCrashed else { return }
        isCrashed = true
        
        // 1. On fige l'image, on coupe la musique et on joue le crash IMMÉDIATEMENT
        self.isPaused = true
        self.displayLink?.invalidate()
        self.displayLink = nil // On efface toute trace du moteur
        
        // --- NOUVEAU : GESTION AUDIO ET HAPTIQUE DU CRASH ---
        SoundManager.shared.stopBGM()
        SoundManager.shared.playSFX(filename: "crash")
        HapticManager.shared.playCrash() // <-- NOUVEAU (La double vibration lourde de Game Over)
        
        // 2. L'ANIMATION DE RECUL (RECOIL)
        // La voiture rebondit violemment de 1.5 mètre en arrière
        let recoil = SCNAction.moveBy(x: 0, y: 0, z: 1.5, duration: 0.15)
        recoil.timingMode = .easeOut // L'animation ralentit à la fin du rebond
        
        // L'avant de la voiture se soulève (choc frontal) et elle tourne légèrement sur le côté
        let randomSide = Float.random(in: -0.5...0.5)
        let tilt = SCNAction.rotateBy(x: CGFloat(-Float.pi) / 8, y: CGFloat(randomSide), z: 0, duration: 0.15)
        
        // On joue les deux animations en même temps
        let crashAnimation = SCNAction.group([recoil, tilt])
        playerNode.runAction(crashAnimation)
        
        // 3. LE TREMBLEMENT DE CAMÉRA (Très rapide et sec)
        if let cameraNode = self.rootNode.childNodes.first(where: { $0.camera != nil }) {
            let left = SCNAction.moveBy(x: -0.5, y: -0.3, z: 0, duration: 0.05)
            let right = SCNAction.moveBy(x: 0.5, y: 0.3, z: 0, duration: 0.05)
            let reset = SCNAction.move(to: SCNVector3(0, 3, 5), duration: 0.05)
            let shake = SCNAction.sequence([left, right, left, right, reset])
            cameraNode.runAction(shake)
        }
        
        // 4. FIN RAPIDE
        // On attend juste 0.8 seconde (le temps de voir le rebond) avant d'afficher le menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.isPaused = true
            self.onGameOver?()
        }
    }
}
