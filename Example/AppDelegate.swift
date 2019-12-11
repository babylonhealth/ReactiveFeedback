//
//  AppDelegate.swift
//  ReactiveFeedback
//
//  Created by sergdort on 28/08/2017.
//  Copyright © 2017 sergdort. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Comment these lines if you want to see multi store example
        window?.rootViewController = RootViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
