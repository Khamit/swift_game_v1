//
//  StarModel.swift
//  Nighty Tales
//
//  Created by Khamit on 19.12.2025.
//
import SwiftUI
import Combine

class StarModel: ObservableObject, Identifiable {
    let id = UUID()
    // Основные свойства звезды
    @Published var position: CGPoint
    @Published var opacity: Double
    @Published var scale: CGFloat
    @Published var rotation: Double
    @Published var isPulsing: Bool
    @Published var isVisible: Bool
    @Published var shouldExplode: Bool
    @Published var level: Int = 1
    
    // НОВЫЕ СВОЙСТВА:
    @Published var baseValue: Int = 1      // Базовая стоимость звезды
    @Published var mergeValue: Int = 5     // Значение при слиянии
    @Published var experience: Int = 0     // Опыт звезды (для будущих улучшений)
    @Published var element: StarElement = .normal // Элемент/тип звезды
    @Published var isSpecial: Bool = false // Особые звезды (золотые, алмазные)
    
    // Визуальные свойства
    @Published var color: Color
    @Published var size: CGSize
    @Published var glowRadius: CGFloat
    @Published var glowColor: Color
    
    // механика: натягивание и запуск
    @Published var velocity: CGPoint = .zero
    @Published var isDragging: Bool = false
    @Published var dragStartPosition: CGPoint = .zero
    @Published var dragCurrentPosition: CGPoint = .zero
    @Published var isInFlight: Bool = false
    @Published var originalSize: CGSize
    @Published var dragScale: CGFloat = 1.0
    
    // Физические параметры
    private let maxVelocity: CGFloat = 1500
    private let minVelocity: CGFloat = 200
    private let friction: CGFloat = 0.98
    private let elasticity: CGFloat = 0.7
    private let dragFactor: CGFloat = 0.1 // Коэффициент уменьшения при натягивании
    private let minDragScale: CGFloat = 0.7
    
    // Анимационные свойства
    private var pulseAnimation: Animation
    private var moveAnimation: Animation
    
    // новые
    // Вычисляемое свойство для текущей стоимости
    var currentValue: Int {
        let levelMultiplier = 1 + (level - 1) * 2
        return baseValue * levelMultiplier
    }
    var damage: Int {
        // Урон по уровням согласно требованиям
        switch level {
        case 1: return 1      // Уровень 1: 1 урон
        case 2: return 20     // Уровень 2: 20 урона
        case 3: return 45     // Уровень 3: 45 урона
        case 4: return 80     // Уровень 4: 80 урона
        case 5: return 125    // Уровень 5: 125 урона
        default:
            // Для уровней выше 5: уровень * 25
            return level * 25
        }
    }
    
    init(
        position: CGPoint = CGPoint(x: 200, y: 400),
        size: CGSize = CGSize(width: 80, height: 80),
        color: Color = .yellow,
        opacity: Double = 1.0,
        scale: CGFloat = 1.0,
        rotation: Double = 0.0,
        isPulsing: Bool = true,
        isVisible: Bool = true,
        glowRadius: CGFloat = 15,
        glowColor: Color = .yellow
    ) {
        self.position = position
        self.size = size
        self.color = color
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.isPulsing = isPulsing
        self.isVisible = isVisible
        self.shouldExplode = false
        self.glowRadius = glowRadius
        self.glowColor = glowColor
        self.originalSize = size
        
        self.pulseAnimation = Animation
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        
        self.moveAnimation = Animation
            .spring(response: 0.6, dampingFraction: 0.6)
    }
    
    // MARK: - Новая механика: Натягивание и запуск
    
    func startDrag(at point: CGPoint) {
        guard !isInFlight else { return }
        
        isDragging = true
        dragStartPosition = point
        dragCurrentPosition = point
        velocity = .zero
        
        // Звезда слегка уменьшается при натягивании
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragScale = minDragScale
            scale = 0.95
        }
    }
    
    func updateDrag(to point: CGPoint) {
        guard isDragging else { return }
        dragCurrentPosition = point
    }
    
    func endDrag() -> (velocity: CGPoint, force: CGFloat) {
        guard isDragging else { return (.zero, 0) }
        
        isDragging = false
        isInFlight = true
        
        // Вычисляем вектор натягивания (от текущей позиции к стартовой)
        let dragVector = CGPoint(
            x: dragStartPosition.x - dragCurrentPosition.x,
            y: dragStartPosition.y - dragCurrentPosition.y
        )
        
        // Ограничиваем максимальную силу
        let distance = sqrt(dragVector.x * dragVector.x + dragVector.y * dragVector.y)
        let maxDistance: CGFloat = 300
        let clampedDistance = min(distance, maxDistance)
        
        // Нормализуем вектор
        let normalizedVector = distance > 0 ? CGPoint(
            x: dragVector.x / distance,
            y: dragVector.y / distance
        ) : .zero
        
        // Вычисляем скорость (чем сильнее натягивание, тем больше скорость)
        let force = clampedDistance / maxDistance
        let speed = minVelocity + (maxVelocity - minVelocity) * force
        
        velocity = CGPoint(
            x: normalizedVector.x * speed,
            y: normalizedVector.y * speed
        )
        
        // Восстанавливаем размер звезды
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragScale = 1.0
            scale = 1.0
        }
        
        return (velocity, force)
    }
    
    func update(deltaTime: CGFloat, bounds: CGRect) {
        guard isInFlight else { return }
        
        // Обновляем позицию на основе скорости
        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime
        
        // Применяем трение
        velocity.x *= friction
        velocity.y *= friction
        
        // Обработка столкновений с границами
        handleBoundaryCollision(bounds: bounds)
        
        // Если скорость очень маленькая, останавливаем звезду
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        if speed < 10 {
            isInFlight = false
            velocity = .zero
        }
        
        // Вращение при движении
        if speed > 50 {
            rotation += velocity.x * deltaTime * 0.1
        }
    }
    
    private func handleBoundaryCollision(bounds: CGRect) {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        
        // Левая граница
        if position.x - halfWidth < 0 {
            position.x = halfWidth
            velocity.x = -velocity.x * elasticity
        }
        
        // Правая граница
        if position.x + halfWidth > bounds.width {
            position.x = bounds.width - halfWidth
            velocity.x = -velocity.x * elasticity
        }
        
        // Верхняя граница
        if position.y - halfHeight < 0 {
            position.y = halfHeight
            velocity.y = -velocity.y * elasticity
        }
        
        // Нижняя граница
        if position.y + halfHeight > bounds.height {
            position.y = bounds.height - halfHeight
            velocity.y = -velocity.y * elasticity
        }
    }
    
    // MARK: - Слияние и столкновения
    
    func canMerge(with other: StarModel) -> Bool {
        // Звезды могут сливаться только если у них одинаковый уровень
        // И не более 5 уровня (кроме случая 5+5 для взрыва)
        return level == other.level
    }

    // Добавим проверку на максимальный уровень
    var isMaxLevel: Bool {
        return level >= 5
    }

    // Добавим индикатор готовности к взрыву
    var isReadyForExplosion: Bool {
        return level == 5
    }
    
    // Метод для слияния (улучшенный)
    func merge(with other: StarModel) -> MergeResult {
        level += 1
        
        // Вычисляем новое значение
        let totalValue = currentValue + other.currentValue
        let newBaseValue = totalValue / 2
        
        // Сохраняем опыт
        experience += 1
        if experience >= 3 && level >= 3 {
            isSpecial = true
        }
        
        changeSize(
            CGSize(
                width: originalSize.width * 1.25,
                height: originalSize.height * 1.25
            )
        )
        
        changeColor(
            Color(
                hue: Double(level) * 0.15,
                saturation: 0.8,
                brightness: 1.0
            )
        )
        
        // Обновляем оригинальный размер
        originalSize = size
        
        return MergeResult(
            newLevel: level,
            valueGained: totalValue,
            isSpecialUpgrade: isSpecial && !other.isSpecial
        )
    }
    
    func intersects(_ other: StarModel) -> Bool {
        let dx = position.x - other.position.x
        let dy = position.y - other.position.y
        let distance = sqrt(dx*dx + dy*dy)
        return distance < (size.width + other.size.width) / 2
    }
    
    // MARK: - Вспомогательные методы
    
    func reset(to position: CGPoint? = nil) {
        if let position = position {
            self.position = position
        }
        
        withAnimation(moveAnimation) {
            opacity = 1.0
            scale = 1.0
            rotation = 0
            isVisible = true
            velocity = .zero
            isInFlight = false
            isDragging = false
            dragScale = 1.0
        }
        
        isPulsing = true
    }
    
    func hide() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            isVisible = false
        }
    }
    
    func show() {
        withAnimation(moveAnimation) {
            opacity = 1
            isVisible = true
        }
    }
    
    func changeColor(_ newColor: Color) {
        withAnimation(.easeInOut(duration: 0.5)) {
            color = newColor
            glowColor = newColor.opacity(0.7)
        }
    }
    
    func changeSize(_ newSize: CGSize) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            size = newSize
        }
    }
}

// Дополнительные структуры
struct MergeResult {
    let newLevel: Int
    let valueGained: Int
    let isSpecialUpgrade: Bool
}

// Типы звезд
enum StarElement {
    case normal
    case fire
    case water
    case earth
    case air
    case light
    case dark
}
