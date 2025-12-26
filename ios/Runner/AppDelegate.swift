import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Log app delegate initialization
    print("[AppDelegate] didFinishLaunchingWithOptions called")
    
    // Initialize Firebase
    print("[AppDelegate] Initializing Firebase...")
    FirebaseApp.configure()
    print("[AppDelegate] Firebase initialized successfully")
    
    // Initialize Google Maps with error handling
    do {
      print("[AppDelegate] Initializing Google Maps...")
      GMSServices.provideAPIKey("AIzaSyA0D0dfua7LuH18-OZL-4OI5lLj7XP6bqg")
      print("[AppDelegate] Google Maps API key provided successfully")
    } catch {
      print("[AppDelegate ERROR] Failed to initialize Google Maps: \(error)")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    print("[AppDelegate] Plugin registration complete")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
