import SwiftUI

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double    // 0.0 to 1.0
    var lineWidth: CGFloat = 8
    var size: CGFloat = 80
    var trackColor: Color = .pinkLight
    var progressColor: Color = .pinkPrimary
    var overColor: Color = .success
    
    private var displayColor: Color {
        progress >= 1.0 ? overColor : progressColor
    }
    
    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            
            // Progress
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    displayColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
            
            // Percentage text
            Text("\(Int(min(progress, 1.0) * 100))%")
                .font(PinkTypography.callout)
                .foregroundColor(displayColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: Double
    let icon: String
    var color: Color = .pinkPrimary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value.asCurrency)
                .font(PinkTypography.moneySmall)
                .foregroundColor(.textPrimary)
            
            Text(title)
                .font(PinkTypography.caption)
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
        .pinkCard()
    }
}

// MARK: - Month Picker

struct MonthPicker: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    
    private let monthNames = Calendar.current.shortMonthSymbols
    
    var body: some View {
        HStack {
            Button {
                if selectedMonth == 1 {
                    selectedMonth = 12
                    selectedYear -= 1
                } else {
                    selectedMonth -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.pinkPrimary)
            }
            
            Spacer()
            
            Text("\(monthNames[selectedMonth - 1]) \(String(selectedYear))")
                .font(PinkTypography.headline)
            
            Spacer()
            
            Button {
                if selectedMonth == 12 {
                    selectedMonth = 1
                    selectedYear += 1
                } else {
                    selectedMonth += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.pinkPrimary)
            }
        }
        .padding(.horizontal, 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressRing(progress: 0.72, size: 100)
        ProgressRing(progress: 1.0, size: 60)
        
        HStack {
            StatCard(title: "Income", value: 4200, icon: "arrow.down.circle.fill", color: .success)
            StatCard(title: "Spent", value: 1850, icon: "arrow.up.circle.fill", color: .danger)
        }
        .padding()
    }
}
