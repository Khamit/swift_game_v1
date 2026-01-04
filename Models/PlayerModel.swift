//
//  PlayerModel.swift
//  Nighty Tales
//
//  Created by Khamit on 19.12.2025.
//
//

import Foundation
import Combine

final class PlayerModel: ObservableObject {
    @Published var score: Int = 0
    @Published var comboMultiplier: Int = 1
    @Published var highScore: Int = 0
    @Published var starsCollected: Int = 0
    @Published var mergesCount: Int = 0
    @Published var jumpsCount: Int = 0
    
    // Новая валюта для покупки башен
    @Published var currency: Int = 0
    @Published var totalMoneyEarned: Int = 0
    
    // Множители
    @Published var moneyMultiplier: Double = 1.0
    @Published var speedMultiplier: Double = 1.0
    @Published var blueMultipliers: Int = 0
    
    // Башни
    @Published var towers: [TowerModel] = []
    
    // Для отправки на Firestore
    var playerID: String = UUID().uuidString
    var lastPlayed: Date = Date()
    var playerName: String = "Player"
    
    // Конфигурация начисления очков
    private let baseJumpPoints = 5
    private let baseMergePoints = 100
    private let comboDecayTime: TimeInterval = 3.0
    private var lastMergeTime: Date = Date()
    
    // Множители для особых достижений
    private let specialMultiplierThreshold = 10
    private var specialMultiplierEvents: [Int] = []
    
    init() {
        self.currency = 10000  // Стартовый капитал 10,000
        startComboDecayTimer()
        initializeTowers()
    }
    
    // Инициализация башен
    private func initializeTowers() {
        towers.removeAll()
        
        // Создаем первую башню активной по умолчанию
        let firstTower = TowerType.basic.model
        firstTower.activate()
        towers.append(firstTower)
        
        // Создаем остальные 4 башни неактивными
        for towerType in [TowerType.fast, TowerType.rich, TowerType.mega, TowerType.ultimate] {
            let tower = towerType.model
            towers.append(tower)
        }
    }
    
    // MARK: - Методы начисления очков
    
    func addPoints(_ points: Int) {
        let multipliedPoints = Int(Double(points) * moneyMultiplier)
        score += multipliedPoints * comboMultiplier
        highScore = max(highScore, score)
        
        // Также добавляем валюту (10% от очков)
        let currencyEarned = max(1, multipliedPoints / 10)
        addCurrency(currencyEarned)
    }
    
    func addCurrency(_ amount: Int) {
        currency += amount
        totalMoneyEarned += amount
    }
    
    func spendCurrency(_ amount: Int) -> Bool {
        if currency >= amount {
            currency -= amount
            return true
        }
        return false
    }
    
    func stealMoney(_ amount: Int) -> Int {
        let actualAmount = min(amount, currency)
        currency -= actualAmount
        
        // Уведомляем о краже денег
        if actualAmount > 0 {
            print("game func SM: \(actualAmount)")
        }
        
        return actualAmount
    }
    
    func successfulJump() {
        jumpsCount += 1
        
        // Базовые очки за прыжок
        var points = baseJumpPoints
        
        // Бонус за прыжок во время комбо
        if comboMultiplier > 1 {
            points += comboMultiplier * 2
        }
        
        // Бонус за последовательные прыжки
        if jumpsCount % 10 == 0 {
            points += 50
        }
        
        addPoints(points)
        lastMergeTime = Date()
    }
    
    func merged(level: Int) {
        let basePoints = baseMergePoints * level
        
        // Увеличиваем комбо при слиянии
        comboMultiplier += 1
        
        // Проверяем достижение специальных множителей
        checkSpecialMultiplier()
        
        // Максимальный комбо - 50x
        comboMultiplier = min(comboMultiplier, 50)
        
        addPoints(basePoints)
        mergesCount += 1
        lastMergeTime = Date()
        
        // Увеличиваем синие множители при слиянии определенных уровней
        if level % 3 == 0 {
            blueMultipliers += 1
            updateSpeedMultiplier()
        }
        
        // Увеличиваем множитель денег при слиянии определенных уровней
        if level % 2 == 0 {
            moneyMultiplier = min(10.0, moneyMultiplier + 0.1)
        }
    }
    
    // MARK: - Специальные множители
    
    private func checkSpecialMultiplier() {
        // Проверяем, достигли ли мы порога для специального множителя
        if comboMultiplier % specialMultiplierThreshold == 0 && comboMultiplier > 0 {
            let multiplierValue = comboMultiplier
            
            // Проверяем, чтобы не дублировать события
            if !specialMultiplierEvents.contains(multiplierValue) {
                specialMultiplierEvents.append(multiplierValue)
                
                // Запускаем событие специального множителя
                NotificationCenter.default.post(
                    name: .specialMultiplierReached,
                    object: nil,
                    userInfo: ["multiplier": multiplierValue]
                )
                
                // Бонус за достижение множителя
                let bonus = multiplierValue * 100
                addPoints(bonus)
                addCurrency(bonus / 5)
            }
        }
    }
    
    func getCurrentMultiplierText() -> String? {
        if comboMultiplier >= 10 {
            return "x\(comboMultiplier)"
        }
        return nil
    }
    
    // MARK: - Башни
    
    func updateTowers(currentTime: Date) -> Int {
        var totalProduction = 0
        
        for tower in towers where tower.isActive {
            let production = tower.updateProduction(
                currentTime: currentTime,
                moneyMultiplier: moneyMultiplier,
                speedMultiplier: speedMultiplier
            )
            
            if production > 0 {
                totalProduction += production
                addCurrency(production)
            }
        }
        
        return totalProduction
    }
    
    func purchaseTower(at index: Int) -> Bool {
        guard index < towers.count, !towers[index].isActive else { return false }
        
        let tower = towers[index]
        if spendCurrency(tower.purchaseCost) {
            tower.activate()
            return true
        }
        
        return false
    }
    
    func upgradeTower(at index: Int) -> Bool {
        guard index < towers.count, towers[index].isActive else { return false }
        
        let tower = towers[index]
        if spendCurrency(tower.upgradeCost) {
            return tower.upgrade()
        }
        
        return false
    }
    
    func canPurchaseTower(at index: Int) -> Bool {
        guard index < towers.count else { return false }
        return !towers[index].isActive && currency >= towers[index].purchaseCost
    }
    
    func canUpgradeTower(at index: Int) -> Bool {
        guard index < towers.count else { return false }
        return towers[index].isActive && currency >= towers[index].upgradeCost
    }
    
    // MARK: - Обновление множителей
    
    private func updateSpeedMultiplier() {
        // Синие множители увеличивают скорость производства
        speedMultiplier = 1.0 + (Double(blueMultipliers) * 0.1)
        speedMultiplier = min(speedMultiplier, 3.0) // Максимум 3x скорости
    }
    
    // MARK: - Комбо система
    
    private func startComboDecayTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkComboDecay()
        }
    }
    
    private func checkComboDecay() {
        let timeSinceLastMerge = Date().timeIntervalSince(lastMergeTime)
        
        // Сбрасываем комбо, если прошло больше заданного времени
        if timeSinceLastMerge > comboDecayTime && comboMultiplier > 1 {
            resetCombo()
        }
        
        // Постепенное уменьшение комбо, если долго нет действий
        if timeSinceLastMerge > comboDecayTime * 2 {
            comboMultiplier = max(1, comboMultiplier - 1)
            lastMergeTime = Date()
        }
    }
    
    func resetCombo() {
        if comboMultiplier > 1 {
            print("Комбо сброшено! Был множитель x\(comboMultiplier)")
        }
        comboMultiplier = 1
        specialMultiplierEvents.removeAll()
    }
    
    // MARK: - Дополнительные награды
    
    func achievementBonus(achievementType: AchievementType) {
        let bonusPoints: Int
        
        switch achievementType {
        case .firstMerge:
            bonusPoints = 100
        case .combo5x:
            bonusPoints = 250
        case .combo10x:
            bonusPoints = 1000
        case .combo20x:
            bonusPoints = 5000
        case .combo50x:
            bonusPoints = 25000
        case .collect100Stars:
            bonusPoints = 2000
        case .highScore:
            bonusPoints = 500
        case .towerMaster:
            bonusPoints = 10000
        }
        
        addPoints(bonusPoints)
    }
    
    enum AchievementType {
        case firstMerge
        case combo5x
        case combo10x
        case combo20x
        case combo50x
        case collect100Stars
        case highScore
        case towerMaster
    }
    
    // MARK: - Сброс и управление

    func resetGame() {
        score = 0
        resetCombo()
        jumpsCount = 0
        mergesCount = 0
        currency = 10000  // Возвращаем стартовый капитал
        moneyMultiplier = 1.0
        speedMultiplier = 1.0
        blueMultipliers = 0
        specialMultiplierEvents.removeAll()
        lastPlayed = Date()
        
        // Сбрасываем башни
        for tower in towers {
            tower.reset()
        }
        
        // Активируем первую башню
        if !towers.isEmpty {
            towers[0].activate()
        }
    }
    
    func completeGame() {
        if score > highScore {
            achievementBonus(achievementType: .highScore)
            highScore = score
        }
        
        // Проверяем достижения
        if comboMultiplier >= 5 {
            achievementBonus(achievementType: .combo5x)
        }
        
        if comboMultiplier >= 10 {
            achievementBonus(achievementType: .combo10x)
        }
        
        if comboMultiplier >= 20 {
            achievementBonus(achievementType: .combo20x)
        }
        
        if comboMultiplier >= 50 {
            achievementBonus(achievementType: .combo50x)
        }
        
        if starsCollected >= 100 {
            achievementBonus(achievementType: .collect100Stars)
        }
        
        // Проверяем, все ли башни построены
        let allTowersBuilt = towers.allSatisfy { $0.isActive }
        if allTowersBuilt {
            achievementBonus(achievementType: .towerMaster)
        }
        
        saveLocalData()
    }
    
    // MARK: - Сохранение данных
    
    func saveLocalData() {
        UserDefaults.standard.set(highScore, forKey: "highScore_\(playerID)")
        UserDefaults.standard.set(playerName, forKey: "playerName_\(playerID)")
        UserDefaults.standard.set(starsCollected, forKey: "starsCollected_\(playerID)")
        UserDefaults.standard.set(currency, forKey: "currency_\(playerID)")
        UserDefaults.standard.set(totalMoneyEarned, forKey: "totalMoneyEarned_\(playerID)")
        
        // Сохраняем данные башен
        var towersData: [[String: Any]] = []
        for tower in towers {
            towersData.append(tower.toDictionary())
        }
        UserDefaults.standard.set(towersData, forKey: "towers_\(playerID)")
    }
    
    func loadLocalData() {
        highScore = UserDefaults.standard.integer(forKey: "highScore_\(playerID)")
        playerName = UserDefaults.standard.string(forKey: "playerName_\(playerID)") ?? "Player"
        starsCollected = UserDefaults.standard.integer(forKey: "starsCollected_\(playerID)")
        currency = UserDefaults.standard.integer(forKey: "currency_\(playerID)")
        totalMoneyEarned = UserDefaults.standard.integer(forKey: "totalMoneyEarned_\(playerID)")
        
        // Загружаем данные башен
        if let towersData = UserDefaults.standard.array(forKey: "towers_\(playerID)") as? [[String: Any]] {
            for (index, data) in towersData.enumerated() where index < towers.count {
                if let isActive = data["isActive"] as? Bool, isActive {
                    towers[index].activate()
                }
                if let level = data["level"] as? Int {
                    towers[index].level = level
                }
            }
        }
    }
    
    // MARK: - Для Firestore
    
    func toDictionary() -> [String: Any] {
        var towersData: [[String: Any]] = []
        for tower in towers {
            towersData.append(tower.toDictionary())
        }
        
        return [
            "playerID": playerID,
            "playerName": playerName,
            "score": score,
            "highScore": highScore,
            "currency": currency,
            "totalMoneyEarned": totalMoneyEarned,
            "starsCollected": starsCollected,
            "mergesCount": mergesCount,
            "jumpsCount": jumpsCount,
            "comboMultiplier": comboMultiplier,
            "moneyMultiplier": moneyMultiplier,
            "speedMultiplier": speedMultiplier,
            "blueMultipliers": blueMultipliers,
            "towers": towersData,
            "lastPlayed": Date(),
            "gameVersion": "1.1.0"
        ]
    }
    
    func fromDictionary(_ dict: [String: Any]) {
        if let id = dict["playerID"] as? String { playerID = id }
        if let name = dict["playerName"] as? String { playerName = name }
        if let score = dict["score"] as? Int { self.score = score }
        if let highScore = dict["highScore"] as? Int { self.highScore = highScore }
        if let currency = dict["currency"] as? Int { self.currency = currency }
        if let totalMoney = dict["totalMoneyEarned"] as? Int { totalMoneyEarned = totalMoney }
        if let stars = dict["starsCollected"] as? Int { starsCollected = stars }
        if let merges = dict["mergesCount"] as? Int { mergesCount = merges }
        if let jumps = dict["jumpsCount"] as? Int { jumpsCount = jumps }
        if let combo = dict["comboMultiplier"] as? Int { comboMultiplier = combo }
        if let moneyMult = dict["moneyMultiplier"] as? Double { moneyMultiplier = moneyMult }
        if let speedMult = dict["speedMultiplier"] as? Double { speedMultiplier = speedMult }
        if let blueMults = dict["blueMultipliers"] as? Int { blueMultipliers = blueMults }
        
        if let towersData = dict["towers"] as? [[String: Any]] {
            for (index, data) in towersData.enumerated() where index < towers.count {
                if let isActive = data["isActive"] as? Bool, isActive {
                    towers[index].activate()
                }
                if let level = data["level"] as? Int {
                    towers[index].level = level
                }
            }
        }
    }
}

// Расширение для уведомлений
extension Notification.Name {
    static let specialMultiplierReached = Notification.Name("specialMultiplierReached")
}
