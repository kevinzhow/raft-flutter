import Flutter
import UIKit

// Public UIKit alternate-icon API. OS state owns the choice, not a Dart cache.
final class RaftStartupPalette {
  static let colors = ["yellow", "blue", "green", "white", "pink"]
  static let names = ["blue": "AppIconBlue", "green": "AppIconGreen",
                      "white": "AppIconWhite", "pink": "AppIconPink"]
  static func selected() -> String {
    let name = UIApplication.shared.alternateIconName
    return names.first(where: { $0.value == name })?.key ?? "yellow"
  }

  /// Background of the selected icon (the tile colour).
  static func iconColor() -> UIColor {
    let hex: UInt32
    switch selected() {
    case "blue": hex = 0x27CCF3
    case "green": hex = 0xA9D877
    case "white": hex = 0xFFFFFF
    case "pink": hex = 0xFE7DA8
    default: hex = 0xFFD440
    }
    return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                   green: CGFloat((hex >> 8) & 255) / 255,
                   blue: CGFloat(hex & 255) / 255, alpha: 1)
  }

  /// The appearance the user stored in Appearance settings. Flutter's
  /// shared_preferences keeps it in UserDefaults.standard under `flutter.raft.mode`
  /// (system | light | dark); "system" follows the scene's current style.
  static func isDark(system: UIUserInterfaceStyle) -> Bool {
    switch UserDefaults.standard.string(forKey: "flutter.raft.mode") {
    case "dark": return true
    case "light": return false
    default: return system == .dark
    }
  }

  /// Page-body colour of the stored theme (the mobile home paints
  /// `layer-canvas-muted`): white Brutal light, #F8F8F7 Elegant light, #0D0D0B
  /// dark. Both colour sets also hold the dark value; LaunchBackground is the
  /// system LaunchScreen background (default Brutal family).
  static func canvas(dark: Bool) -> UIColor {
    let elegant = UserDefaults.standard.string(forKey: "flutter.raft.light") == "elegant"
    let name = elegant ? "LaunchBackgroundElegant" : "LaunchBackground"
    return UIColor(named: name, in: nil,
                   compatibleWith: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
      ?? (dark ? UIColor(red: 13 / 255, green: 13 / 255, blue: 11 / 255, alpha: 1) : .white)
  }
}

class SceneDelegate: FlutterSceneDelegate {
  static let tileSize: CGFloat = 112

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let controller = window?.rootViewController as? FlutterViewController else { return }
    // The system LaunchScreen is static (light/dark canvas, no icon: iOS cannot
    // change it per user choice). This view takes over at once with the stored
    // theme's canvas and the chosen icon as a centred tile, and disappears at
    // the first rendered Flutter frame.
    var system = (scene as? UIWindowScene)?.traitCollection.userInterfaceStyle ?? .unspecified
    if system == .unspecified { system = UIScreen.main.traitCollection.userInterfaceStyle }
    let startup = UIView()
    startup.backgroundColor = RaftStartupPalette.canvas(
      dark: RaftStartupPalette.isDark(system: system))
    let tile = UIView()
    tile.translatesAutoresizingMaskIntoConstraints = false
    tile.backgroundColor = RaftStartupPalette.iconColor()
    tile.layer.cornerRadius = SceneDelegate.tileSize * 0.2237
    tile.layer.cornerCurve = .continuous
    tile.clipsToBounds = true
    let mark = UIImageView(image: UIImage(named: "LaunchMark", in: nil,
                    compatibleWith: UITraitCollection(userInterfaceStyle: .light)))
    mark.translatesAutoresizingMaskIntoConstraints = false
    mark.contentMode = .scaleAspectFit
    tile.addSubview(mark)
    startup.addSubview(tile)
    NSLayoutConstraint.activate([
      tile.widthAnchor.constraint(equalToConstant: SceneDelegate.tileSize),
      tile.heightAnchor.constraint(equalToConstant: SceneDelegate.tileSize),
      tile.centerXAnchor.constraint(equalTo: startup.centerXAnchor),
      tile.centerYAnchor.constraint(equalTo: startup.centerYAnchor),
      // LaunchMark has a .92 fill ratio; the app icon mark fills .625 of the tile.
      mark.widthAnchor.constraint(equalTo: tile.widthAnchor, multiplier: 0.625 / 0.92),
      mark.heightAnchor.constraint(equalTo: tile.heightAnchor, multiplier: 0.625 / 0.92),
      mark.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
      mark.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
    ])
    // Flutter's public splashScreenView owns layout and first-render removal;
    // no timer, display callback replacement or extra UIWindow is required.
    controller.splashScreenView = startup
  }
}
