//
//  AppDelegate.swift
//  Toy
//
//  Created by Maxim Kitaygora on 1/21/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import UIKit
import UserNotifications
import PushKit
import FBSDKCoreKit
import FBSDKShareKit
import FBSDKLoginKit


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    //----------------------------------------------------------------------
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {

        // Override point for customization after application launch.
        
        // Push notifications
        let deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as! String?
        if (deviceToken == nil) {
            if #available(iOS 10.0, *) {
                let center = UNUserNotificationCenter.current()
                center.delegate = self
                center.getDeliveredNotifications(completionHandler: { (notifications: [UNNotification]) in
                    if notifications.count != 0 {
                        print(notifications)
                        center.removeAllDeliveredNotifications()
                    }
                })
                
                center.requestAuthorization(options: [.alert, .badge], completionHandler: { (granted, error) in
                    if granted == true {
                        print("DBG: Access to notifications granted")
                        application.registerForRemoteNotifications()
                    }
                })
                
            } else {
                let settings = UIUserNotificationSettings(types: [.alert, .badge], categories: nil)
                application.registerUserNotificationSettings(settings)
                application.applicationIconBadgeNumber = 0
                application.registerForRemoteNotifications()
            }
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    //----------------------------------------------------------------------
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        let sourceApplication: String? = options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String
        if url == NSURL(string: "KiQToy://twitter")! as URL {
            UserDefaults.standard.set("twitter", forKey: "launchedFor")
            UserDefaults.standard.synchronize();
            return true
        }
        if url == NSURL(string: "KiQToy://fb")! as URL {
            UserDefaults.standard.set("fb", forKey: "launchedFor")
            UserDefaults.standard.synchronize();            return true
        }
        if url == NSURL(string: "KiQToy://main")! as URL {
            UserDefaults.standard.set("main", forKey: "launchedFor")
            UserDefaults.standard.synchronize();
            return true
        }
        
        return FBSDKApplicationDelegate.sharedInstance().application(app, open: url, sourceApplication: sourceApplication, annotation: nil)
    }
    
    //----------------------------------------------------------------------
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    //----------------------------------------------------------------------
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    //----------------------------------------------------------------------
    func applicationWillEnterForeground(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    //----------------------------------------------------------------------
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    //----------------------------------------------------------------------
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        let loginManager: FBSDKLoginManager = FBSDKLoginManager()
        loginManager.logOut()
    }
    
    //----------------------------------------------------------------------
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Called when the application is getting token for remorte notifications
        

        let deviceTokenDataString: String = deviceToken.base64EncodedString()
        let decodedData = NSData(base64Encoded: deviceTokenDataString, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters) as NSData?
        if decodedData == nil {
            UserDefaults.standard.set("", forKey: "deviceToken")
        } else {
            let characterSet: CharacterSet = CharacterSet( charactersIn: "<>" )
            let deviceTokenString: String = ( decodedData!.description as NSString )
                .trimmingCharacters( in: characterSet )
                .replacingOccurrences( of: " ", with: "" ) as String
            print("DBG: deviceTokenString =", deviceTokenString)
            UserDefaults.standard.set(deviceTokenString, forKey: "deviceToken")
        }
        UserDefaults.standard.synchronize();
    }
    
    //----------------------------------------------------------------------
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Called when the application has failed to get token for remorte notifications
        #if DEBUG
            print("ERROR: Could not get token data, Error: ", error)
        #endif
    }


}

