import SwiftUI

struct CameraScreenView: View {
    @StateObject private var viewModel: CameraScreenViewModel
    let onBackToSetup: () -> Void

    @State private var shouldConfirmLeaving = false
    @State private var isNavigatingBack = false

    private let neonGreen = Color(red: 0.06, green: 0.98, blue: 0.56)

    init(corner: TimerOverlayCorner, countdownDuration: TimeInterval, prestartCountdownSeconds: Int, shouldBurnInTimer: Bool, onBackToSetup: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: CameraScreenViewModel(
                corner: corner,
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
                    .padding(.top, 16)

                Spacer()

                bottomRecordBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
            }

            if let countdown = viewModel.prestartCountdownDisplay {
                prestartCountdownOverlay(countdown)
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
        .alert("Leave timer setup?", isPresented: $shouldConfirmLeaving) {
            Button("Stay", role: .cancel) { }
            Button("Leave", role: .destructive) {
                Task { await leaveFlow() }
            }
        } message: {
            Text(viewModel.recorder.isRecording ? "You are currently recording. Leaving now will stop and discard this recording." : "Are you sure you want to leave this page?")
        }
        .confirmationDialog(
            "Save recording?",
            isPresented: $viewModel.shouldPresentSaveDialog,
            titleVisibility: .visible
        ) {
            Button("Save") {
                Task { await viewModel.savePendingRecording() }
            }

            Button("Discard", role: .destructive) {
                viewModel.discardPendingRecording()
            }

            Button("Cancel", role: .cancel) { }
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
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(neonGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 12)
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
                }

            Button(timerActionLabel) {
                viewModel.startTimer()
            }
            .font(.system(size: 34, weight: .bold, design: .monospaced))
            .foregroundStyle(timerActionIsEnabled ? Color.black : neonGreen.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(timerActionIsEnabled ? neonGreen : Color.black.opacity(0.78))
            .overlay {
                Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
            }
            .disabled(!timerActionIsEnabled)
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
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(neonGreen)
                .frame(width: 64, height: 64)
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
        VStack(spacing: 8) {
            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage.uppercased())
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
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
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                    Image(systemName: viewModel.recorder.isRecording ? "stop.fill" : "record.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                }
                .padding(.vertical, 18)
                .foregroundStyle(recordButtonForeground)
                .background(recordButtonBackground)
                .overlay {
                    Rectangle().stroke(neonGreen.opacity(0.95), lineWidth: 1.5)
                }
            }
            .disabled(!canToggleRecording)
            .neonGlow(color: neonGreen)
        }
        .padding(12)
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
            .padding(.vertical, 170)
            .allowsHitTesting(false)
            .neonGlow(color: neonGreen, radius: 2.4)
    }

    private func prestartCountdownOverlay(_ countdown: Int) -> some View {
        VStack {
            Spacer()

            Text("\(countdown)")
                .font(.system(size: 92, weight: .heavy, design: .monospaced))
                .foregroundStyle(neonGreen)
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
        .allowsHitTesting(false)
    }

    private var canToggleRecording: Bool {
        (viewModel.recorder.isRecording || viewModel.pendingExportURL == nil) && !viewModel.isStoppingRecording && !isNavigatingBack
    }

    private var timerActionIsEnabled: Bool {
        viewModel.recorder.isRecording && !viewModel.timerManager.isRunning && !viewModel.timerManager.isInPrestartCountdown
    }

    private var timerActionLabel: String {
        if viewModel.timerManager.isRunning || viewModel.timerManager.isInPrestartCountdown {
            return "TIMER RUNNING"
        }

        return "START TIMER"
    }

    private var recordingToggleLabel: String {
        viewModel.recorder.isRecording ? "Stop Recording" : "Record"
    }

    private var recordButtonForeground: Color {
        canToggleRecording ? .black : neonGreen.opacity(0.45)
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
