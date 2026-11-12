import AppKit
import SwiftUI

/// Bir limit penceresi (ör. 5 saatlik, haftalık). Her servis ~/.claude/kota/<id>.json içinde
/// bunların dizisini tutar; uygulama yalnızca okur, dosyaları servis betikleri yazar.
struct Window: Decodable {
    let label: String
    let used_percentage: Double
    let resets_at: Double  // epoch saniye
}

struct Provider: Identifiable {
    let id: String
    let name: String
    let color: Color

    /// Paketteki logos/<id>.svg; şablon olarak yüklenir ki beyaza boyanabilsin.
    var logo: NSImage {
        let image = Bundle.main.url(forResource: id, withExtension: "svg").flatMap(NSImage.init(contentsOf:)) ?? NSImage()
        image.isTemplate = true
        return image
    }
}

let providers = [
    Provider(id: "claude", name: "Claude", color: Color(red: 0.91, green: 0.42, blue: 0.27)),
    Provider(id: "codex", name: "OpenAI", color: Color(red: 0.20, green: 0.83, blue: 0.56)),
    Provider(id: "gemini", name: "Gemini", color: Color(red: 0.98, green: 0.86, blue: 0.22)),
]

final class Model: ObservableObject {
    @Published var data: [String: [Window]] = [:]
    @Published var now = Date()
    private let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/kota")

    init() {
        reload()
        // shortcut: 30 sn'de bir dosyaları yeniden okur; anlık tepki gerekirse dosya izleyiciye geç.
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.reload() }
    }

    func reload() {
        now = Date()
        for p in providers {
            let url = dir.appendingPathComponent("\(p.id).json")
            data[p.id] = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Window].self, from: $0) }
        }
    }
}

/// Kalan süreyi en büyük iki birimle yazar: "3g 4sa", "2sa 10dk", "10dk".
func remaining(_ seconds: Double) -> String {
    let m = Int(seconds) / 60
    if m >= 1440 { return "\(m / 1440)g \(m % 1440 / 60)sa" }
    if m >= 60 { return "\(m / 60)sa \(m % 60)dk" }
    return "\(max(m, 1))dk"
}

/// Sıfırlanma anı geçmiş pencerenin dosyadaki yüzdesi bayattır: kullanım sıfır sayılır.
func used(_ w: Window, _ now: Date) -> Double {
    w.resets_at > now.timeIntervalSince1970 ? w.used_percentage : 0
}

struct Ring: View {
    let provider: Provider
    let windows: [Window]?
    let now: Date
    let s: Double
    @State private var hover = false

    var body: some View {
        // Tek halka: sınıra en yakın pencereyi gösterir; ayrıntı ipucunda.
        let pct = windows?.map { used($0, now) }.max()
        let tip = windows?.map { w in
            let left = w.resets_at - now.timeIntervalSince1970
            return "\(w.label): %\(Int(used(w, now).rounded()))" + (left > 0 ? ", \(remaining(left)) sonra sıfırlanır" : "")
        }.joined(separator: "\n") ?? "Veri yok"

        VStack(spacing: 5 * s) {
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 3 * s)
                Circle().trim(from: 0, to: (pct ?? 0) / 100)
                    .stroke(provider.color, style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(nsImage: provider.logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17 * s, height: 17 * s)
                    .foregroundStyle(.white)
            }
            .frame(width: 36 * s, height: 36 * s)
            Text(pct.map { "%\(Int($0.rounded()))" } ?? "–")
                .font(.system(size: 11 * s, weight: .medium).monospacedDigit())
                .foregroundStyle((pct ?? 0) >= 90 ? .red : .white)
        }
        // .help değil: ipuçları yalnızca etkin uygulamada çıkar, Kota ise hiç etkinleşmez.
        .onHover { hover = $0 }
        .popover(isPresented: $hover, arrowEdge: .leading) {
            Text("\(provider.name)\n\(tip)").font(.system(size: 12)).padding(10).fixedSize()
        }
    }
}

/// Ekranın sağ kenarından akarak çıkan şekil: üstte ve altta kenara S eğrisiyle bağlanır.
struct Blob: Shape {
    let fillet: Double

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + fillet),
                   control1: CGPoint(x: r.maxX, y: r.minY + fillet * 0.55),
                   control2: CGPoint(x: r.minX, y: r.minY + fillet * 0.45))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - fillet))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                   control1: CGPoint(x: r.minX, y: r.maxY - fillet * 0.45),
                   control2: CGPoint(x: r.maxX, y: r.maxY - fillet * 0.55))
        p.closeSubpath()
        return p
    }
}

struct Widget: View {
    @ObservedObject var model: Model
    let onSize: (CGSize) -> Void
    @AppStorage("scale") private var s = 1.0
    @AppStorage("hidden") private var hidden = ""  // gizlenen servis kimlikleri, virgülle

    private func shown(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !hidden.split(separator: ",").contains(Substring(id)) },
            set: { on in
                var ids = hidden.split(separator: ",").map(String.init).filter { $0 != id }
                if !on { ids.append(id) }
                hidden = ids.joined(separator: ",")
            })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 16 * s) {
                ForEach(providers.filter { shown($0.id).wrappedValue }) { p in
                    Ring(provider: p, windows: model.data[p.id], now: model.now, s: s)
                }
            }
            .padding(.vertical, 52 * s)
            .frame(width: 62 * s)
            .background(.black, in: Blob(fillet: 58 * s))

            // Dişli, alt eğrinin boşluğuna oturur.
            Menu {
                ForEach(providers) { p in Toggle(p.name, isOn: shown(p.id)) }
                Divider()
                Picker("Boyut", selection: $s) {
                    Text("Küçük").tag(0.8)
                    Text("Orta").tag(1.0)
                    Text("Büyük").tag(1.3)
                    Text("Çok büyük").tag(1.6)
                }
                Divider()
                Button("Kota'dan Çık") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14 * s, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 32 * s, height: 32 * s)
                    .background(.black, in: Circle())
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .padding(.top, -16 * s)
            .padding(.leading, 14 * s)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onSize($0) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = Model()
    var panel: NSPanel!

    func applicationDidFinishLaunching(_: Notification) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: Widget(model: model) { [weak self] in self?.place($0) })
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        // .fullScreenAuxiliary yok: tam ekran uygulamaların üstüne çıkmaz.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        place(panel.contentView!.fittingSize)
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.place(self.panel.frame.size)
        }
    }

    /// Paneli ana ekranın sağ kenarına, dikeyde ortaya yerleştirir; boyut ayarı değişince de çağrılır.
    func place(_ size: CGSize) {
        // screens.first = menü çubuğunun olduğu ana ekran; NSScreen.main ise o an odaktaki ekrandır.
        guard let screen = NSScreen.screens.first?.frame else { return }
        panel.setFrame(NSRect(x: screen.maxX - size.width, y: screen.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
