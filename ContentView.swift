import SwiftUI
import UIKit

private enum RemoteStyle {
    static let background = Color(red: 0.055, green: 0.075, blue: 0.12)
    static let surface = Color(red: 0.11, green: 0.14, blue: 0.21)
    static let accent = Color(red: 0.37, green: 0.68, blue: 1.0)
}

struct ContentView: View {
    @StateObject private var tv = SamsungTV()
    @State private var selectedPage = 0
    @State private var showConnection = false
    @State private var digits = ""

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 730
            VStack(spacing: compact ? 10 : 16) {
                header
                Picker("Раздел", selection: $selectedPage) {
                    Text("Пульт").tag(0)
                    Text("Цифры").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 22)

                if selectedPage == 0 {
                    mainRemote(compact: compact)
                } else {
                    numberPad(compact: compact)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RemoteStyle.background.ignoresSafeArea())
            .foregroundStyle(.white)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConnection) { connectionSheet }
        .onAppear { if !tv.connected { tv.connect() } }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SAMSUNG REMOTE").font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(2.5).foregroundStyle(RemoteStyle.accent)
                Text("Гостиная · T5202").font(.system(size: 21, weight: .semibold))
                Text(tv.status).font(.caption).lineLimit(1)
                    .foregroundStyle(tv.connected ? .green : .gray)
            }
            Spacer()
            Button { showConnection = true } label: {
                Image(systemName: "wifi").font(.title3)
                    .frame(width: 46, height: 46)
                    .background(RemoteStyle.surface, in: Circle())
                    .overlay(Circle().stroke(tv.connected ? Color.green.opacity(0.7) : Color.white.opacity(0.12)))
            }
            .accessibilityLabel("Подключение к телевизору")
            remoteIcon("power", "KEY_POWER", tint: .red)
        }
        .padding(.horizontal, 22)
    }

    private func mainRemote(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 15) {
            HStack(spacing: 10) {
                shortcut("Домой", icon: "house.fill", key: "KEY_HOME")
                shortcut("Smart Hub", icon: "square.grid.2x2.fill", key: "KEY_SMART_HUB")
                shortcut("Настройки", icon: "gearshape.fill", key: "KEY_MENU")
                shortcut("Назад", icon: "arrow.uturn.backward", key: "KEY_RETURN")
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                remoteIcon("chevron.up", "KEY_UP", size: 62)
                HStack(spacing: 22) {
                    remoteIcon("chevron.left", "KEY_LEFT", size: 62)
                    Button { send("KEY_ENTER") } label: {
                        Text("OK").font(.system(size: 21, weight: .bold, design: .rounded))
                            .frame(width: 78, height: 78)
                            .background(RemoteStyle.accent, in: Circle())
                    }
                    .disabled(!tv.connected)
                    .accessibilityLabel("Подтвердить")
                    remoteIcon("chevron.right", "KEY_RIGHT", size: 62)
                }
                remoteIcon("chevron.down", "KEY_DOWN", size: 62)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 4 : 12)
            .background(RemoteStyle.surface, in: RoundedRectangle(cornerRadius: 34))
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                rocker(title: "ГРОМКОСТЬ", plus: "KEY_VOLUP", minus: "KEY_VOLDOWN", icon: "speaker.wave.2.fill")
                rocker(title: "КАНАЛЫ", plus: "KEY_CHUP", minus: "KEY_CHDOWN", icon: "tv.fill")
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                wideAction("Без звука", icon: "speaker.slash.fill", key: "KEY_MUTE")
                wideAction("Источник", icon: "rectangle.on.rectangle", key: "KEY_SOURCE")
            }
            .padding(.horizontal, 20)
        }
    }

    private func numberPad(compact: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(digits.isEmpty ? "Номер канала" : digits)
                    .foregroundStyle(digits.isEmpty ? .gray : .white)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Spacer()
                Button { digits = "" } label: { Image(systemName: "delete.left") }
                    .accessibilityLabel("Очистить номер")
            }
            .padding(18)
            .background(RemoteStyle.surface, in: RoundedRectangle(cornerRadius: 18))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(1...9, id: \.self) { n in digitButton(n) }
                Button { send("KEY_PRECH"); digits = "" } label: { digitLabel("↶") }
                    .accessibilityLabel("Предыдущий канал")
                digitButton(0)
                Button { send("KEY_ENTER"); digits = "" } label: { digitLabel("OK") }
                    .accessibilityLabel("Подтвердить канал")
            }
            .disabled(!tv.connected)
            Text("Цифры отправляются на телевизор сразу. OK подтверждает выбор канала.")
                .font(.caption).foregroundStyle(.gray).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }

    private func digitButton(_ number: Int) -> some View {
        Button {
            if digits.count >= 4 { digits = "" }
            digits += String(number)
            send("KEY_\(number)")
        } label: { digitLabel(String(number)) }
        .accessibilityLabel("Цифра \(number)")
    }

    private func digitLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 27, weight: .medium, design: .rounded))
            .frame(maxWidth: .infinity).frame(height: 74)
            .background(RemoteStyle.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func shortcut(_ title: String, icon: String, key: String) -> some View {
        Button { send(key) } label: {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 21))
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity).frame(height: 72)
            .background(RemoteStyle.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!tv.connected)
        .accessibilityLabel(title)
    }

    private func remoteIcon(_ icon: String, _ key: String, size: CGFloat = 46, tint: Color = .white) -> some View {
        Button { send(key) } label: {
            Image(systemName: icon).font(.system(size: size == 46 ? 19 : 23, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(size == 46 ? RemoteStyle.surface : Color.white.opacity(0.065), in: Circle())
        }
        .disabled(!tv.connected)
        .accessibilityLabel(key)
    }

    private func rocker(title: String, plus: String, minus: String, icon: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title).font(.system(size: 10, weight: .semibold)).tracking(1)
            }.foregroundStyle(.gray)
            HStack(spacing: 0) {
                rockerButton("plus", plus)
                Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 30)
                rockerButton("minus", minus)
            }
            .background(RemoteStyle.surface, in: RoundedRectangle(cornerRadius: 19))
        }.frame(maxWidth: .infinity)
    }

    private func rockerButton(_ icon: String, _ key: String) -> some View {
        Button { send(key) } label: {
            Image(systemName: icon).font(.title3.bold())
                .frame(maxWidth: .infinity).frame(height: 58)
        }.disabled(!tv.connected)
    }

    private func wideAction(_ title: String, icon: String, key: String) -> some View {
        Button { send(key) } label: {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: 49)
                .background(RemoteStyle.surface, in: RoundedRectangle(cornerRadius: 16))
        }.disabled(!tv.connected)
    }

    private var connectionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("IP-адрес Samsung TV").font(.headline)
                TextField("192.168.0.101", text: $tv.ip)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                Text(tv.status).font(.footnote).foregroundStyle(.secondary)
                Button("Подключиться") { tv.connect() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Text("iPhone и телевизор должны находиться в одной Wi-Fi сети. При первом подключении подтвердите разрешение на экране Samsung.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(22)
            .navigationTitle("Подключение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { showConnection = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func send(_ key: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tv.key(key)
    }
}
