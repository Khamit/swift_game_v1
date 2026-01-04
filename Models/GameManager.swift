//
//  GameManager.swift
//  Nighty Tales
//
//  Created by Khamit on 19.12.2025.
//
//

import SwiftUI
import Combine

final class GameManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var player: PlayerModel
    @Published private(set) var stars: [StarModel] = []
    @Published private(set) var particleSystem = ParticleSystem()
    @Published private(set) var gameBoard: CGRect = .zero
    @Published private(set) var isGameActive: Bool = false
    @Published private(set) var enemyManager = EnemyManager()
    @Published private(set) var screenSplit = ScreenDividerModel()
    
    // MARK: - Game Properties
    private let maxStars = 12
    private let maxStarLevel = 5
    private let explosionLevel = 10
    private var mergeTimer: Timer?
    private var productionTimer: Timer?
    private var gameTime: TimeInterval = 0
    private var lastStarSpawnTime: TimeInterval = 0
    private var spawnInterval: TimeInterval = 4.0
    
    // MARK: - Wave System Properties
    @Published private(set) var currentWave: Int = 1
    @Published private(set) var timeToNextWave: Int = 10
    @Published private(set) var enemiesThisWave: Int = 3
    private var waveTimer: Timer?
    private var waveProgressTimer: Timer?
    
    // Слияния
    private var lastMergeTime: Date = Date()
    private var mergeCooldown: TimeInterval = 0.5
    private var lastProductionUpdate: Date = Date()
    
    // Уведом   ления
    @Published var showMultiplierNotification: Bool = false
    @Published var currentMultiplierNotification: String = ""
    private var notificationTimer: Timer?
    
    
    @Published var activeBuffs: [ActiveBuff] = []
    
    // MARK: - HUD Metrics

    var threatLevel: Double {
        let zoneThreat = Double(screenSplit.enemyRatio)
        let enemyThreat = min(Double(enemyManager.activeEnemies.count) / 10.0, 1.0)
        return min((zoneThreat * 0.6 + enemyThreat * 0.4), 1.0)
    }

    @Published var timeScale: Double = 1.0

    
    // MARK: - Init
    init() {
        self.player = PlayerModel()
        enemyManager.loadEnemies()
    }
    
    // MARK: - Game Setup
    func setupGame(in bounds: CGRect) {
        gameBoard = bounds
        isGameActive = true

        spawnInitialStars(in: bounds)
        startWaveSystem(in: bounds) // ← ВАЖНО
        startGameTimers()
        startEnemyPressure()
    }
    
    private func spawnInitialStars(in bounds: CGRect) {
        // Звезды появляются только в нижней зоне (игровой зоне)
        let playerZoneHeight = bounds.height * (1 - screenSplit.enemyRatio)
        let playerZoneY = bounds.height * screenSplit.enemyRatio
        
        for _ in 0..<4 {
            let position = CGPoint(
                x: CGFloat.random(in: 50...(bounds.width - 50)),
                y: CGFloat.random(in: playerZoneY + 50...(bounds.height - 50))
            )
            
            let star = StarModel(
                position: position,
                size: CGSize(width: 60, height: 60),
                color: .yellow
            )
            stars.append(star)
        }
    }
    
    private func startWaveSystem(in bounds: CGRect) {
        // Сбрасываем волны
        currentWave = 1
        timeToNextWave = 30
        enemiesThisWave = 3
        
        // Запускаем таймеры волн
        startWaveTimer(in: bounds)
        startWaveProgressTimer()
    }
    
    private func startWaveTimer(in bounds: CGRect) {
        waveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isGameActive else { return }
            self.spawnWave(in: bounds)
        }
        
        // Первая волна через 30 секунд
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isGameActive {
                self.spawnWave(in: bounds)
            }
        }
    }
    
    private func startWaveProgressTimer() {
        waveProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isGameActive else { return }
            
            if self.timeToNextWave > 0 {
                self.timeToNextWave -= 1
            }
        }
    }
    
    private func spawnWave(in bounds: CGRect) {
        let spawnDelay = max(0.3, 1.5 - Double(currentWave) * 0.05)

        print("🌊 Волна \(currentWave) начинается!")
        
        let pressure = min(0.02 + CGFloat(currentWave) * 0.002, 0.05)
        screenSplit.shiftTowardEnemy(by: pressure)
        
        let baseEnemies = 3
        let scaling = currentWave / 2
        let waveEnemiesCount = min(baseEnemies + scaling, 20)

        
        // Рассчитываем количество врагов для этой волны
        // let waveEnemiesCount = min(3 + currentWave, 8) // Максимум 8 врагов
        
        // Создаем врагов текущего уровня волны
        for i in 0..<waveEnemiesCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * spawnDelay) {
                _ = self.enemyManager.spawnWaveEnemy(
                    level: min(self.currentWave, 5),
                    in: bounds,
                    enemyZoneHeight: self.screenSplit.enemyRatio
                )
            }
        }
        
        // Увеличиваем уровень волны
        currentWave += 1
        
        // Сброс таймера до следующей волны
        timeToNextWave = 10
        
        print("⏳ До следующей волны: 30 секунд")
    }
    
    func setTimeScale(_ scale: Double) {
        timeScale = scale
        pauseGame()
        resumeGame()
    }
    
    private func startGameTimers() {
        mergeTimer = Timer.scheduledTimer(withTimeInterval: 0.1 / timeScale, repeats: true) { [weak self] _ in
            self?.checkForMerges()
        }
        
        productionTimer = Timer.scheduledTimer(withTimeInterval: 1.0  / timeScale, repeats: true) { [weak self] _ in
            self?.updateTowerProduction()
        }
    }
    
    private func startEnemyPressure() {
        // Враги постепенно увеличивают свою территорию
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isGameActive else { return }
            
            // Враги расширяют свою территорию
            self.screenSplit.shiftTowardEnemy(by: 0.05)
            
            print("📈 Враги расширили территорию: \(self.screenSplit.enemyRatio * 100)%")
        }
    }
    
    // MARK: - Game Loop
    
    func updateGame(deltaTime: TimeInterval, bounds: CGRect) {
        guard isGameActive else { return }
        
        gameTime += deltaTime
        
        // Обновление врагов
        enemyManager.updateEnemies(
            deltaTime: deltaTime,
            bounds: bounds,
            enemyZoneHeight: screenSplit.enemyRatio
        )
        
        // Обновление звезд (только в нижней зоне)
        updateStars(deltaTime: deltaTime, bounds: bounds)
        
        // Проверка столкновений звезд с врагами
        checkStarEnemyCollisions()
        
        // Проверка конца игры
        if screenSplit.enemyRatio >= 0.95 {
            gameOver()
        }
    }
    
    
    private func updateStars(deltaTime: TimeInterval, bounds: CGRect) {
        let enemyZoneHeightPixels = bounds.height * screenSplit.enemyRatio
        
        for index in stars.indices.reversed() {
            let star = stars[index]
            // Звезда летит
            if star.isInFlight {
                star.update(deltaTime: CGFloat(deltaTime), bounds: bounds)
                
                // Проверяем, вышла ли звезда за пределы экрана
                if star.position.x < -50 || star.position.x > bounds.width + 50 ||
                   star.position.y < -50 || star.position.y > bounds.height + 50 {
                    stars.remove(at: index)
                    continue
                }
                
                // Если звезда попала во вражескую зону и остановилась, возвращаем ее в игровую зону
                if !star.isInFlight && star.position.y < enemyZoneHeightPixels {
                    star.position = CGPoint(
                        x: CGFloat.random(in: 50...(bounds.width - 50)),
                        y: bounds.height - 100
                    )
                }
            }
        }
        
        // Спавн новых звезд
        if gameTime - lastStarSpawnTime > spawnInterval && stars.count < maxStars {
            spawnNewStar(in: bounds)
            lastStarSpawnTime = gameTime
        }
    }
    
    private func spawnNewStar(in bounds: CGRect) {
        let playerZoneHeight = bounds.height * (1 - screenSplit.enemyRatio)
        let playerZoneY = bounds.height * screenSplit.enemyRatio
        
        let position = CGPoint(
            x: CGFloat.random(in: 50...(bounds.width - 50)),
            y: CGFloat.random(in: playerZoneY + 50...(bounds.height - 50))
        )
        
        let star = StarModel(
            position: position,
            size: CGSize(width: 60, height: 60),
            color: .yellow
        )
        
        stars.append(star)
        print("⭐️ Новая звезда появилась в нижней зоне")
    }
    
    // MARK: - Star & Enemy Interactions
    private func checkStarEnemyCollisions() {
        for star in stars where star.isInFlight {
            for enemy in enemyManager.activeEnemies {
                let distance = sqrt(
                    pow(star.position.x - enemy.position.x, 2) +
                    pow(star.position.y - enemy.position.y, 2)
                )
                
                let collisionDistance = (star.size.width + enemy.size.width) / 3
                
                if distance < collisionDistance {
                    // Звезда наносит урон врагу
                    handleStarHitEnemy(star: star, enemy: enemy)
                    break
                }
            }
        }
    }
    
    private func handleStarHitEnemy(star: StarModel, enemy: EnemyModel) {
        // Урон в зависимости от уровня звезды
        let damage = star.damage
        enemy.takeDamage(damage)
        
        print("💥 Звезда уровня \(star.level) наносит \(damage) урона врагу \(enemy.name)")
        
        // Взрыв частиц
        particleSystem.emit(at: enemy.position, count: 15, color: .red)
        
        // Если враг побежден
        if enemy.health <= 0 {
            // Награда за победу
            let reward = enemy.lootReward
            player.addCurrency(reward)
            player.addPoints(reward * 10)
            
            // Удаляем врага
            enemyManager.removeEnemy(enemy)
            
            // Уменьшаем вражескую зону (игрок отвоевывает территорию)
            screenSplit.shiftTowardPlayer(by: 0.05)
            
            print("🎉 Враг \(enemy.name) уничтожен! Награда: \(reward)$")
        }
        
        // Удаляем звезду после попадания
        if enemy.health <= 0 {
            if let index = stars.firstIndex(where: { $0.id == star.id }) {
                stars.remove(at: index)
            }
        }
    }
    
    // MARK: - Star Dragging
    func starDragged(_ star: StarModel, to location: CGPoint) {
        guard let index = stars.firstIndex(where: { $0.id == star.id }) else { return }
        stars[index].updateDrag(to: location)
    }
    
    func starDragEnded(_ star: StarModel) {
        guard let index = stars.firstIndex(where: { $0.id == star.id }) else { return }
        let (velocity, force) = stars[index].endDrag()
        
        if force > 0.1 { // Минимальная сила для запуска
            print("🚀 Звезда запущена с силой: \(Int(force * 100))%")
        }
    }
    
    // MARK: - Merging System
    private func checkForMerges() {
        guard Date().timeIntervalSince(lastMergeTime) > mergeCooldown else { return }
        
        for i in 0..<stars.count {
            for j in (i+1)..<stars.count where i < stars.count && j < stars.count {
                let star1 = stars[i]
                let star2 = stars[j]
                
                if star1.canMerge(with: star2) && star1.intersects(star2) {
                    performMerge(star1: star1, star2: star2)
                    lastMergeTime = Date()
                    return
                }
            }
        }
    }
    
    private func performMerge(star1: StarModel, star2: StarModel) {
        guard let index1 = stars.firstIndex(where: { $0.id == star1.id }),
              let index2 = stars.firstIndex(where: { $0.id == star2.id }),
              index1 != index2 else { return }
        
        // Увеличиваем уровень первой звезды
        stars[index1].merge(with: star2)
        
        // Удаляем вторую звезду
        stars.remove(at: index2)
        
        // Взрыв частиц
        particleSystem.emit(at: star1.position, count: 25, color: star1.color)
        
        // Начисление очков
        player.merged(level: stars[index1].level)
        
        print("✨ Слияние! Новый уровень: \(stars[index1].level)")
    }
    
    // MARK: - Tower Production
    private func updateTowerProduction() {
        let currentTime = Date()
        let production = player.updateTowers(currentTime: currentTime)
        
        if production > 0 {
            print("🏦 Башни произвели: \(production)$")
        }
    }

    // MARK: - Money Stealing (с задержкой)
    private var lastStealTime: Date = Date()
    private let stealCooldown: TimeInterval = 3.0 // Задержка 3 секунды между кражами
    
    func processMoneySteal() {
        guard isGameActive else { return }
        
        // Проверяем задержку
        guard Date().timeIntervalSince(lastStealTime) >= stealCooldown else { return }
        lastStealTime = Date()
        
        var totalStolen = 0
        let activeEnemies = enemyManager.activeEnemies
        
        // Случайный враг крадет деньги
        if let randomEnemy = activeEnemies.randomElement() {
            let stealAmount = randomEnemy.stealAmount
            guard stealAmount > 0 else { return }
            
            let stolen = player.stealMoney(stealAmount)
            
            if stolen > 0 {
                totalStolen += stolen
                
                // Враги расширяют территорию при краже денег
                let expansion = CGFloat(stolen) / 10000.0 * 0.02 // Уменьшили коэффициент
                screenSplit.shiftTowardEnemy(by: expansion)
                
                print("💰 Враг \(randomEnemy.name) украл \(stolen)$ (всего украдено: \(totalStolen)$)")
                
                // Создаем анимацию кражи денег
                NotificationCenter.default.post(
                    name: .moneyStolen,
                    object: nil,
                    userInfo: ["amount": stolen, "position": randomEnemy.position]
                )
            }
        }
        
        // ❗️ КОНЕЦ ИГРЫ ПО ДЕНЬГАМ
        if player.currency <= 0 {
            NotificationCenter.default.post(
                name: .gameOverByEnemySteal,
                object: nil
            )
        }
    }
    
    // MARK: - Game State
    func pauseGame() {
        isGameActive = false
        mergeTimer?.invalidate()
        productionTimer?.invalidate()
        waveTimer?.invalidate()
        waveProgressTimer?.invalidate()
    }
    
    func resumeGame() {
        isGameActive = true
        startGameTimers()
        if let bounds = gameBoard.size.width > 0 ? gameBoard : nil {
            startWaveTimer(in: bounds)
            startWaveProgressTimer()
        }
    }
    
    func gameOver() {
        isGameActive = false
        pauseGame()
        player.completeGame()
        
        print("💀 Игра окончена! Вражеская зона заполнила экран")
        
        NotificationCenter.default.post(
            name: .gameOver,
            object: nil
        )
    }
    
    func resetGame() {
        stars.removeAll()
        enemyManager.activeEnemies.removeAll()
        screenSplit.reset()
        player.resetGame()
        
        mergeTimer?.invalidate()
        productionTimer?.invalidate()
        waveTimer?.invalidate()
        waveProgressTimer?.invalidate()
        
        isGameActive = false
    }
    
    func saveGameData() {
        player.saveLocalData()
        enemyManager.saveEnemies()
    }
    
    // MARK: - Helper Methods
    
    func purchaseTower(at index: Int) -> Bool {
        return player.purchaseTower(at: index)
    }
    
    func upgradeTower(at index: Int) -> Bool {
        return player.upgradeTower(at: index)
    }
    
    func canPurchaseTower(at index: Int) -> Bool {
        return player.canPurchaseTower(at: index)
    }
    
    func canUpgradeTower(at index: Int) -> Bool {
        return player.canUpgradeTower(at: index)
    }
}

// Расширения для уведомлений
extension Notification.Name {
    static let gameOverByEnemySteal = Notification.Name("gameOverByEnemySteal")
    static let gameOver = Notification.Name("gameOver")
    static let moneyStolen = Notification.Name("moneyStolen")
    static let waveStarted = Notification.Name("waveStarted")
}

struct ActiveBuff: Identifiable {
    let id = UUID()
    let icon: String
    let remainingTime: Int
}
