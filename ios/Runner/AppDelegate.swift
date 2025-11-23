import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

  // Create a blur view to hide content
  var securityBlurEffectView: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Listen for Screen Recording capture status changes
    NotificationCenter.default.addObserver(self, selector: #selector(preventScreenRecording), name: UIScreen.capturedDidChangeNotification, object: nil)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 1. Hide content in App Switcher
  override func applicationWillResignActive(_ application: UIApplication) {
      // Only apply in Release mode (Swift uses flags differently, but simple logic works)
      #if !DEBUG
      if let window = self.window {
          let blurEffect = UIBlurEffect(style: .dark)
          securityBlurEffectView = UIVisualEffectView(effect: blurEffect)
          securityBlurEffectView?.frame = window.frame
          window.addSubview(securityBlurEffectView!)
      }
      #endif
      super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
      securityBlurEffectView?.removeFromSuperview()
      super.applicationDidBecomeActive(application)
  }

  // 2. Detect Screen Recording and Blackout
  @objc func preventScreenRecording() {
      #if !DEBUG
      if UIScreen.main.isCaptured {
          // Recording started: Add blur or show alert
          if let window = self.window {
              // Re-use the blur view or create a "Recording Detected" overlay
              if securityBlurEffectView == nil {
                  let blurEffect = UIBlurEffect(style: .dark)
                  securityBlurEffectView = UIVisualEffectView(effect: blurEffect)
                  securityBlurEffectView?.frame = window.frame
                  window.addSubview(securityBlurEffectView!)
              }
          }
      } else {
          // Recording stopped
          securityBlurEffectView?.removeFromSuperview()
          securityBlurEffectView = nil
      }
      #endif
  }
}