import SwiftUI

struct CameraScreenView: View {
    @StateObject private var viewModel: CameraScreenViewModel
    let onBackToSetup: () -> Void

    @State private var shouldConfirmLeaving = false
    @State private var isNavigatingBack = false

    private let neonGreen = Color(red: 0.06, green: 0.98, blue: 0.56)

    init(corner: TimerOverlayCorner, cameraPosition: CameraPositionOption, countdownDuration: TimeInterval, prestartCountdownSeconds: Int, shouldBurnInTimer: Bool, onBackToSetup: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: CameraScreenViewModel(
                corner: corner,
                cameraPosition: cameraPosition,
                countdownDuration: countdownDuration,
                prestartCountdownSeconds: prestartCountdownSeconds,
                shouldBurnInTimer: shouldBurnInTimer
            )
        )
        self.onBackToSetup = onBackToSetup
    }

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.recorder.session)
                .ignoresSafeArea()

            cameraFrameGuide

            VStack(spacing: 0) {
                topHUD
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer()

                bottomRecordBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .allowsHitTesting(!isShowingBlockingOverlay)

            if let countdown = viewModel.prestartCountdownDisplay {
                prestartCountdownOverlay(countdown)
            }

            if viewModel.isExporting {
                savingOverlay
            }

            if isShowingCustomDialog {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                if shouldConfirmLeaving {
                    leaveDialog
                } else if viewModel.shouldPresentSaveDialog {
                    saveDialog
                }
            }
        }
        .task {
            await viewModel.setup()
        }
        .alert("Permissions Needed", isPresented: Binding(get: { viewModel.permissionDeniedMessage != nil }, set: { if !$0 { viewModel.permissionDeniedMessage = nil } })) {
            Button("OK") { viewModel.permissionDeniedMessage = nil }
        } message: {
            Text(viewModel.permissionDeniedMessage ?? "")
        }
    }

    private var topHUD: some View {
        HStack(alignment: .top) {
            topBackButton

            Spacer(minLength: 12)

            timerPanel
        }
    }

    private var timerPanel: some View {
        VStack(spacing: 0) {
            Text(viewModel.timerDisplayString)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(neonGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 12)
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
                }

            if !viewModel.timerManager.isRunning && !viewModel.timerManager.isInPrestartCountdown {
                Button("START TIMER") {
                    viewModel.toggleTimer()
                }
                .font(.system(size: 23, weight: .bold, design: .monospaced))
                .foregroundStyle(timerActionForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(timerActionBackground)
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
                }
                .disabled(!timerActionIsEnabled)
            }
        }
        .background(Color.black.opacity(0.52))
        .neonGlow(color: neonGreen)
        .frame(maxWidth: 252)
    }

    private var topBackButton: some View {
        Button {
            shouldConfirmLeaving = true
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundStyle(neonGreen)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.55))
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
                }
        }
        .disabled(isNavigatingBack)
        .accessibilityLabel("Back")
        .neonGlow(color: neonGreen)
    }

    private var bottomRecordBar: some View {
        VStack(spacing: 6) {
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage.uppercased())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(neonGreen.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            Button {
                viewModel.toggleRecording()
            } label: {
                HStack {
                    Spacer()
                    Text(recordingToggleLabel.uppercased())
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(0.4)
                    Image(systemName: viewModel.recorder.isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                    Spacer()
                }
                .padding(.vertical, 10)
                .foregroundStyle(recordButtonForeground)
                .background(recordButtonBackground)
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
                }
            }
            .disabled(!canToggleRecording)
            .neonGlow(color: neonGreen)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .overlay {
            Rectangle().stroke(neonGreen.opacity(0.8), lineWidth: 1.2)
        }
        .neonGlow(color: neonGreen, radius: 2.2)
    }

    private var cameraFrameGuide: some View {
        RoundedRectangle(cornerRadius: 0)
            .stroke(neonGreen.opacity(0.75), lineWidth: 1.5)
            .padding(.horizontal, 16)
            .padding(.vertical, 150)
            .allowsHitTesting(false)
            .neonGlow(color: neonGreen, radius: 2.4)
    }

    private var leaveDialog: some View {
        VStack(spacing: 14) {
            Text("LEAVE SETUP?")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(neonGreen)

            Text(viewModel.recorder.isRecording ? "LEAVING NOW WILL STOP AND DISCARD THIS RECORDING." : "ARE YOU SURE YOU WANT TO LEAVE THIS PAGE?")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(neonGreen.opacity(0.9))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                dialogButton(title: "STAY", isFilled: false) {
                    shouldConfirmLeaving = false
                }

                dialogButton(title: "LEAVE", isFilled: true) {
                    shouldConfirmLeaving = false
                    Task { await leaveFlow() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(Color.black.opacity(0.9))
        .overlay {
            Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.4)
        }
        .neonGlow(color: neonGreen)
    }


    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(neonGreen)

                Text("SAVING RECORDING…")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(neonGreen)

                Text("LONGER RECORDINGS TAKE LONGER TO BURN IN")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(neonGreen.opacity(0.86))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: 360)
            .background(Color.black.opacity(0.9))
            .overlay {
                Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.4)
            }
            .neonGlow(color: neonGreen)
        }
    }

    private var saveDialog: some View {
        VStack(spacing: 14) {
            Text("SAVE RECORDING?")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(neonGreen)

            HStack(spacing: 10) {
                dialogButton(title: "SAVE", isFilled: true) {
                    Task { await viewModel.savePendingRecording() }
                }

                dialogButton(title: "DISCARD", isFilled: false) {
                    viewModel.discardPendingRecording()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 340)
        .background(Color.black.opacity(0.9))
        .overlay {
            Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.4)
        }
        .neonGlow(color: neonGreen)
    }

    private func dialogButton(title: String, isFilled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(isFilled ? Color.black : neonGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isFilled ? neonGreen : Color.black.opacity(0.82))
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.3)
                }
        }
    }

    private func prestartCountdownOverlay(_ countdown: Int) -> some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                Text("\(countdown)")
                    .font(.system(size: 92, weight: .heavy, design: .monospaced))
                    .foregroundStyle(neonGreen)

                Button("CANCEL") {
                    viewModel.cancelPrestartCountdown()
                }
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(neonGreen)
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.2)
                }
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.78))
            .overlay {
                Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
            }
            .neonGlow(color: neonGreen, radius: 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isShowingCustomDialog: Bool {
        shouldConfirmLeaving || viewModel.shouldPresentSaveDialog
    }

    private var isShowingBlockingOverlay: Bool {
        isShowingCustomDialog || viewModel.isExporting
    }

    private var canToggleRecording: Bool {
        (viewModel.recorder.isRecording || viewModel.pendingExportURL == nil) && !viewModel.isStoppingRecording && !isNavigatingBack
    }

    private var timerActionIsEnabled: Bool {
        if viewModel.timerManager.isRunning || viewModel.timerManager.isInPrestartCountdown {
            return true
        }

        return viewModel.recorder.isRecording && !viewModel.isStoppingRecording
    }

    private var timerActionForeground: Color {
        timerActionIsEnabled ? .black : neonGreen.opacity(0.5)
    }

    private var timerActionBackground: Color {
        timerActionIsEnabled ? neonGreen : Color.black.opacity(0.78)
    }

    private var recordingToggleLabel: String {
        viewModel.recorder.isRecording ? "Stop Recording" : "Record"
    }

    private var recordButtonForeground: Color {
        guard canToggleRecording else { return neonGreen.opacity(0.45) }

        return viewModel.recorder.isRecording ? neonGreen : .black
    }

    private var recordButtonBackground: Color {
        if !canToggleRecording {
            return Color.black.opacity(0.75)
        }

        return viewModel.recorder.isRecording ? Color.black.opacity(0.85) : neonGreen
    }

    private func leaveFlow() async {
        guard !isNavigatingBack else { return }
        isNavigatingBack = true

        await viewModel.cleanupOnNavigation()
        onBackToSetup()
    }
}

private extension View {
    func neonGlow(color: Color, radius: CGFloat = 3.2) -> some View {
        self
            .shadow(color: color.opacity(0.14), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.08), radius: radius * 1.8, x: 0, y: 0)
    }
}
