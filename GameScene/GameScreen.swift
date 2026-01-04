import SwiftUI
import Combine

struct GameScreen: View {
    @StateObject private var screenDivider = ScreenDividerModel()
    @StateObject private var gameManager: GameManager
    @StateObject private var fpsCounter = FPSCounter()
    
    @State private var lastUpdateTime: Date?
    @State private var showTowerMenu = false
    @State private var showGameOver = false
    @State private var moneyStealAnimations: [(id: UUID, position: CGPoint, amount: Int)] = []
    @State private var notificationMessage = ""
    @State private var showNotification = false
    
    let timer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    // HUD height (lordekz)
    private let hudHeight: CGFloat = 90
    
    init() {
        _gameManager = StateObject(wrappedValue: GameManager())
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                // ===== HUD (отдельная зона) =====
                HUDView(gameManager: gameManager)
                    .frame(height: hudHeight)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.9),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .zIndex(10)

                // ===== Игровая область =====
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        enemyZoneView(in: geo)
                        dividerView()
                        playerZoneView(in: geo)
                    }

                    // Звезды
                    ForEach(gameManager.stars) {
                        StarView(star: $0)
                    }

                    // Враги
                    ForEach(gameManager.enemyManager.activeEnemies) {
                        EnemyView(enemy: $0)
                    }

                    // Частицы
                    ForEach(gameManager.particleSystem.particles) {
                        ParticleView(particle: $0)
                    }

                    // Анимации кражи денег
                    ForEach(moneyStealAnimations, id: \.id) { animation in
                        MoneyStealAnimationView(
                            position: animation.position,
                            amount: animation.amount
                        )
                    }

                    // FPS (дебаг)
                    FPSView(counter: fpsCounter)

                    // Уведомления
                    if showNotification {
                        MultiplierNotificationView(message: notificationMessage)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .background(Color.black)
            .ignoresSafeArea() // ?? 
            .onAppear {
                setupGame(in: geo)
                fpsCounter.start()
                setupNotifications()
            }
            .onReceive(timer) { currentTime in
                updateGame(currentTime: currentTime, geo: geo)
            }
            .sheet(isPresented: $showTowerMenu) {
                TowerMenuView(gameManager: gameManager)
            }
            .alert("Игра окончена!", isPresented: $showGameOver) {
                Button("Заново", action: resetGame)
                Button("Выход", role: .cancel) {}
            } message: {
                Text("Враги украли все ваши деньги!")
            }
        }
    }

    
    // MARK: - Компоненты зон
    
    private func enemyZoneView(in geo: GeometryProxy) -> some View {
        Color.red.opacity(0.2)
            .frame(height: geo.size.height * gameManager.screenSplit.enemyRatio) // Исправлено: используем gameManager.screenSplit
            .overlay(
                Text("Вражеская территория")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8),
                alignment: .topLeading
            )
    }
    
    private func playerZoneView(in geo: GeometryProxy) -> some View {
        Color.blue.opacity(0.2)
            .frame(height: geo.size.height * gameManager.screenSplit.playerRatio) // Исправлено: используем gameManager.screenSplit
            .overlay(
                Text("Ваша территория")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8),
                alignment: .bottomLeading
            )
    }
    
    private func dividerView() -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.red, .yellow, .green, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .shadow(radius: 5)
    }
    
    // MARK: - Игровая логика
    
    private func setupGame(in geo: GeometryProxy) {
        let gameBounds = CGRect(
            x: 0,
            y: hudHeight,
            width: geo.size.width,
            height: geo.size.height - hudHeight
        )
        gameManager.setupGame(in: gameBounds)
        lastUpdateTime = Date()
    }

    
    private func updateGame(currentTime: Date, geo: GeometryProxy) {
        guard let lastTime = lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime.timeIntervalSince(lastTime)
        
        // Обновление игры
        gameManager.updateGame(
            deltaTime: deltaTime,
            bounds: CGRect(
                x: 0,
                y: hudHeight,
                width: geo.size.width,
                height: geo.size.height - hudHeight
            )
        )
        
        // Обновление системы частиц
        gameManager.particleSystem.update(deltaTime: deltaTime)
        
        // Проверка кражи денег
        gameManager.processMoneySteal()
        
        // Обновление анимаций кражи
         updateMoneyStealAnimations()
        
        lastUpdateTime = currentTime
    }
    
    private func updateMoneyStealAnimations() {
        // Удаляем старые анимации (через 2 секунды)
        moneyStealAnimations.removeAll { animation in
            // Здесь можно добавить логику таймера для каждой анимации
            false // Временно - нужно добавить время создания
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .moneyStolen, object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let amount = userInfo["amount"] as? Int,
               let position = userInfo["position"] as? CGPoint {
                addMoneyStealAnimation(amount: amount, position: position)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .specialMultiplierReached, object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo,
               let multiplier = userInfo["multiplier"] as? Int {
                showMultiplierNotification(multiplier: multiplier)
            }
        }
    }
    
    private func addMoneyStealAnimation(amount: Int, position: CGPoint) {
        let animation = (id: UUID(), position: position, amount: amount)
        moneyStealAnimations.append(animation)
        
        // Удаляем анимацию через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let index = moneyStealAnimations.firstIndex(where: { $0.id == animation.id }) {
                moneyStealAnimations.remove(at: index)
            }
        }
    }
    
    private func showMultiplierNotification(multiplier: Int) {
        notificationMessage = "КОМБО x\(multiplier)!"
        showNotification = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showNotification = false
            }
        }
    }
    
    private func resetGame() {
        gameManager.resetGame()
        moneyStealAnimations.removeAll()
        showGameOver = false
        showNotification = false
        
        // Перенастройка игры
        DispatchQueue.main.async {
            if let geo = UIApplication.shared.windows.first?.bounds {
                gameManager.setupGame(in: geo)
                lastUpdateTime = Date()
            }
        }
    }
// MARK: - Остальные View остаются без изменений
    
    private func getGeometry() -> GeometryProxy? {
        // Этот метод нужно реализовать через GeometryReader
        return nil
    }
}

struct EnemyView: View {
    @ObservedObject var enemy: EnemyModel

    var body: some View {
        ZStack {
            Image(enemy.image)
                .resizable()
                .scaledToFit()
                .frame(width: enemy.size.width, height: enemy.size.height)
                .position(enemy.position)
                .opacity(enemy.opacity)

            // Имя
            Text(enemy.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .position(x: enemy.position.x,
                          y: enemy.position.y - enemy.size.height / 2 - 14)

            // HP
            HealthBarView(
                currentHealth: enemy.health,
                maxHealth: enemy.maxHealth,
                width: enemy.size.width
            )
            .position(x: enemy.position.x,
                      y: enemy.position.y + enemy.size.height / 2 + 10)
        }
    }
}


struct HealthBarView: View {
    let currentHealth: Int
    let maxHealth: Int
    let width: CGFloat
    
    private var healthPercentage: CGFloat {
        CGFloat(currentHealth) / CGFloat(maxHealth)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Фон
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .frame(width: width, height: 8)
                .cornerRadius(4)
            
            // Здоровье
            Rectangle()
                .fill(
                    healthPercentage > 0.5 ? .green :
                    healthPercentage > 0.25 ? .yellow : .red
                )
                .frame(width: width * healthPercentage, height: 6)
                .cornerRadius(3)
                .padding(1)
        }
    }
}

struct HUDView: View {
    @ObservedObject var gameManager: GameManager

    var body: some View {
        HStack(spacing: 16) {

            // ===== ЛЕВО: СЧЕТ + ДОХОД =====
            VStack(alignment: .leading, spacing: 6) {
                Text("Счет: \(gameManager.player.score)")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.yellow)
                    Text("\(gameManager.player.currency)$")
                        .foregroundColor(.white)
                }

                Text("+\(gameManager.player.totalMoneyEarned)/с")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Spacer()

            // ===== ЦЕНТР: ВОЛНА + ТАЙМЕР =====
            VStack(spacing: 4) {
                Text("ВОЛНА \(gameManager.currentWave)")
                    .font(.caption)
                    .foregroundColor(.white)

                ProgressView(value: Double(gameManager.timeToNextWave), total: 10)
                    .progressViewStyle(.linear)
                    .tint(.orange)
                    .frame(width: 80)

                Text("\(gameManager.timeToNextWave)с")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            // ===== УГРОЗА =====
            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(threatColor)

                ProgressView(value: gameManager.threatLevel)
                    .progressViewStyle(.linear)
                    .tint(threatColor)
                    .frame(width: 60)
            }

            Spacer()

            // ===== БАФФЫ =====
            HStack(spacing: 6) {
                ForEach(gameManager.activeBuffs) { buff in
                    VStack {
                        Image(systemName: buff.icon)
                        Text("\(buff.remainingTime)s")
                            .font(.caption2)
                    }
                    .foregroundColor(.cyan)
                }
            }

            Spacer()

            // ===== СКОРОСТЬ =====
            HStack(spacing: 8) {
                speedButton("1x", scale: 1.0)
                speedButton("2x", scale: 2.0)
                speedButton("4x", scale: 4.0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
    }

    private var threatColor: Color {
        switch gameManager.threatLevel {
        case 0..<0.4: return .green
        case 0..<0.7: return .yellow
        default: return .red
        }
    }

    private func speedButton(_ title: String, scale: Double) -> some View {
        Button {
            gameManager.setTimeScale(scale)
        } label: {
            Text(title)
                .font(.caption)
                .padding(6)
                .background(
                    gameManager.timeScale == scale
                    ? Color.blue
                    : Color.gray.opacity(0.4)
                )
                .cornerRadius(6)
                .foregroundColor(.white)
        }
    }
}


struct TowerMenuView: View {
    @ObservedObject var gameManager: GameManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(gameManager.player.towers.indices, id: \.self) { index in
                        TowerCardView(
                            tower: gameManager.player.towers[index],
                            index: index,
                            gameManager: gameManager
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Башни")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TowerCardView: View {
    @ObservedObject var tower: TowerModel
    let index: Int
    @ObservedObject var gameManager: GameManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Иконка и уровень
            ZStack {
                Circle()
                    .fill(tower.color.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                VStack {
                    Image(systemName: tower.icon)
                        .font(.system(size: 30))
                        .foregroundColor(tower.color)
                    
                    Text("Ур. \(tower.level)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            // Информация
            VStack(spacing: 4) {
                Text(tower.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "dollarsign.circle")
                    Text("\(tower.money)$/цикл")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "clock")
                    Text(String(format: "%.1fс", tower.productionSpeed))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Прогресс-бар
            if tower.isActive {
                ProgressView(value: tower.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: tower.color))
                    .frame(height: 4)
                    .padding(.horizontal)
            }
            
            // Кнопки действий
            if !tower.isActive {
                Button(action: {
                    if gameManager.player.purchaseTower(at: index) {
                        // Успешная покупка
                    }
                }) {
                    Text("Купить: \(tower.purchaseCost)$")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            gameManager.player.canPurchaseTower(at: index) ?
                            Color.green : Color.gray
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!gameManager.player.canPurchaseTower(at: index))
            } else {
                Button(action: {
                    if gameManager.player.upgradeTower(at: index) {
                        // Успешное улучшение
                    }
                }) {
                    Text("Улучшить: \(tower.upgradeCost)$")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            gameManager.player.canUpgradeTower(at: index) ?
                            Color.blue : Color.gray
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!gameManager.player.canUpgradeTower(at: index))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }
}

struct MultiplierNotificationView: View {
    let message: String
    @State private var scale = 0.5
    @State private var opacity = 0.0
    
    var body: some View {
        Text(message)
            .font(.system(size: 32, weight: .black, design: .rounded))
            .overlay(
                LinearGradient(
                    colors: [.yellow, .orange, .red],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .mask(
                Text(message)
                    .font(.system(size: 32, weight: .black, design: .rounded))
            )
            .shadow(color: .black, radius: 5)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    scale = 1.2
                    opacity = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scale = 1.0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        opacity = 0.0
                        scale = 0.5
                    }
                }
            }
    }
}

// MARK: - Превью

struct GameScreen_Previews: PreviewProvider {
    static var previews: some View {
        GameScreen()
            .preferredColorScheme(.dark)
    }
}
