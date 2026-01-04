//
//  EnemyModel.swift
//  Nighty Tales
//
//  Created by Khamit on 24.12.2025.
//

import Foundation
import Combine
internal import CoreGraphics

// Типы документов у врагов
enum DocumentType {
    case fakeDoc
    case orderToJudge
    case none
}

// Типы урона
enum DamageType: String, Codable {
    case physical
    case magical
    case poison
    case fire
    
    var baseDamage: Int {
        switch self {
        case .physical: return 10
        case .magical: return 15
        case .poison: return 5
        case .fire: return 12
        }
    }
}

// Основная модель врага
final class EnemyModel: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var health: Int
    @Published var maxHealth: Int
    @Published var level: Int
    @Published var isBoss: Bool
    @Published var isActive: Bool
    @Published var isHidden: Bool
    @Published var defence: Int
    @Published var relationshipLevel: Int // 0-100, где 100 - лучшие отношения
    
    // Атаки (может быть несколько)
    @Published var attacks: [EnemyAttack]
    
    // Документ (один из двух типов или отсутствует)
    @Published var document: DocumentType
    
    // Дополнительные параметры
    // @Published var stealAmount: Int // Сколько денег может украсть
    @Published var appearanceChance: Double // Шанс появления (0-1)
    @Published var lootReward: Int // Награда за победу
    @Published var image: String
    // Добавляем новые свойства для позиции и размера
    @Published var position: CGPoint
    @Published var size: CGSize
    // Враг урон
    // private var hitsReceived: [Int: Int] = [:] // [starLevel: hitCount]
    // @Published var hitsRequired: [Int: Int] // [starLevel: hitsNeeded]
    // @Published var currentHits: Int = 0
    @Published var opacity: Double = 1.0
    
    init(
        id: UUID = UUID(),
        name: String,
        health: Int = 100,
        level: Int = 1,
        isBoss: Bool = false,
        isActive: Bool = true,
        isHidden: Bool = false,
        defence: Int = 5,
        relationshipLevel: Int = 50,
        attacks: [EnemyAttack] = [],
        document: DocumentType = .none,
        appearanceChance: Double = 0.5,
        lootReward: Int = 100,
        image: String = "enemy1",
        position: CGPoint = .zero, // НОВОЕ: позиция по умолчанию
        size: CGSize = CGSize(width: 80, height: 80), // НОВОЕ: размер по умолчанию
        opacity: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.health = health
        self.maxHealth = health
        self.level = level
        self.isBoss = isBoss
        self.isActive = isActive
        self.isHidden = isHidden
        self.defence = defence
        self.relationshipLevel = relationshipLevel
        self.attacks = attacks
        self.document = document
        self.appearanceChance = appearanceChance
        self.lootReward = lootReward
        self.image = image
        self.position = position
        self.size = size
        self.opacity = opacity
        
        // Если атаки не указаны, создаем базовые
        if attacks.isEmpty {
            self.attacks = [EnemyAttack(type: .physical, damage: 10 + level * 2)]
        }
    }
    
    func takeDamage(_ damage: Int) {
        let reduced = max(1, damage - defence)
        health = max(0, health - reduced)
    }


    
    // Атаковать игрока
    func attack(playerDefence: Int) -> (damage: Int, stealAmount: Int) {
        guard isActive else { return (0, 0) }
        
        // Выбираем случайную атаку
        let selectedAttack = attacks.randomElement() ?? attacks[0]
        
        // Учитываем защиту
        let calculatedDamage = max(1, selectedAttack.damage - playerDefence)
        
        // Шанс украсть деньги (30% если stealAmount > 0)
        let willSteal = stealAmount > 0 && Double.random(in: 0...1) < 0.3
        
        return (
            damage: calculatedDamage,
            stealAmount: willSteal ? stealAmount : 0
        )
    }
    
    // Исцелить
    func heal(_ amount: Int) {
        health = min(maxHealth, health + amount)
    }
    
    // Изменить уровень отношений
    func updateRelationship(change: Int) {
        relationshipLevel = max(0, min(100, relationshipLevel + change))
    }
    
    // Получить документ (если есть)
    func getDocument() -> DocumentType? {
        return document != .none ? document : nil
    }
    
    // Для Firestore/сохранения
    func toDictionary() -> [String: Any] {
        var attacksData: [[String: Any]] = []
        for attack in attacks {
            attacksData.append(attack.toDictionary())
        }
        
        return [
            "id": id.uuidString,
            "name": name,
            "health": health,
            "maxHealth": maxHealth,
            "level": level,
            "isBoss": isBoss,
            "isActive": isActive,
            "isHidden": isHidden,
            "defence": defence,
            "relationshipLevel": relationshipLevel,
            "attacks": attacksData,
            "document": documentString(),
            "appearanceChance": appearanceChance,
            "lootReward": lootReward,
            "image": image,
            "positionX": position.x, // ДОБАВИТЬ
            "positionY": position.y, // ДОБАВИТЬ
            "sizeWidth": size.width, // ДОБАВИТЬ
            "sizeHeight": size.height, // ДОБАВИТЬ
            "opacity": opacity
        ]
    }
    
    private func documentString() -> String {
        switch document {
        case .fakeDoc: return "fakeDoc"
        case .orderToJudge: return "orderToJudge"
        case .none: return "none"
        }
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> EnemyModel? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String else {
            return nil
        }
        
        let positionX = dict["positionX"] as? CGFloat ?? 0
        let positionY = dict["positionY"] as? CGFloat ?? 0
        let sizeWidth = dict["sizeWidth"] as? CGFloat ?? 80
        let sizeHeight = dict["sizeHeight"] as? CGFloat ?? 80
        
        let health = dict["health"] as? Int ?? 100
        let maxHealth = dict["maxHealth"] as? Int ?? health
        
        let enemy = EnemyModel(
            id: id,
            name: name,
            health: dict["health"] as? Int ?? 100,
            level: dict["level"] as? Int ?? 1,
            isBoss: dict["isBoss"] as? Bool ?? false,
            isActive: dict["isActive"] as? Bool ?? true,
            isHidden: dict["isHidden"] as? Bool ?? false,
            defence: dict["defence"] as? Int ?? 5,
            relationshipLevel: dict["relationshipLevel"] as? Int ?? 50,
            appearanceChance: dict["appearanceChance"] as? Double ?? 0.5,
            lootReward: dict["lootReward"] as? Int ?? 100,
            image: dict["image"] as? String ?? "enemy1",
            position: CGPoint(x: positionX, y: positionY),
            size: CGSize(width: sizeWidth, height: sizeHeight)
        )
        
        // Восстанавливаем атаки
        if let attacksData = dict["attacks"] as? [[String: Any]] {
            var attacks: [EnemyAttack] = []
            for attackData in attacksData {
                if let attack = EnemyAttack.fromDictionary(attackData) {
                    attacks.append(attack)
                }
            }
            enemy.attacks = attacks
        }
        
        // Восстанавливаем документ
        if let docString = dict["document"] as? String {
            switch docString {
            case "fakeDoc": enemy.document = .fakeDoc
            case "orderToJudge": enemy.document = .orderToJudge
            default: enemy.document = .none
            }
        }
        
        // Восстанавливаем hitsReceived
        if let hitsDict = dict["hitsReceived"] as? [String: Int] {
            var hits: [Int: Int] = [:]
            for (key, value) in hitsDict {
                if let level = Int(key) {
                    hits[level] = value
                }
            }
        }
        
        // Восстанавливаем opacity
        enemy.opacity = dict["opacity"] as? Double ?? 1.0
        
        return enemy
    }
}

// Модель атаки врага
struct EnemyAttack: Codable {
    let type: DamageType
    var damage: Int
    let specialEffect: String? // Дополнительный эффект
    
    init(type: DamageType, damage: Int, specialEffect: String? = nil) {
        self.type = type
        self.damage = damage
        self.specialEffect = specialEffect
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "type": typeString(),
            "damage": damage,
            "specialEffect": specialEffect as Any
        ]
    }
    
    private func typeString() -> String {
        switch type {
        case .physical: return "physical"
        case .magical: return "magical"
        case .poison: return "poison"
        case .fire: return "fire"
        }
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> EnemyAttack? {
        guard let typeString = dict["type"] as? String,
              let damage = dict["damage"] as? Int else {
            return nil
        }
        
        let type: DamageType
        switch typeString {
        case "physical": type = .physical
        case "magical": type = .magical
        case "poison": type = .poison
        case "fire": type = .fire
        default: type = .physical
        }
        
        let specialEffect = dict["specialEffect"] as? String
        
        return EnemyAttack(type: type, damage: damage, specialEffect: specialEffect)
    }
}

// Менеджер врагов
class EnemyManager: ObservableObject {
    @Published var enemies: [EnemyModel] = []
    @Published var activeEnemies: [EnemyModel] = []
    @Published var bossDefeated: Bool = false
    
    private var spawnTimer: Timer?
    // Предопределенные враги
    private let baseEnemies: [EnemyModel] = [
        EnemyModel(
            name: "Theif",
            health: 50,
            level: 1,
            defence: 2,
            attacks: [EnemyAttack(type: .physical, damage: 8)],
            appearanceChance: 0.8,
            lootReward: 500,
            image: "enemy1" // ДОБАВИТЬ КАРТИНКУ
        ),
        EnemyModel(
            name: "Corrupt",
            health: 120,
            level: 3,
            defence: 8,
            attacks: [
                EnemyAttack(type: .physical, damage: 15),
                EnemyAttack(type: .magical, damage: 20, specialEffect: "Снижает доход")
            ],
            document: .fakeDoc,
            appearanceChance: 0.5,
            lootReward: 2000,
            image: "enemy2" // ДОБАВИТЬ КАРТИНКУ
        ),
        EnemyModel(
            name: "Tax Inspector",
            health: 150,
            level: 5,
            defence: 10,
            attacks: [
                EnemyAttack(type: .physical, damage: 25),
                EnemyAttack(type: .fire, damage: 30, specialEffect: "Горит 3 хода")
            ],
            appearanceChance: 0.3,
            lootReward: 5000,
            image: "enemy3" // МОЖНО ПОВТОРЯТЬ
        ),
        EnemyModel(
            name: "Mafia Boss",
            health: 500,
            level: 10,
            isBoss: true,
            defence: 25,
            relationshipLevel: 0,
            attacks: [
                EnemyAttack(type: .physical, damage: 50),
                EnemyAttack(type: .poison, damage: 20, specialEffect: "Отравление"),
                EnemyAttack(type: .fire, damage: 40, specialEffect: "Пожар")
            ],
            document: .orderToJudge,
            appearanceChance: 0.1,
            lootReward: 50000,
            image: "enemy4" // ДОБАВИТЬ КАРТИНКУ
        )
    ]

    
    init() {
        enemies = baseEnemies
    }
    
    func constrainEnemiesToZone(bounds: CGRect, enemyZoneHeight: CGFloat) {
        let enemyZoneHeightPixels = bounds.height * enemyZoneHeight
        
        for enemy in activeEnemies {
            // Если враг выходит за пределы вражеской зоны, возвращаем его
            if enemy.position.y > enemyZoneHeightPixels {
                enemy.position.y = enemyZoneHeightPixels - 50
            }
            
            // Также ограничиваем по X
            let margin: CGFloat = 50
            enemy.position.x = max(margin, min(bounds.width - margin, enemy.position.x))
            enemy.position.y = max(margin, min(enemyZoneHeightPixels - margin, enemy.position.y))
        }
    }
    
    // Запуск спавна врагов
    func startSpawning(in bounds: CGRect, enemyZoneHeight: CGFloat) {
        stopSpawning() // Останавливаем предыдущий таймер
        
        // Спавним первого врага сразу
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            _ = self.spawnRandomEnemy(in: bounds, enemyZoneHeight: enemyZoneHeight)
        }
        
        // Запускаем таймер спавна
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            _ = self.spawnRandomEnemy(in: bounds, enemyZoneHeight: enemyZoneHeight)
        }
    }
    
    func stopSpawning() {
        spawnTimer?.invalidate()
        spawnTimer = nil
    }
    
    // Появление случайного врага
    func spawnRandomEnemy(in bounds: CGRect, enemyZoneHeight: CGFloat) -> EnemyModel? {
        guard activeEnemies.count < 5 else { return nil }
        
        let roll = Double.random(in: 0...1)
        let available = enemies.filter { !$0.isBoss && roll < $0.appearanceChance }
        
        guard let enemyTemplate = available.randomElement() else {
            return nil
        }
        
        // Генерируем случайную позицию ТОЛЬКО в верхней (вражеской) зоне
        let margin: CGFloat = 50
        let enemyZoneHeightPixels = bounds.height * enemyZoneHeight
        
        // Убедимся, что позиция Y находится в пределах вражеской зоны
        let minY = margin
        let maxY = enemyZoneHeightPixels - margin
        
        // Если макс Y меньше минимального, используем середину зоны
        let positionY = maxY > minY ?
            CGFloat.random(in: minY...maxY) :
            enemyZoneHeightPixels / 2
        
        let position = CGPoint(
            x: CGFloat.random(in: margin...(bounds.width - margin)),
            y: positionY
        )
        
        // Клонируем врага
        let enemy = EnemyModel(
            name: enemyTemplate.name,
            health: enemyTemplate.maxHealth + Int.random(in: -10...10),
            level: enemyTemplate.level,
            isBoss: enemyTemplate.isBoss,
            defence: enemyTemplate.defence + Int.random(in: -2...2),
            relationshipLevel: enemyTemplate.relationshipLevel,
            attacks: enemyTemplate.attacks.map {
                EnemyAttack(
                    type: $0.type,
                    damage: $0.damage + Int.random(in: -3...3),
                    specialEffect: $0.specialEffect
                )
            },
            document: enemyTemplate.document,
            appearanceChance: enemyTemplate.appearanceChance,
            lootReward: enemyTemplate.lootReward + Int.random(in: -20...20),
            image: enemyTemplate.image,
            position: position,
            size: CGSize(width: 80, height: 80)
        )
        
        activeEnemies.append(enemy)
        print("👾 Враг создан в позиции Y: \(position.y), вражеская зона: \(enemyZoneHeightPixels)")
        return enemy
    }
    
    
    // Добавим новый метод в EnemyManager:
    func spawnWaveEnemy(level: Int, in bounds: CGRect, enemyZoneHeight: CGFloat) -> EnemyModel? {
        guard activeEnemies.count < 8 else { return nil } // Увеличим лимит врагов
        
        // Генерируем случайную позицию ТОЛЬКО в верхней (вражеской) зоне
        let margin: CGFloat = 50
        let enemyZoneHeightPixels = bounds.height * enemyZoneHeight
        
        // Убедимся, что позиция Y находится в пределах вражеской зоны
        let minY = margin
        let maxY = enemyZoneHeightPixels - margin
        
        // Если макс Y меньше минимального, используем середину зоны
        let positionY = maxY > minY ?
            CGFloat.random(in: minY...maxY) :
            enemyZoneHeightPixels / 2
        
        let position = CGPoint(
            x: CGFloat.random(in: margin...(bounds.width - margin)),
            y: positionY
        )
        
        // Создаем вора с указанным уровнем
        let health = 50 + (level - 1) * 20
        let defence = 2 + (level - 1)
        let baseDamage = 8 + (level - 1) * 5
        let lootReward = 100 * level
        
        let enemy = EnemyModel(
            name: "Thief Lv.\(level)",
            health: health,
            level: level,
            defence: defence,
            attacks: [EnemyAttack(type: .physical, damage: baseDamage)],
            appearanceChance: 1.0,
            lootReward: lootReward,
            image: "enemy1", // Используем ту же картинку
            position: position,
            size: CGSize(width: 80, height: 80)
        )
        
        activeEnemies.append(enemy)
        print("👾 Вор уровня \(level) создан в позиции Y: \(position.y)")
        return enemy
    }

    // Появление босса
    func spawnBoss(in bounds: CGRect) -> EnemyModel? {
        guard let bossTemplate = enemies.first(where: { $0.isBoss }),
              !bossDefeated else {
            return nil
        }
        
        let position = CGPoint(
            x: bounds.midX,
            y: bounds.midY
        )
        
        let boss = EnemyModel(
            name: bossTemplate.name,
            health: bossTemplate.maxHealth,
            level: bossTemplate.level,
            isBoss: true,
            defence: bossTemplate.defence,
            relationshipLevel: bossTemplate.relationshipLevel,
            attacks: bossTemplate.attacks,
            document: bossTemplate.document,
            appearanceChance: 1.0,
            lootReward: bossTemplate.lootReward,
            image: bossTemplate.image,
            position: position,
            size: CGSize(width: 120, height: 120)
        )
        
        activeEnemies.append(boss)
        return boss
    }
    
    // Удалить поверженного врага
    func removeEnemy(_ enemy: EnemyModel) {
        if let index = activeEnemies.firstIndex(where: { $0.id == enemy.id }) {
            if enemy.isBoss {
                bossDefeated = true
            }
            activeEnemies.remove(at: index)
            print("💀 Враг удален: \(enemy.name)")
        }
    }
    
    // Сохранение/загрузка
    func saveEnemies() {
        var enemiesData: [[String: Any]] = []
        for enemy in enemies {
            enemiesData.append(enemy.toDictionary())
        }
        UserDefaults.standard.set(enemiesData, forKey: "enemies")
        
        var activeEnemiesData: [[String: Any]] = []
        for enemy in activeEnemies {
            activeEnemiesData.append(enemy.toDictionary())
        }
        UserDefaults.standard.set(activeEnemiesData, forKey: "activeEnemies")
        UserDefaults.standard.set(bossDefeated, forKey: "bossDefeated")
    }
    
    func updateEnemies(deltaTime: TimeInterval, bounds: CGRect, enemyZoneHeight: CGFloat) {
        let enemyZoneHeightPixels = bounds.height * enemyZoneHeight
        
        // Ограничиваем врагов в их зоне
        for enemy in activeEnemies {
            // Убеждаемся, что враги остаются в верхней зоне
            if enemy.position.y > enemyZoneHeightPixels - enemy.size.height/2 {
                enemy.position.y = enemyZoneHeightPixels - enemy.size.height/2
            }
            
            enemy.position.y = min(
                enemy.position.y,
                enemyZoneHeightPixels - enemy.size.height / 2
            )
            enemy.position.y = max(
                enemy.size.height / 2,
                enemy.position.y
            )

        }
    }
    
    func loadEnemies() {
        if let enemiesData = UserDefaults.standard.array(forKey: "enemies") as? [[String: Any]] {
            var loadedEnemies: [EnemyModel] = []
            for enemyData in enemiesData {
                if let enemy = EnemyModel.fromDictionary(enemyData) {
                    loadedEnemies.append(enemy)
                }
            }
            enemies = loadedEnemies.isEmpty ? baseEnemies : loadedEnemies
        }
        
        if let activeEnemiesData = UserDefaults.standard.array(forKey: "activeEnemies") as? [[String: Any]] {
            var loadedActiveEnemies: [EnemyModel] = []
            for enemyData in activeEnemiesData {
                if let enemy = EnemyModel.fromDictionary(enemyData) {
                    loadedActiveEnemies.append(enemy)
                }
            }
            activeEnemies = loadedActiveEnemies
        }
        
        bossDefeated = UserDefaults.standard.bool(forKey: "bossDefeated")
    }
}

extension EnemyModel {
    // Количество денег, которое враг крадет за раз
    var stealAmount: Int {
        switch level {
        case 1: return 10     // Было 50
        case 2: return 25     // Было 150
        case 3: return 50     // Было 300
        case 4: return 100    // Было 500
        case 5: return 150    // Было 800
        case 6...10: return level * 30  // Было level * 200
        default: return level * 50      // Было level * 300
        }
    }
}
