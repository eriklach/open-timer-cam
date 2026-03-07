import SwiftUI

struct CameraScreenView: View {
    @StateObject private var viewModel: CameraScreenViewModel
    let onBackToSetup: () -> Void

    @State private var shouldConfirmLeaving = false
    @State private var isNavigatingBack = false

    init(corner: TimerOverlayCorner, countdownDuration: TimeInterval, prestartCountdownSeconds: Int, onBackToSetup: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: CameraScreenViewModel(
                corner: corner,
                countdownDuration: countdownDuration,
                prestartCountdownSeconds: prestartCountdownSeconds
            )
        )
        self.onBackToSetup = onBackToSetup
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CameraPreviewView(session: viewModel.recorder.session)
                .ignoresSafeArea()

            timerOverlay
                .padding(16)

            if let countdown = viewModel.prestartCountdownDisplay {
                prestartCountdownOverlay(countdown)
            }

            controls
        }
        .overlay(alignment: .topLeading) {
            topBackButton
                .padding(.top, 16)
                .padding(.leading, 16)
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

    private var timerOverlay: some View {
        Text(viewModel.timerDisplayString)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var topBackButton: some View {
        Button {
            shouldConfirmLeaving = true
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(isNavigatingBack)
        .accessibilityLabel("Back")
    }

    private func prestartCountdownOverlay(_ countdown: Int) -> some View {
        VStack {
            Spacer()

            Text("\(countdown)")
                .font(.system(size: 92, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 20)
                .background(.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        VStack {
            Spacer()

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.toggleRecording()
                } label: {
                    Label(recordingToggleLabel, systemImage: recordingToggleIcon)
                        .frame(minWidth: 138)
                }
                .buttonStyle(.borderedProminent)
                .tint(recordingToggleTint)
                .controlSize(.large)
                .disabled(!canToggleRecording)

                Button("Start Timer") {
                    viewModel.startTimer()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(canStartTimer ? .orange : .gray)
                .disabled(!canStartTimer)
            }
            .buttonBorderShape(.roundedRectangle)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
        }
    }

    private var canToggleRecording: Bool {
        (viewModel.recorder.isRecording || viewModel.pendingExportURL == nil) && !viewModel.isStoppingRecording && !isNavigatingBack
    }

    private var canStartTimer: Bool {
        viewModel.recorder.isRecording && !viewModel.timerManager.isRunning && !viewModel.timerManager.isInPrestartCountdown
    }

    private var recordingToggleLabel: String {
        viewModel.recorder.isRecording ? "Stop Recording" : "Start Recording"
    }

    private var recordingToggleIcon: String {
        viewModel.recorder.isRecording ? "stop.fill" : "record.circle.fill"
    }

    private var recordingToggleTint: Color {
        canToggleRecording ? .red : .gray
    }

    private func leaveFlow() async {
        guard !isNavigatingBack else { return }
        isNavigatingBack = true

        await viewModel.cleanupOnNavigation()
        onBackToSetup()
    }
}
