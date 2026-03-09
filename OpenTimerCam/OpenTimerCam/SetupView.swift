import SwiftUI

struct SetupView: View {
    @Binding var selectedCorner: TimerOverlayCorner
    @Binding var selectedCameraPosition: CameraPositionOption
    @Binding var timerMinutes: Int
    @Binding var countdownSeconds: Int
    let onContinue: () -> Void

    private let countdownOptions = [0, 3, 5, 10]
    private let neonGreen = Color(red: 0.06, green: 0.98, blue: 0.56)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()


            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header

                    neonCard(title: "TIMER MINUTES") {
                        Picker("Timer Minutes", selection: $timerMinutes) {
                            ForEach(0...59, id: \.self) { minute in
                                Text("\(minute) MIN")
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundStyle(neonGreen)
                                    .tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .clipped()
                        .tint(neonGreen)
                        .overlay {
                            Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.2)
                        }
                    }

                    neonCard(title: "START COUNTDOWN") {
                        segmentedCountdown
                    }

                    neonCard(title: "TIMER POSITION") {
                        segmentedCorner
                    }

                    neonCard(title: "CAMERA") {
                        segmentedCamera
                    }

                    Text("FORMAT: M:SS.SSS COUNT UP")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(neonGreen.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    continueButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 26)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("OPEN TIMER CAM")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(neonGreen)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(neonGreen.opacity(0.9))
                .frame(height: 1.5)

            Text("SETUP")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(neonGreen)

            Rectangle()
                .fill(neonGreen.opacity(0.9))
                .frame(height: 1.5)
        }
        .neonGlow(color: neonGreen, radius: 2)
    }

    private var segmentedCountdown: some View {
        HStack(spacing: 8) {
            ForEach(countdownOptions, id: \.self) { seconds in
                let isSelected = seconds == countdownSeconds
                Button {
                    countdownSeconds = seconds
                } label: {
                    Text(seconds == 0 ? "OFF" : "\(seconds)S")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.black : neonGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSelected ? neonGreen : Color.black.opacity(0.85))
                        .overlay {
                            Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.2)
                        }
                }
            }
        }
    }

    private var segmentedCorner: some View {
        HStack(spacing: 8) {
            ForEach(TimerOverlayCorner.allCases) { corner in
                let isSelected = corner == selectedCorner
                Button {
                    selectedCorner = corner
                } label: {
                    Text(cornerShortLabel(corner))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.black : neonGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSelected ? neonGreen : Color.black.opacity(0.85))
                        .overlay {
                            Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.2)
                        }
                }
            }
        }
    }

    private var segmentedCamera: some View {
        HStack(spacing: 8) {
            ForEach(CameraPositionOption.allCases) { position in
                let isSelected = position == selectedCameraPosition
                Button {
                    selectedCameraPosition = position
                } label: {
                    Text(position.shortLabel)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.black : neonGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(isSelected ? neonGreen : Color.black.opacity(0.85))
                        .overlay {
                            Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.2)
                        }
                }
            }
        }
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            HStack {
                Spacer()
                Text("CONTINUE")
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .foregroundStyle(Color.black)
            .padding(.vertical, 12)
            .background(neonGreen)
            .overlay {
                Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.4)
            }
        }
        .padding(.top, 8)
        .neonGlow(color: neonGreen)
    }


    private func neonCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(neonGreen.opacity(0.88))

            content()
        }
        .padding(12)
        .background(Color.black.opacity(0.58))
        .overlay {
            Rectangle().stroke(neonGreen.opacity(0.92), lineWidth: 1.3)
        }
        .neonGlow(color: neonGreen, radius: 1.8)
    }


    private func cornerShortLabel(_ corner: TimerOverlayCorner) -> String {
        switch corner {
        case .topLeading:
            return "TOP L"
        case .topTrailing:
            return "TOP R"
        case .bottomLeading:
            return "BTM L"
        case .bottomTrailing:
            return "BTM R"
        }
    }
}

private extension View {
    func neonGlow(color: Color, radius: CGFloat = 3.2) -> some View {
        self
            .shadow(color: color.opacity(0.14), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.08), radius: radius * 1.8, x: 0, y: 0)
    }
}
