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

    var nextCoinDistance: Float = 500.0     // Kilométrage de la prochaine pièce
    
    var onNearMiss: (() -> Void)?
    
    var lastLaneChangeTime: TimeInterval = 0.0
    
    override init() {
        super.init()
        setupCamera()
        setupPlayer()
        setupEnvironment()
        prefillLineDashes()
        
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
        let geometry = SCNBox(width: 0.4, height: 0.4, length: 0.8, chamferRadius: 0.05)
        geometry.firstMaterial?.diffuse.contents = UIColor.systemRed
        playerNode = SCNNode(geometry: geometry)
        playerNode.position = SCNVector3(x: lanes[currentLaneIndex], y: 0.2, z: 2)
        playerNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        playerNode.physicsBody?.categoryBitMask = CollisionCategory.player
        playerNode.physicsBody?.contactTestBitMask = CollisionCategory.obstacle | CollisionCategory.coin
        self.rootNode.addChildNode(playerNode)
    }
    
    func movePlayer(direction: Int) {
        let newIndex = currentLaneIndex + direction
        if newIndex >= 0 && newIndex < lanes.count {
            currentLaneIndex = newIndex
            
            // --- NOUVEAU : On enregistre le moment exact du coup de volant ---
            lastLaneChangeTime = CACurrentMediaTime()
            
            let targetPosition = SCNVector3(x: lanes[currentLaneIndex], y: playerNode.position.y, z: playerNode.position.z)
            let moveAction = SCNAction.move(to: targetPosition, duration: 0.15)
            moveAction.timingMode = .easeOut
            playerNode.runAction(moveAction)
        }
    }
    
    func setBoost(active: Bool) {
        // On donne la vitesse cible : 60 en appuyant, retour à 30 en relâchant
        targetSpeed = active ? 80.0 : 40.0
    }
    
    func setupEnvironment() {
        self.background.contents = UIColor.systemTeal
        let sunGeo = SCNSphere(radius: 5.0)
        sunGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        sunGeo.firstMaterial?.emission.contents = UIColor.systemYellow
        let sunNode = SCNNode(geometry: sunGeo)
        sunNode.position = SCNVector3(x: 10, y: 15, z: -80)
        self.rootNode.addChildNode(sunNode)
        
        let floorGeometry = SCNFloor()
        floorGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen
        floorGeometry.reflectivity = 0.0
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.position = SCNVector3(x: 0, y: 0, z: 0)
        self.rootNode.addChildNode(floorNode)
        
        let roadGeo = SCNBox(width: 2.4, height: 0.005, length: 200.0, chamferRadius: 0)
        roadGeo.firstMaterial?.diffuse.contents = UIColor.darkGray
        let roadNode = SCNNode(geometry: roadGeo)
        roadNode.position = SCNVector3(x: 0, y: 0.005, z: -45)
        self.rootNode.addChildNode(roadNode)
        
        let edgeXPositions: [Float] = [-1.2, 1.2]
        for x in edgeXPositions {
            let edgeLineGeo = SCNBox(width: 0.05, height: 0.01, length: 100.0, chamferRadius: 0)
            edgeLineGeo.firstMaterial?.diffuse.contents = UIColor.white
            let edgeLineNode = SCNNode(geometry: edgeLineGeo)
            edgeLineNode.position = SCNVector3(x: x, y: 0.01, z: -45)
            self.rootNode.addChildNode(edgeLineNode)
        }
    }
    
    func spawnObstacle() {
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
        let obstacleGeo = SCNBox(width: 0.4, height: 0.4, length: 0.8, chamferRadius: 0.05)
        let obstacleNode = ObstacleNode()
        obstacleNode.geometry = obstacleGeo
        
        obstacleNode.drivingSpeed = newSpeed
        obstacleNode.currentLaneIndex = randomLaneIndex // NOUVEAU : On mémorise la bande
        
        let colorIntensity = CGFloat(obstacleNode.drivingSpeed / 30.0)
        obstacleGeo.firstMaterial?.diffuse.contents = UIColor(white: colorIntensity + 0.3, alpha: 1.0)
        
        obstacleNode.position = SCNVector3(x: randomLaneX, y: 0.2, z: -50)
        obstacleNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
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
        
        
        // --- 1. ACCÉLÉRATION ET FREINAGE PROGRESSIFS ---
        // accelerationRate à 10.0 = Il faut 3 secondes pour passer de 30 à 60
        let accelerationRate: Float = 10.0
        // decelerationRate à 45.0 = Frein moteur rapide (0.6 seconde pour revenir à 30)
        let decelerationRate: Float = 45.0
        
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
                
                // 2. IA DE CHANGEMENT DE VOIE
                // On déclenche la décision quand la voiture arrive à 35 mètres de nous
                if obstacle.position.z > -35.0 && !obstacle.hasDecidedToTurn {
                    obstacle.hasDecidedToTurn = true // Décision prise une seule fois
                    
                    // 30% de chance d'essayer de changer de bande
                    if Int.random(in: 1...100) <= 30 {
                        var possibleDirections: [Int] = []
                        if obstacle.currentLaneIndex > 0 { possibleDirections.append(-1) } // Peut aller à gauche
                        if obstacle.currentLaneIndex < lanes.count - 1 { possibleDirections.append(1) } // Peut aller à droite
                        
                        if let dir = possibleDirections.randomElement() {
                            let targetIndex = obstacle.currentLaneIndex + dir
                            
                            // SÉCURITÉ : Vérifier si la bande cible est libre
                            var isSafe = true
                            for otherNode in self.rootNode.childNodes {
                                if let otherCar = otherNode as? ObstacleNode, otherCar != obstacle {
                                    if otherCar.currentLaneIndex == targetIndex {
                                        // Si une autre voiture est à moins de 15m (devant ou derrière), on annule !
                                        if abs(otherCar.position.z - obstacle.position.z) < 15.0 {
                                            isSafe = false
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if isSafe {
                                // On valide le changement ! On "réserve" la bande tout de suite.
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
                
                // --- 4. DÉTECTION DU NEAR MISS ---
                let dz = abs(obstacle.position.z - playerNode.position.z)
                let dx = abs(obstacle.position.x - playerNode.position.x)
                
                // NOUVEAU : Est-ce qu'on vient de donner un coup de volant ?
                // Le mouvement dure 0.15s, on laisse 0.4s de fenêtre pour être généreux
                let currentTime = CACurrentMediaTime()
                let isDodging = (currentTime - lastLaneChangeTime) < 0.15
                
                // On ajoute "isDodging" à la validation !
                if dz < 0.7 && dx > 0.45 && dx < 0.75 && !obstacle.hasScoredNearMiss && isDodging {
                    obstacle.hasScoredNearMiss = true
                    
                    let bonus = (targetSpeed > 40.0) ? 20 : 10
                    score += bonus
                    
                    DispatchQueue.main.async {
                        self.onScoreUpdate?(self.score)
                        self.onNearMiss?()
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
            nextCoinDistance += Float.random(in: 500.0...2000.0) // Une pièce tous les 20 à 50m
        }
        
        // --- LE "FAUX" CALCUL DE LA VITESSE (L'illusion d'arcade) ---
        // Le ratio magique de 2.25 permet d'afficher 90km/h quand le jeu tourne à 40m/s
        let magicMultiplier: Float = 2.25
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
        
        // 4. Score lié à la distance (Le boost le fait grimper 2x plus vite !)
        if distanceTraveled >= nextScoreDistance {
            score += 1
            DispatchQueue.main.async { self.onScoreUpdate?(self.score) }
            nextScoreDistance += 3.0
        }
    }
}

extension GameScene: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        // 1. Est-ce qu'on a touché une pièce ?
        if nodeA.name == "coin" || nodeB.name == "coin" {
            let coinNode = nodeA.name == "coin" ? nodeA : nodeB
            coinNode.removeFromParentNode() // La pièce disparaît !
            
            // On prévient l'interface de rajouter 1 coin
            DispatchQueue.main.async { self.onCoinCollected?() }
            return // On s'arrête là, pas de Game Over !
        }
        
        // 2. Sinon, c'est un obstacle ! GAME OVER.
        self.isPaused = true
        self.displayLink?.invalidate()
        DispatchQueue.main.async {
            self.onGameOver?()
        }
    }
}
