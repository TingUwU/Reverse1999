import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - 0. 背景音樂音效管理器 (BGM Manager)
final class BGMManager {
    static let shared = BGMManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying: Bool = false
    
    private init() {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }
    
    /// 播放單一背景音樂，若已在播放中則持續播放不中斷
    func playBGM(named name: String = "bgm") {
        guard !isPlaying else { return }
        
        let extensions = ["mp3", "m4a", "wav"]
        var soundURL: URL?
        
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                soundURL = url
                break
            }
        }
        
        guard let url = soundURL else {
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // 無限循環播放
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("無法播放音樂: \(error.localizedDescription)")
        }
    }
    
    func stopBGM() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
}

// MARK: - 1. 遊戲流程狀態列舉
enum GamePhase {
    case home        // 登入/首頁封面
    case preparation // 戰前編隊
    case battle      // 戰鬥主畫面
    case victory     // 戰鬥勝利結算
}

// MARK: - 2. 資料模型：神秘學家與技能卡牌
struct Arcanist: Identifiable {
    let id = UUID()
    let name: String
    let englishName: String
    let afflatusIcon: String
    let portraitImage: String  // 戰前編隊大圖
    let battleImage: String    // 戰鬥場上小人圖 (對應帶有 __小 的圖檔)
    let color: Color
    var hp: Int
    let maxHP: Int
}

struct SkillCard: Identifiable, Equatable {
    let id = UUID()
    let ownerName: String
    let title: String
    let subtitle: String
    let tag: String
    let stars: Int
    let damage: Int
    let cardImage: String
    let icon: String
    let cardColor: Color
}

// MARK: - 3. 主視圖
struct ContentView: View {
    
    @State private var gamePhase: GamePhase = .home
    @State private var currentRound: Int = 1
    @State private var maxRounds: Int = 20
    @State private var moxie: Int = 20
    
    // 首頁圖片名稱 (請將截圖加入 Assets 並命名為「首頁」)
    let homeCoverImageName = "首頁"
    
    // 敵方狀態與圖片名稱 (已對應附圖中的「重塑之手」與「小怪」)
    @State private var bossHP: Int = 35000
    @State private var bossMaxHP: Int = 35000
    @State private var minion1HP: Int = 8000
    @State private var minion2HP: Int = 8000
    let bossImageName = "重塑之手"
    let minionImageName = "小怪"
    
    // 由左到右：貝麗爾、伊索爾德 (Isolde)、蝴蝶、瑪爾莎
    @State private var team: [Arcanist] = [
        Arcanist(name: "貝麗爾", englishName: "BERYL", afflatusIcon: "sparkles", portraitImage: "貝麗爾", battleImage: "貝麗爾＿小", color: Color(red: 0.35, green: 0.55, blue: 0.65), hp: 9200, maxHP: 9200),
        Arcanist(name: "伊索爾德", englishName: "ISOLDE", afflatusIcon: "brain.head.profile", portraitImage: "142d", battleImage: "142d＿小", color: Color(red: 0.65, green: 0.50, blue: 0.35), hp: 8800, maxHP: 8800),
        Arcanist(name: "蝴蝶", englishName: "BUTTERFLY", afflatusIcon: "leaf.fill", portraitImage: "蝴蝶", battleImage: "蝴蝶＿小", color: Color(red: 0.45, green: 0.65, blue: 0.45), hp: 8500, maxHP: 8500),
        Arcanist(name: "瑪爾莎", englishName: "MARTHA", afflatusIcon: "flame.fill", portraitImage: "瑪爾莎", battleImage: "瑪爾莎＿小", color: Color(red: 0.75, green: 0.35, blue: 0.35), hp: 9500, maxHP: 9500)
    ]
    
    @State private var actionSlots: [SkillCard] = []
    @State private var handCards: [SkillCard] = []
    @State private var hoveredCard: SkillCard? = nil
    
    @State private var isExecutingTurn: Bool = false
    @State private var teamAttackOffset: CGFloat = 0
    @State private var enemyAttackOffset: CGFloat = 0
    @State private var enemyHitShake: CGFloat = 0
    
    @State private var showEnemyDamageText: Bool = false
    @State private var enemyDamageString: String = ""
    @State private var showTeamHealText: Bool = false
    @State private var teamFloatString: String = ""
    @State private var isTeamFloatHeal: Bool = true
    
    @State private var showUltimateCutIn: Bool = false
    @State private var ultimateCard: SkillCard? = nil
    
    let vintageGold = Color(red: 0.82, green: 0.71, blue: 0.48)
    let actionOrange = Color(red: 0.78, green: 0.38, blue: 0.18)
    let darkBg = Color(red: 0.07, green: 0.08, blue: 0.11)
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                switch gamePhase {
                case .home:
                    homeView(size: geo.size)
                        .transition(.opacity)
                case .preparation:
                    preparationView(size: geo.size)
                        .transition(.opacity)
                case .battle:
                    battleView(size: geo.size)
                        .transition(.opacity)
                case .victory:
                    victoryView(size: geo.size)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(darkBg.ignoresSafeArea())
        .onAppear {
            if handCards.isEmpty {
                generateHandCards()
            }
            BGMManager.shared.playBGM(named: "bgm")
        }
    }
}

// MARK: - 3.5. 畫面〇：登入首頁畫面 (點擊跳轉戰前編隊)
extension ContentView {
    private func homeView(size: CGSize) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.5)) {
                gamePhase = .preparation
            }
        } label: {
            ZStack {
                Image(homeCoverImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. 畫面一：戰前編隊畫面
extension ContentView {
    private func preparationView(size: CGSize) -> some View {
        let isCompact = size.width < 700 || size.height < 380
        let slotHeight = min(size.height * 0.56, 240)
        
        return ZStack {
            RadialGradient(
                colors: [Color(red: 0.18, green: 0.20, blue: 0.25), darkBg],
                center: .top, startRadius: 30, endRadius: size.width * 0.6
            )
            .ignoresSafeArea()
            
            VStack(spacing: isCompact ? 6 : 14) {
                HStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            gamePhase = .home
                        }
                    } label: {
                        Image(systemName: "arrowtriangle.left")
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "square.grid.2x2")
                    Image(systemName: "exclamationmark.diamond")
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .foregroundColor(vintageGold)
                        Text("17小時 203")
                            .font(.system(size: 12, design: .serif))
                        Image(systemName: "plus")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.5))
                    .border(vintageGold.opacity(0.4), width: 1)
                }
                .font(.system(size: isCompact ? 13 : 15))
                .foregroundColor(.white.opacity(0.85))
                
                Spacer(minLength: 2)
                
                HStack(alignment: .center, spacing: size.width * 0.025) {
                    VStack(alignment: .leading, spacing: isCompact ? 6 : 12) {
                        HStack {
                            Text("▸ 目標")
                                .font(.system(size: isCompact ? 14 : 16, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "sparkles")
                                .foregroundColor(actionOrange)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Label("擊敗全部敵人", systemImage: "sparkle")
                            Label("12回合內勝利", systemImage: "sparkle")
                        }
                        .font(.system(size: isCompact ? 12 : 14, design: .serif))
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(isCompact ? 8 : 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.45))
                        
                        Text("▸ 敵人 🔍")
                            .font(.system(size: isCompact ? 14 : 16, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        
                        // 戰前編隊左下角同步顯示「重塑之手」與「小怪」預覽縮圖
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4).fill(Color.purple.opacity(0.3))
                                if assetImageExists(named: bossImageName) {
                                    Image(bossImageName)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipped()
                                        .cornerRadius(4)
                                } else {
                                    Image(systemName: "crown.fill").foregroundColor(.purple)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.purple.opacity(0.6), lineWidth: 1))
                            
                            HStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.purple.opacity(0.3))
                                    if assetImageExists(named: minionImageName) {
                                        Image(minionImageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipped()
                                            .cornerRadius(4)
                                    } else {
                                        Image(systemName: "person.fill").foregroundColor(.purple)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.purple.opacity(0.6), lineWidth: 1))
                                
                                Text("x2").font(.caption2).foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("推薦等級：洞悉二20級")
                            Text("推薦靈感：無")
                        }
                        .font(.system(size: 11, design: .serif))
                        .minimumScaleFactor(0.8)
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(width: size.width * 0.27)
                    
                    HStack(spacing: size.width * 0.015) {
                        ForEach(0..<4, id: \.self) { index in
                            let member = team[index]
                            Button {
                                withAnimation(.spring()) {
                                    let nextIndex = (index + 1) % team.count
                                    team.swapAt(index, nextIndex)
                                }
                            } label: {
                                GeometryReader { cardGeo in
                                    ZStack {
                                        LinearGradient(
                                            colors: [Color.black.opacity(0.7), member.color.opacity(0.35), Color.black.opacity(0.85)],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                        
                                        if assetImageExists(named: member.portraitImage) {
                                            Image(member.portraitImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: cardGeo.size.width, height: cardGeo.size.height)
                                                .clipped()
                                            
                                            LinearGradient(
                                                colors: [Color.black.opacity(0.65), Color.clear, Color.black.opacity(0.85)],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        }
                                        
                                        VStack(spacing: isCompact ? 6 : 10) {
                                            HStack {
                                                Text("\(index + 1)")
                                                    .font(.system(size: isCompact ? 22 : 28, weight: .light, design: .serif))
                                                    .foregroundColor(.white.opacity(0.75))
                                                    .shadow(color: .black, radius: 3)
                                                Spacer()
                                                Image(systemName: member.afflatusIcon)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(vintageGold)
                                                    .padding(5)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.top, 6)
                                            
                                            Spacer()
                                            
                                            if !assetImageExists(named: member.portraitImage) {
                                                ZStack {
                                                    Circle()
                                                        .stroke(vintageGold.opacity(0.6), lineWidth: 1.5)
                                                        .frame(width: isCompact ? 34 : 44, height: isCompact ? 34 : 44)
                                                    Image(systemName: "person.crop.rectangle.fill")
                                                        .font(.system(size: isCompact ? 15 : 18))
                                                        .foregroundColor(vintageGold)
                                                }
                                                Text("請放入:\n\(member.portraitImage)")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.white.opacity(0.45))
                                                Spacer()
                                            }
                                            
                                            VStack(spacing: 2) {
                                                Text(member.name)
                                                    .font(.system(size: isCompact ? 13 : 15, weight: .bold, design: .serif))
                                                    .foregroundColor(.white)
                                                    .shadow(color: .black, radius: 2)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.7)
                                                
                                                Text("點擊換位")
                                                    .font(.system(size: 9, design: .serif))
                                                    .foregroundColor(vintageGold.opacity(0.85))
                                            }
                                            .padding(.bottom, 8)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: slotHeight)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(vintageGold.opacity(0.5), lineWidth: 1)
                                )
                                .offset(y: index % 2 == 1 ? (isCompact ? 8 : 14) : (isCompact ? -6 : -10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer(minLength: 2)
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass.bottomhalf.filled")
                            .padding(6)
                            .background(Color.white)
                            .foregroundColor(.black)
                        Text("成員佇列 8")
                            .font(.system(size: isCompact ? 12 : 14, weight: .medium, design: .serif))
                            .foregroundColor(.white)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing, 12)
                    .background(Color.white.opacity(0.12))
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            resetBattle()
                            gamePhase = .battle
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "record.circle")
                            Text("-20")
                            Text("開始行動")
                                .font(.system(size: isCompact ? 14 : 16, weight: .bold, design: .serif))
                        }
                        .padding(.horizontal, isCompact ? 18 : 26)
                        .padding(.vertical, isCompact ? 8 : 11)
                        .background(actionOrange)
                        .foregroundColor(.black)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, max(size.width * 0.03, 16))
            .padding(.vertical, max(size.height * 0.03, 10))
        }
    }
}

// MARK: - 5. 畫面二：橫向戰鬥主畫面 (左側怪物呈現「重塑之手」與「小怪」圖片)
extension ContentView {
    private func battleView(size: CGSize) -> some View {
        let isCompact = size.width < 700 || size.height < 380
        let unitHeight = min(size.height * 0.34, 135)
        let bossHeight = min(size.height * 0.46, 190)
        
        return ZStack {
            ZStack {
                RadialGradient(
                    colors: [Color(red: 0.20, green: 0.16, blue: 0.28), darkBg],
                    center: .center, startRadius: 30, endRadius: size.width * 0.55
                )
                .ignoresSafeArea()
                
                Ellipse()
                    .stroke(
                        LinearGradient(colors: [.purple.opacity(0.7), .blue.opacity(0.4), .purple.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2.5
                    )
                    .frame(width: size.width * 0.82, height: size.height * 0.24)
                    .offset(y: size.height * 0.08)
                    .blur(radius: 1)
            }
            
            HStack(spacing: size.width * 0.02) {
                
                // MARK: 左側敵方陣營 (呈現「重塑之手」與 2 隻「小怪」圖片)
                ZStack {
                    HStack(alignment: .bottom, spacing: size.width * 0.012) {
                        // 高大 Boss：重塑之手
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.circle.fill").foregroundColor(.purple)
                                Rectangle().fill(Color.orange).frame(width: 50, height: 4)
                            }
                            .font(.caption2)
                            
                            ZStack(alignment: .bottom) {
                                if assetImageExists(named: bossImageName) {
                                    Image(bossImageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 120, maxHeight: bossHeight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                                        )
                                        .shadow(color: .red.opacity(0.5), radius: 8)
                                    
                                    // 底部半透明名稱與血量標籤
                                    VStack(spacing: 1) {
                                        Text("重塑之手")
                                            .font(.system(size: 11, weight: .bold, design: .serif))
                                            .foregroundColor(.white)
                                        Text("HP: \(bossHP)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.red.opacity(0.95))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(LinearGradient(colors: [Color.red.opacity(0.35), Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.6), lineWidth: 1.5))
                                    
                                    VStack(spacing: 6) {
                                        Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                                            .font(.system(size: isCompact ? 28 : 38))
                                            .foregroundColor(.red)
                                        Text("重塑之手")
                                            .font(.system(size: isCompact ? 11 : 13, weight: .bold, design: .serif))
                                            .foregroundColor(.white)
                                        Text("HP: \(bossHP)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.red.opacity(0.9))
                                        Text("請放入: \(bossImageName)")
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                    .padding(4)
                                }
                            }
                            .frame(maxWidth: 120, maxHeight: bossHeight)
                        }
                        
                        // 兩隻小怪 (使用「小怪」圖片)
                        minionView(name: "小怪 A", hp: minion1HP, height: unitHeight * 0.85)
                        minionView(name: "小怪 B", hp: minion2HP, height: unitHeight * 0.85)
                    }
                    .offset(x: enemyAttackOffset + enemyHitShake)
                    
                    if showEnemyDamageText {
                        VStack(spacing: 2) {
                            Text("✦ CRITICAL ✦")
                                .font(.system(size: 11, weight: .black, design: .serif))
                                .foregroundColor(vintageGold)
                            Text(enemyDamageString)
                                .font(.system(size: isCompact ? 22 : 28, weight: .heavy, design: .serif))
                                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.35))
                                .shadow(color: .black, radius: 4)
                        }
                        .offset(y: -bossHeight * 0.55)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // MARK: 右側我方 4 人小隊
                ZStack {
                    HStack(alignment: .bottom, spacing: size.width * 0.01) {
                        ForEach(team) { member in
                            VStack(spacing: 3) {
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up.forward.square.fill").foregroundColor(.cyan)
                                    Image(systemName: "shield.lefthalf.filled").foregroundColor(.yellow)
                                    Image(systemName: "sparkles").foregroundColor(.orange)
                                }
                                .font(.system(size: 8))
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(height: 3)
                                    .padding(.horizontal, 4)
                                
                                ZStack {
                                    if assetImageExists(named: member.battleImage) {
                                        Image(member.battleImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 72, maxHeight: unitHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .shadow(color: member.color.opacity(0.6), radius: 6)
                                    } else {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(LinearGradient(colors: [member.color.opacity(0.55), Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(vintageGold.opacity(0.7), lineWidth: 1))
                                        
                                        VStack(spacing: 4) {
                                            Image(systemName: member.afflatusIcon)
                                                .font(.system(size: isCompact ? 16 : 22))
                                                .foregroundColor(vintageGold)
                                            Text(member.name)
                                                .font(.system(size: 11, weight: .bold, design: .serif))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.6)
                                            Text(member.battleImage)
                                                .font(.system(size: 8, design: .monospaced))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        .padding(2)
                                    }
                                }
                                .frame(maxWidth: 72, maxHeight: unitHeight)
                                
                                Ellipse()
                                    .stroke(member.color, lineWidth: 2)
                                    .frame(height: 10)
                            }
                        }
                    }
                    .offset(x: teamAttackOffset)
                    
                    if showTeamHealText {
                        Text(teamFloatString)
                            .font(.system(size: isCompact ? 20 : 24, weight: .bold, design: .serif))
                            .foregroundColor(isTeamFloatHeal ? .green : .red)
                            .shadow(color: .black, radius: 4)
                            .offset(y: -unitHeight * 0.65)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity)
                
                ZStack {
                    Rectangle()
                        .fill(Color.cyan.opacity(0.25))
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(45))
                        .overlay(Rectangle().stroke(Color.cyan, lineWidth: 1.5).rotationEffect(.degrees(45)))
                    Text("\(moxie)")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 8)
            }
            .padding(.horizontal, max(size.width * 0.02, 12))
            .padding(.bottom, size.height * 0.12)
            
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text("輪次: 1/1")
                            Text("回合: \(currentRound)/\(maxRounds)")
                        }
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "infinity.circle.fill")
                                .foregroundColor(.red)
                            Text("以血求生")
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.black.opacity(0.7))
                                    Rectangle()
                                        .fill(LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: barGeo.size.width * CGFloat(bossHP) / CGFloat(bossMaxHP))
                                        .animation(.easeInOut, value: bossHP)
                                }
                            }
                            .frame(width: min(size.width * 0.38, 320), height: 8)
                            .border(vintageGold.opacity(0.5), width: 1)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { slotIndex in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.black.opacity(0.45))
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(vintageGold.opacity(0.35), lineWidth: 1))
                                    
                                    if slotIndex < actionSlots.count {
                                        let slottedCard = actionSlots[slotIndex]
                                        VStack(spacing: 2) {
                                            Image(systemName: slottedCard.icon)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                            Text(slottedCard.title)
                                                .font(.system(size: 8, weight: .bold, design: .serif))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                        }
                                        .padding(2)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(slottedCard.cardColor.opacity(0.85))
                                        .cornerRadius(4)
                                        .onTapGesture {
                                            guard !isExecutingTurn else { return }
                                            withAnimation {
                                                let removed = actionSlots.remove(at: slotIndex)
                                                handCards.append(removed)
                                            }
                                        }
                                    } else {
                                        Image(systemName: "eye.trianglebadge.exclamationmark")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.18))
                                    }
                                }
                                .frame(width: isCompact ? 42 : 50, height: isCompact ? 54 : 66)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button {
                            withAnimation { gamePhase = .preparation }
                        } label: {
                            diamondIcon(systemName: "person.2.crop.square.stack")
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            resetBattle()
                        } label: {
                            diamondIcon(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, max(size.width * 0.025, 14))
                .padding(.top, 8)
                
                Spacer()
                
                if let card = hoveredCard {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(card.title)
                                .font(.system(size: 13, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Text(card.ownerName)
                                .font(.system(size: 10, design: .serif))
                                .foregroundColor(vintageGold)
                        }
                        Text(card.subtitle)
                            .font(.system(size: 11, design: .serif))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(8)
                    .frame(width: min(size.width * 0.45, 280))
                    .background(Color.black.opacity(0.85))
                    .border(vintageGold.opacity(0.6), width: 1)
                    .transition(.opacity)
                }
                
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(vintageGold.opacity(0.7), lineWidth: 1.5)
                                .frame(width: 28, height: 28)
                            Text("\(moxie)")
                                .font(.system(size: 11, weight: .bold, design: .serif))
                                .foregroundColor(vintageGold)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.path")
                            Image(systemName: "circle.dotted")
                            Image(systemName: "triangle")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(vintageGold.opacity(0.8))
                        .padding(5)
                        .background(Color.black.opacity(0.6))
                    }
                    
                    Spacer(minLength: 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(handCards) { card in
                                Button {
                                    selectCard(card)
                                } label: {
                                    cardItemView(card: card, isCompact: isCompact)
                                }
                                .buttonStyle(.plain)
                                .disabled(isExecutingTurn)
                            }
                        }
                    }
                    
                    if !actionSlots.isEmpty && !isExecutingTurn {
                        Button {
                            executeBattleTurn()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 15))
                                Text("出擊\n(\(actionSlots.count)/4)")
                                    .font(.system(size: 10, weight: .bold, design: .serif))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: isCompact ? 46 : 54, height: isCompact ? 84 : 98)
                            .background(actionOrange)
                            .foregroundColor(.black)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, max(size.width * 0.025, 14))
                .padding(.bottom, 6)
            }
            
            if showUltimateCutIn, let ult = ultimateCard {
                ZStack {
                    Color.black.opacity(0.88).ignoresSafeArea()
                    RadialGradient(
                        colors: [ult.cardColor.opacity(0.8), .clear],
                        center: .center, startRadius: 20, endRadius: size.width * 0.5
                    )
                    .ignoresSafeArea()
                    
                    if let caster = team.first(where: { $0.name == ult.ownerName }),
                       assetImageExists(named: caster.portraitImage) {
                        Image(caster.portraitImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: size.height * 0.85)
                            .opacity(0.45)
                            .offset(x: -size.width * 0.18)
                    }
                    
                    VStack(spacing: 12) {
                        Image(systemName: ult.icon)
                            .font(.system(size: isCompact ? 50 : 68))
                            .foregroundColor(vintageGold)
                            .shadow(color: ult.cardColor, radius: 16)
                        
                        Text("✦ 至終的儀式 ✦")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .tracking(6)
                            .foregroundColor(vintageGold)
                        
                        Text(ult.title)
                            .font(.system(size: isCompact ? 26 : 34, weight: .heavy, design: .serif))
                            .foregroundColor(.white)
                        
                        Text(ult.subtitle)
                            .font(.system(size: 13, design: .serif))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.08)))
            }
        }
    }
    
    // 小怪視圖元件 (顯示「小怪」圖片 + 底部血量條)
    private func minionView(name: String, hp: Int, height: CGFloat) -> some View {
        VStack(spacing: 3) {
            Rectangle()
                .fill(hp > 0 ? Color.orange : Color.gray.opacity(0.3))
                .frame(width: 40, height: 3)
            
            ZStack(alignment: .bottom) {
                if assetImageExists(named: minionImageName) {
                    Image(minionImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 64, maxHeight: height)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text(hp > 0 ? "\(hp)" : "擊破")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(hp > 0 ? .white : .red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(hp > 0 ? 0.65 : 0.25))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    
                    VStack(spacing: 4) {
                        Image(systemName: hp > 0 ? "person.bust.fill" : "xmark.circle")
                            .font(.system(size: 18))
                            .foregroundColor(hp > 0 ? .white.opacity(0.8) : .gray)
                        Text(hp > 0 ? "\(hp)" : "擊破")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(2)
                }
            }
            .frame(maxWidth: 64, maxHeight: height)
        }
        .opacity(hp > 0 ? 1.0 : 0.35)
    }
    
    private func cardItemView(card: SkillCard, isCompact: Bool) -> some View {
        let cardW: CGFloat = isCompact ? 62 : 72
        let cardH: CGFloat = isCompact ? 64 : 74
        
        return VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(0..<card.stars, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.8))
            
            ZStack {
                LinearGradient(
                    colors: [card.cardColor.opacity(0.85), Color.black.opacity(0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                
                if assetImageExists(named: card.cardImage) {
                    Image(card.cardImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardW, height: cardH)
                        .clipped()
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: card.icon)
                            .font(.system(size: isCompact ? 20 : 24))
                            .foregroundColor(.white)
                        Text(card.title)
                            .font(.system(size: 10, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(width: cardW, height: cardH)
            
            Text(card.tag)
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .frame(width: cardW, height: 16)
                .background(Color.black.opacity(0.92))
                .foregroundColor(
                    card.tag == "Buff" ? .cyan :
                    card.tag == "Debuff" ? .purple :
                    card.tag == "Ultimate" ? vintageGold : .orange
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(card.tag == "Ultimate" ? vintageGold : Color.white.opacity(0.35), lineWidth: card.tag == "Ultimate" ? 1.5 : 1)
        )
        .cornerRadius(4)
    }
    
    private func diamondIcon(systemName: String) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(45))
                .overlay(Rectangle().stroke(Color.white.opacity(0.5), lineWidth: 1).rotationEffect(.degrees(45)))
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 6. 畫面三：戰鬥勝利結算畫面 (修復人物立繪超出卡片邊界問題)
extension ContentView {
    private func victoryView(size: CGSize) -> some View {
        let isCompact = size.width < 700 || size.height < 380
        let mvpMember = team[0]
        let cardHeight = size.height * 0.68
        
        return ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.16, green: 0.12, blue: 0.20), Color.black],
                startPoint: .leading, endPoint: .trailing
            )
            .ignoresSafeArea()
            
            HStack(spacing: size.width * 0.04) {
                // MARK: 左側 MVP 立繪區塊
                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 0)
                    
                    ZStack {
                        // 卡片底色與圓角外框
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [mvpMember.color.opacity(0.45), Color.black.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        if assetImageExists(named: mvpMember.portraitImage) {
                            // 限制縮放比例並對齊底端，且透過 clipShape 確保不突破卡片
                            Image(mvpMember.portraitImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "theatermasks.fill")
                                    .font(.system(size: isCompact ? 44 : 60))
                                    .foregroundColor(vintageGold)
                                Text(mvpMember.name)
                                    .font(.system(size: isCompact ? 18 : 22, weight: .bold, design: .serif))
                                    .foregroundColor(.white)
                                Text(mvpMember.englishName)
                                    .font(.system(size: 11, design: .serif))
                                    .tracking(2)
                                    .foregroundColor(vintageGold)
                            }
                            .padding()
                        }
                    }
                    .frame(width: size.width * 0.28, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(vintageGold.opacity(0.6), lineWidth: 1.5)
                    )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("演出⋯⋯完成了。")
                            .font(.system(size: isCompact ? 13 : 15, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                        Text("The curtain has fallen.")
                            .font(.system(size: 11, design: .serif))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 4)
                }
                .frame(width: size.width * 0.28)
                
                // MARK: 右側結算資訊區塊
                VStack(alignment: .leading, spacing: isCompact ? 10 : 16) {
                    HStack(alignment: .top) {
                        ZStack {
                            Image(systemName: "triangle")
                                .font(.system(size: isCompact ? 50 : 68, weight: .ultraLight))
                                .foregroundColor(vintageGold.opacity(0.4))
                            Text("戰鬥勝利")
                                .font(.system(size: isCompact ? 24 : 32, weight: .bold, design: .serif))
                                .tracking(3)
                                .foregroundColor(vintageGold)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                VStack(spacing: 2) {
                                    Text("當前回合").font(.system(size: 10, design: .serif)).foregroundColor(.black.opacity(0.7))
                                    Text("\(currentRound)").font(.system(size: 18, weight: .bold, design: .serif)).foregroundColor(.black)
                                }
                                Text("=").foregroundColor(.black.opacity(0.5))
                                VStack(spacing: 2) {
                                    Text("紀錄回合").font(.system(size: 10, design: .serif)).foregroundColor(.black.opacity(0.7))
                                    Text("\(currentRound)").font(.system(size: 18, weight: .bold, design: .serif)).foregroundColor(.black)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(white: 0.88))
                            
                            Text("覆蓋記憶")
                                .font(.system(size: 11, weight: .bold, design: .serif))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(actionOrange)
                                .foregroundColor(.white)
                        }
                        .fixedSize()
                        .cornerRadius(4)
                    }
                    
                    Text("TMW / 19  “我們”")
                        .font(.system(size: isCompact ? 15 : 18, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 6) {
                        HStack {
                            Text("擊敗全部敵人")
                            Spacer()
                            Image(systemName: "sparkle").foregroundColor(actionOrange)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        
                        HStack {
                            Text("12回合內勝利")
                            Spacer()
                            Image(systemName: "sparkle").foregroundColor(actionOrange)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                    }
                    .font(.system(size: isCompact ? 12 : 14, design: .serif))
                    .foregroundColor(.white.opacity(0.9))
                    
                    HStack {
                        Text("Lv 80")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Rectangle()
                            .fill(vintageGold)
                            .frame(height: 2)
                        Text("EXP +200")
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundColor(vintageGold)
                    }
                    
                    HStack(spacing: 12) {
                        rewardBadge(icon: "paintbrush.pointed.fill", count: "300", isCompact: isCompact)
                        rewardBadge(icon: "cube.box.fill", count: "200", isCompact: isCompact)
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                resetBattle()
                                gamePhase = .preparation
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("返回戰前編隊")
                            }
                            .font(.system(size: isCompact ? 12 : 14, weight: .bold, design: .serif))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(vintageGold)
                            .foregroundColor(.black)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, max(size.width * 0.04, 20))
            .padding(.vertical, max(size.height * 0.04, 14))
        }
    }
    
    private func rewardBadge(icon: String, count: String, isCompact: Bool) -> some View {
        let boxSize: CGFloat = isCompact ? 46 : 56
        return VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: isCompact ? 16 : 20))
                .foregroundColor(vintageGold)
            Text(count)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(width: boxSize, height: boxSize)
        .background(Color.white.opacity(0.08))
        .border(vintageGold.opacity(0.4), width: 1)
    }
}

// MARK: - 7. 戰鬥與卡牌互動邏輯
extension ContentView {
    private func generateHandCards() {
        let pool: [SkillCard] = [
            // 貝麗爾專屬招式
            SkillCard(ownerName: "貝麗爾", title: "晶狀體之災", subtitle: "單體精神創傷，對目標附加專屬【光晕】狀態。", tag: "Attack", stars: 1, damage: 6200, cardImage: "card_1", icon: "sparkles", cardColor: Color.teal),
            SkillCard(ownerName: "貝麗爾", title: "波光粼粼之夜", subtitle: "群體攻擊，重排敵方光晕層數並造成高額精神創傷。", tag: "Attack", stars: 2, damage: 9800, cardImage: "card_2", icon: "moon.stars.fill", cardColor: Color.cyan),
            
            // 伊索爾德專屬招式
            SkillCard(ownerName: "伊索爾德", title: "意願的自由", subtitle: "群體削弱，使敵方全體暴擊防禦降低25%，現實與精神防禦降低15%。", tag: "Debuff", stars: 1, damage: 5500, cardImage: "card_3", icon: "butterfly.fill", cardColor: Color.purple),
            SkillCard(ownerName: "伊索爾德", title: "克制的美德", subtitle: "單體現實創傷，命中時賦予目標【燃燒】狀態。", tag: "Attack", stars: 2, damage: 8500, cardImage: "card_4", icon: "flame.fill", cardColor: Color(red: 0.7, green: 0.3, blue: 0.5)),
            
            // 蝴蝶專屬招式
            SkillCard(ownerName: "蝴蝶", title: "底火振翼", subtitle: "單體攻擊，造成精神創傷並施加【燃燒】與穩態本源創傷。", tag: "Attack", stars: 1, damage: 7100, cardImage: "card_5", icon: "leaf.fill", cardColor: Color.green),
            SkillCard(ownerName: "蝴蝶", title: "量化判據", subtitle: "群體增強，使自身與隊友獲得【始動之翼】，攻擊時額外施加燃燒。", tag: "Buff", stars: 2, damage: -2500, cardImage: "card_6", icon: "wind", cardColor: Color(red: 0.3, green: 0.7, blue: 0.4)),
            
            // 瑪爾莎專屬招式
            SkillCard(ownerName: "瑪爾莎", title: "緘默的負重", subtitle: "群體增強，提供厚重護盾並驅散全體負面狀態。", tag: "Buff", stars: 2, damage: -3500, cardImage: "card_7", icon: "shield.fill", cardColor: Color.red),
            
            // 至終的儀式 (大招)
            SkillCard(ownerName: "貝麗爾", title: "無中有着无限的光", subtitle: "至終的儀式：釋放絢麗的晶體折射，對敵方全體造成毀滅性精神創傷！", tag: "Ultimate", stars: 3, damage: 18500, cardImage: "card_1", icon: "sun.max.fill", cardColor: Color(red: 0.2, green: 0.6, blue: 0.7)),
            SkillCard(ownerName: "伊索爾德", title: "紅色的標本", subtitle: "至終的儀式：燃燒殆盡的舞台，對敵方全體降下高額現實創傷！", tag: "Ultimate", stars: 3, damage: 21000, cardImage: "card_3", icon: "theatermasks.fill", cardColor: Color(red: 0.8, green: 0.2, blue: 0.3))
        ]
        
        while handCards.count < 7 {
            if let randomCard = pool.randomElement() {
                let newCard = SkillCard(
                    ownerName: randomCard.ownerName,
                    title: randomCard.title,
                    subtitle: randomCard.subtitle,
                    tag: randomCard.tag,
                    stars: randomCard.stars,
                    damage: randomCard.damage,
                    cardImage: randomCard.cardImage,
                    icon: randomCard.icon,
                    cardColor: randomCard.cardColor
                )
                handCards.append(newCard)
            }
        }
    }
    
    private func selectCard(_ card: SkillCard) {
        guard actionSlots.count < 4, !isExecutingTurn else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            hoveredCard = card
            if let idx = handCards.firstIndex(of: card) {
                handCards.remove(at: idx)
            }
            actionSlots.append(card)
            moxie = min(36, moxie + 4)
        }
        
        if actionSlots.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                executeBattleTurn()
            }
        }
    }
    
    private func executeBattleTurn() {
        guard !actionSlots.isEmpty, !isExecutingTurn else { return }
        isExecutingTurn = true
        hoveredCard = nil
        
        let cardsToPlay = actionSlots
        
        for (index, card) in cardsToPlay.enumerated() {
            let delay = Double(index) * 0.95
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if card.tag == "Ultimate" {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        ultimateCard = card
                        showUltimateCutIn = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showUltimateCutIn = false
                        }
                    }
                }
                
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    teamAttackOffset = -40
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.spring()) {
                        teamAttackOffset = 0
                    }
                }
                
                if card.damage < 0 {
                    let healAmount = abs(card.damage)
                    isTeamFloatHeal = true
                    teamFloatString = "+\(healAmount)  +\(healAmount)"
                    withAnimation { showTeamHealText = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation { showTeamHealText = false }
                    }
                } else {
                    let dmg = card.damage
                    bossHP = max(0, bossHP - dmg)
                    minion1HP = max(0, minion1HP - (dmg / 2))
                    minion2HP = max(0, minion2HP - (dmg / 2))
                    
                    enemyDamageString = "-\(dmg)"
                    withAnimation(.easeInOut(duration: 0.1)) {
                        showEnemyDamageText = true
                        enemyHitShake = 10
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.1)) { enemyHitShake = -8 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation { enemyHitShake = 0 }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                        withAnimation { showEnemyDamageText = false }
                    }
                }
            }
        }
        
        let totalTurnTime = Double(cardsToPlay.count) * 0.95 + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTurnTime) {
            actionSlots.removeAll()
            
            if bossHP <= 0 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    gamePhase = .victory
                }
                isExecutingTurn = false
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    enemyAttackOffset = 40
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        enemyAttackOffset = 0
                    }
                    isTeamFloatHeal = false
                    teamFloatString = "-533   -614"
                    withAnimation { showTeamHealText = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                    withAnimation {
                        showTeamHealText = false
                        currentRound = min(maxRounds, currentRound + 1)
                        generateHandCards()
                        isExecutingTurn = false
                    }
                }
            }
        }
    }
    
    private func resetBattle() {
        bossHP = bossMaxHP
        minion1HP = 8000
        minion2HP = 8000
        currentRound = 1
        moxie = 20
        actionSlots.removeAll()
        handCards.removeAll()
        hoveredCard = nil
        isExecutingTurn = false
        generateHandCards()
    }
    
    private func assetImageExists(named name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #elseif canImport(AppKit)
        return NSImage(named: name) != nil
        #else
        return false
        #endif
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
}
