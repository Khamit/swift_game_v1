//
//  TowerModel.swift
//  Nighty Tales
//
//  Created by Khamit on 21.12.2025.
//

import SwiftUI
import Combine

final class TowerModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var icon: String
    @Published var color: Color
    @Published var baseMoney: Int
    @Published var money: Int
    @Published var productionSpeed: TimeInterval
    @Published var isActive: Bool
    @Published var level: Int
    @Published var upgradeCost: Int
    @Published var purchaseCost: Int
    @Published var lastProductionTime: Date
    @Published var progress: Double = 0.0
    
    // Максимальный уровень
    private let maxLevel: Int = 99
    
    // Стоимость улучшения увеличивается с уровнем
    private let upgradeCostMultiplier = 1.5
    
    init(
        name: String = "Basic",
        icon: String = "house.fill",
        color: Color = .blue,
        baseMoney: Int = 2,
        productionSpeed: TimeInterval = 5.0,
        isActive: Bool = false,
        level: Int = 1,
        purchaseCost: Int = 100
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.baseMoney = baseMoney
        self.money = baseMoney
        self.productionSpeed = productionSpeed
        self.isActive = isActive
        self.level = level
        self.upgradeCost = Int(Double(baseMoney * level) * 1.5)
        self.purchaseCost = purchaseCost
        self.lastProductionTime = Date()
    }
    
    // Обновляет производство денег
    func updateProduction(currentTime: Date, moneyMultiplier: Double = 1.0, speedMultiplier: Double = 1.0) -> Int {
        guard isActive else { return 0 }
        
        let timeSinceLastProduction = currentTime.timeIntervalSince(lastProductionTime)
        let effectiveSpeed = productionSpeed / speedMultiplier
        
        // Обновляем прогресс-бар
        progress = min(timeSinceLastProduction / effectiveSpeed, 1.0)
        
        // Если прошло достаточно времени, производим деньги
        if timeSinceLastProduction >= effectiveSpeed {
            lastProductionTime = currentTime
            progress = 0.0
            
            // Рассчитываем производство с учетом множителей
            let production = Int(Double(money) * moneyMultiplier)
            return production
        }
        
        return 0
    }
    
    // Улучшение башни
    func upgrade() -> Bool {
        guard level < maxLevel else { return false }
        
        level += 1
        money = baseMoney * level
        productionSpeed = max(1.0, productionSpeed * 0.95) // Уменьшаем время производства на 5%
        upgradeCost = Int(Double(upgradeCost) * upgradeCostMultiplier)
        
        return true
    }
    
    // Активация (покупка) башни
    func activate() {
        isActive = true
        lastProductionTime = Date()
    }
    
    // Сброс башни
    func reset() {
        level = 1
        money = baseMoney
        productionSpeed = 5.0
        upgradeCost = Int(Double(baseMoney * level) * 1.5)
        isActive = false
        progress = 0.0
    }
    
    // Получение данных для отображения
    func getDisplayInfo() -> (name: String, income: String, speed: String, level: String) {
        let income = "\(money)$"
        let speed = String(format: "%.1fс", productionSpeed)
        let levelStr = "Ур. \(level)"
        
        return (name, income, speed, levelStr)
    }
    
    // Для Firestore
    func toDictionary() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "level": level,
            "isActive": isActive,
            "moneyPerCycle": money,
            "productionSpeed": productionSpeed,
            "lastProduction": lastProductionTime
        ]
    }
}

// Перечисление типов башен
enum TowerType: CaseIterable {
    case basic
    case fast
    case rich
    case mega
    case ultimate
    
    var model: TowerModel {
        switch self {
        case .basic:
            return TowerModel(
                name: "Basic Tower",
                icon: "house.fill",
                color: .blue,
                baseMoney: 2,
                productionSpeed: 5.0,
                purchaseCost: 100
            )
        case .fast:
            return TowerModel(
                name: "Fast Tower",
                icon: "bolt.horizontal.fill",
                color: .green,
                baseMoney: 1,
                productionSpeed: 2.0,
                purchaseCost: 250
            )
        case .rich:
            return TowerModel(
                name: "Golden Tower",
                icon: "dollarsign.circle.fill",
                color: .yellow,
                baseMoney: 5,
                productionSpeed: 8.0,
                purchaseCost: 500
            )
        case .mega:
            return TowerModel(
                name: "Mega Tower",
                icon: "crown.fill",
                color: .purple,
                baseMoney: 10,
                productionSpeed: 10.0,
                purchaseCost: 1000
            )
        case .ultimate:
            return TowerModel(
                name: "Ultimate Tower",
                icon: "star.circle.fill",
                color: .orange,
                baseMoney: 20,
                productionSpeed: 15.0,
                purchaseCost: 2000
            )
        }
    }
}
