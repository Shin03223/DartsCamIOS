import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var detector = DartsCameraDetector()
    @State private var roomCode: String = "darts777"
    @State private var isLeftSide: Bool = true
    @State private var zoomScale: CGFloat = 1.0

    // 4点キャリブレーション座標（320x320基準）
    @State private var pTop = CGPoint(x: 160, y: 20)
    @State private var pRight = CGPoint(x: 250, y: 160)
    @State private var pBottom = CGPoint(x: 160, y: 300)
    @State private var pLeft = CGPoint(x: 70, y: 160)

    var body: some View {
        VStack(spacing: 10) {
            Text("🎯 DARTS CAMERA AI")
                .font(.headline)
                .foregroundColor(.yellow)

            HStack {
                Text("合言葉:")
                    .foregroundColor(.white)
                    .font(.caption)
                TextField("darts777", text: $roomCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
                    .autocapitalization(.none)
                Button("テスト送信") {
                    detector.sendHit(code: "ib", room: roomCode)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange)
                .foregroundColor(.black)
                .cornerRadius(6)
                .font(.caption.bold())
            }

            // カメラ映像＆ガイド枠エリア
            ZStack {
                CameraPreviewView(session: detector.session)
                    .scaleEffect(zoomScale)
                    .frame(width: 320, height: 320)
                    .clipped()

                // 楕円ガイド描画
                GuideOverlayView(pTop: pTop, pRight: pRight, pBottom: pBottom, pLeft: pLeft, hitPoint: detector.lastHitPoint)
                    .frame(width: 320, height: 320)

                // 4点ドラッグハンドル
                DragHandle(point: $pTop, label: "20上")
                DragHandle(point: $pRight, label: "6右")
                DragHandle(point: $pBottom, label: "3下")
                DragHandle(point: $pLeft, label: "11左")
            }
            .frame(width: 320, height: 320)
            .border(Color.cyan, width: 2)

            // ズーム＆設置位置パネル
            VStack(spacing: 6) {
                HStack {
                    Text(String(format: "ズーム: %.2fx", zoomScale))
                        .foregroundColor(.white)
                        .font(.caption.bold())
                        .frame(width: 85, alignment: .leading)
                    Slider(value: $zoomScale, in: 1.0...4.0, step: 0.05)
                        .onChange(of: zoomScale) { newVal in
                            detector.setHardwareZoom(factor: newVal)
                        }
                }
                HStack {
                    Text(isLeftSide ? "設置位置: 左横" : "設置位置: 右横")
                        .foregroundColor(.white)
                        .font(.caption.bold())
                    Spacer()
                    Button("左横 / 右横 切替") {
                        isLeftSide.toggle()
                        detector.isLeftSide = isLeftSide
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .font(.caption.bold())
                }
            }
            .padding(8)
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .frame(width: 320)

            Text(detector.statusText)
                .font(.caption.bold())
                .foregroundColor(.mint)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("1. 基準撮影") {
                    detector.captureBaseline()
                }
                .padding(10)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .font(.caption.bold())

                Button(detector.isDetecting ? "認識中... (停止)" : "2. 認識 START") {
                    detector.updateCalibration(top: pTop, right: pRight, bottom: pBottom, left: pLeft)
                    detector.roomCode = roomCode
                    detector.toggleDetecting()
                }
                .padding(10)
                .background(detector.isDetecting ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                .font(.caption.bold())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            detector.startCamera()
        }
    }
}

struct DragHandle: View {
    @Binding var point: CGPoint
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.yellow)
                .frame(width: 22, height: 22)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.black)
                .offset(y: -16)
        }
        .position(point)
        .gesture(
            DragGesture()
                .onChanged { value in
                    point = CGPoint(
                        x: min(315, max(5, value.location.x)),
                        y: min(315, max(5, value.location.y))
                    )
                }
        )
    }
}

struct GuideOverlayView: View {
    let pTop: CGPoint
    let pRight: CGPoint
    let pBottom: CGPoint
    let pLeft: CGPoint
    let hitPoint: CGPoint?

    var body: some View {
        Canvas { context, size in
            let cx = (pTop.x + pRight.x + pBottom.x + pLeft.x) / 4
            let cy = (pTop.y + pRight.y + pBottom.y + pLeft.y) / 4
            let rx = hypot(pRight.x - pLeft.x, pRight.y - pLeft.y) / 2
            let ry = hypot(pBottom.x - pTop.x, pBottom.y - pTop.y) / 2
            let rot = atan2(pRight.y - pLeft.y, pRight.x - pLeft.x)

            context.translateBy(x: cx, y: cy)
            context.rotate(by: .radians(rot))

            for scale in [1.0, 0.62, 0.12] {
                let rect = CGRect(x: -rx * scale, y: -ry * scale, width: rx * 2 * scale, height: ry * 2 * scale)
                context.stroke(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.85)), lineWidth: 2)
            }

            context.rotate(by: .radians(-rot))
            context.translateBy(x: -cx, y: -cy)

            if let hp = hitPoint {
                let hitRect = CGRect(x: hp.x - 6, y: hp.y - 6, width: 12, height: 12)
                context.fill(Path(ellipseIn: hitRect), with: .color(.red))
            }
        }
        .allowsHitTesting(false)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class DartsCameraDetector: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "darts.cam.queue")

    @Published var statusText = "カメラ準備中..."
    @Published var isDetecting = false
    @Published var lastHitPoint: CGPoint? = nil

    var isLeftSide = true
    var roomCode = "darts777"
    private var shouldCaptureBase = false
    private var baseBuffer: [UInt8]? = nil
    private var cooldownUntil = Date.distantPast

    private var pTop = CGPoint(x: 160, y: 20)
    private var pRight = CGPoint(x: 250, y: 160)
    private var pBottom = CGPoint(x: 160, y: 300)
    private var pLeft = CGPoint(x: 70, y: 160)

    private let boardNums = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

    func startCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.statusText = "設定アプリからカメラを許可してください"
                    return
                }
                self.setupSession()
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            statusText = "背面カメラが見つかりません"
            return
        }
        videoDevice = device
        if session.canAddInput(input) { session.addInput(input) }

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.statusText = "カメラ起動OK！枠を合わせて「1. 基準撮影」を押してください"
            }
        }
    }

    func setHardwareZoom(factor: CGFloat) {
        guard let dev = videoDevice else { return }
        do {
            try dev.lockForConfiguration()
            let maxZ = min(dev.activeFormat.videoMaxZoomFactor, 4.0)
            dev.videoZoomFactor = max(1.0, min(maxZ, factor))
            dev.unlockForConfiguration()
        } catch {}
    }

func updateCalibration(top: CGPoint, right: CGPoint, bottom: CGPoint, left: CGPoint) {
pTop = top; pRight = right; pBottom = bottom; pLeft = left
}
func captureBaseline() {
shouldCaptureBase = true
statusText = "基準撮影OK！「2. 認識 START」を押してください"
}
func toggleDetecting() {
if baseBuffer == nil {
statusText = "先に「1. 基準撮影」を押してください"
return
}
isDetecting.toggle()
statusText = isDetecting ? "自動認識中（矢を投げてください）" : "停止中"
}
func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
let width = CVPixelBufferGetWidth(pixelBuffer)
let height = CVPixelBufferGetHeight(pixelBuffer)
let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
guard let baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
let ptr = baseAddr.assumingMemoryBound(to: UInt8.self)
// 160x160 にサンプリングして高速比較
let grid = 160
var current = [UInt8](repeating: 0, count: grid * grid * 3)
let side = min(width, height)
let startX = (width - side) / 2
let startY = (height - side) / 2
for gy in 0..<grid {
let py = startY + (gy * side) / grid
for gx in 0..<grid {
let px = startX + (gx * side) / grid
let offset = py * bytesPerRow + px * 4
let idx = (gy * grid + gx) * 3
current[idx] = ptr[offset]
current[idx + 1] = ptr[offset + 1]
current[idx + 2] = ptr[offset + 2]
}
}
if shouldCaptureBase {
baseBuffer = current
shouldCaptureBase = false
return
}
guard isDetecting, let base = baseBuffer, Date() > cooldownUntil else { return }
var changed: [(x: Double, y: Double)] = []
for gy in 5..<(grid - 5) {
for gx in 5..<(grid - 5) {
let idx = (gy * grid + gx) * 3
let diff = abs(Int(current[idx]) - Int(base[idx]))
+ abs(Int(current[idx + 1]) - Int(base[idx + 1]))
+ abs(Int(current[idx + 2]) - Int(base[idx + 2]))
if diff > 110 {
// 320x320座標へスケール変換（縦向きカメラ回転補正込み）
changed.append((x: Double(grid - gy) * 2.0, y: Double(gx) * 2.0))
}
}
}
if changed.count > 25 && changed.count < 2000 {
changed.sort { isLeftSide ? ($0.x > $1.x) : ($0.x < $1.x) }
let tipSlice = changed.prefix(15)
let hx = tipSlice.map(.x).reduce(0, +) / Double(tipSlice.count)
let hy = tipSlice.map(.y).reduce(0, +) / Double(tipSlice.count)
let code = calcDartCode(x: hx, y: hy)
cooldownUntil = Date().addingTimeInterval(1.8)
shouldCaptureBase = true
DispatchQueue.main.async {
self.lastHitPoint = CGPoint(x: hx, y: hy)
self.sendHit(code: code)
}
}
}
private func calcDartCode(x: Double, y: Double) -> String {
let cx = Double(pTop.x + pRight.x + pBottom.x + pLeft.x) / 4.0
let cy = Double(pTop.y + pRight.y + pBottom.y + pLeft.y) / 4.0
let rx = max(10.0, hypot(Double(pRight.x - pLeft.x), Double(pRight.y - pLeft.y)) / 2.0)
let ry = max(10.0, hypot(Double(pBottom.x - pTop.x), Double(pBottom.y - pTop.y)) / 2.0)
let rot = atan2(Double(pRight.y - pLeft.y), Double(pRight.x - pLeft.x))
let dx = x - cx
let dy = y - cy
let cosR = cos(-rot)
let sinR = sin(-rot)
let nx = (dx * cosR - dy * sinR) / rx
let ny = (dx * sinR + dy * cosR) / ry
let dist = hypot(nx, ny)
if dist <= 0.05 { return "ib" }
if dist <= 0.12 { return "ob" }
if dist > 1.06 { return "00s" }
var deg = atan2(ny, nx) * 180.0 / .pi + 90.0 + 9.0
if deg < 0 { deg += 360.0 }
if deg >= 360.0 { deg -= 360.0 }
let idx = Int(deg / 18.0) % 20
let num = String(format: "%02d", boardNums[idx])
var mult = "s"
if dist >= 0.89 && dist <= 1.06 { mult = "d" }
else if dist >= 0.55 && dist <= 0.67 { mult = "t" }
return num + mult
}
func sendHit(code: String, room: String? = nil) {
let targetRoom = (room ?? roomCode).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
let finalRoom = targetRoom.isEmpty ? "darts777" : targetRoom
statusText = "送信: (code.uppercased())"
guard let url = URL(string: "ntfy.sh") else { return }
URLSession.shared.dataTask(with: url).resume()
}
}