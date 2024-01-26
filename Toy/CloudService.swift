//
//  CloudService.swift
//  Toy
//
//  Created by Maxim Kitaygora on 2/24/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit

//************************************************************************
// Structures to work with the Cloud -------------------------------------
//----------------------------------------------------------------------
struct SessionSettings {
    var sessionType:            String = ""
    var clientID:               UInt32 = 0
    var volume:                 UInt8  = 50
    var voiceType:              UInt8  = 0
    var silentSettings:         SilentTimeSettings = SilentTimeSettings()
    var userProfile:            UserProfile = UserProfile()
    var toyProfile:             ToyProfile = ToyProfile()
    var offlineCahngeMade :     Bool = false
    
}

//----------------------------------------------------------------------
struct SilentTimeSettings {
    var isDndOn:        Bool = false
    var start:          Date?
    var end:            Date?
    init(){
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        start = dateFormatter.date(from: "09:00")
        end = dateFormatter.date(from: "10:00")
    }
}

//----------------------------------------------------------------------
struct UserProfile {
    var name: String = ""
    var email: String = ""
    var phone: String = ""
}

//----------------------------------------------------------------------
struct ToyProfile {
    var toyID:                  String = ""
    var toyName:                String = ""
    var deviceInfo:             DeviceInfo = DeviceInfo()
    var notifSettings =         [[NotificationItem]()]
}

//----------------------------------------------------------------------
class CloudService: NSObject, URLSessionDataDelegate{
    
    // MARK: Properties
    private var cloudSession: Foundation.URLSession?
    private var isConnectionEstablished: Bool = false
    private var isSessionEnabled : Bool = false
    private let serverURL = "https://cloud.kiqtoy.com"
    private var localSettings : SessionSettings?
    
    // MARK: Functions
    
    //**************************************************************************
    // MARK: processing JSON
    //---------------------------------------------------------------------
    func getStringFromJSON(key: String, json: [String: AnyObject]) -> String {
        guard let string = json[key] as? String
            else { return ""}
        
        return string
    }
    
    
    //---------------------------------------------------------------------
    func getIntFromJSON(key: String, json: [String: AnyObject]) -> Int {
        guard let int = json[key] as? Int
            else { return 0}
        
        return int
    }
    
    //---------------------------------------------------------------------
    func getBoolFromJSON(key: String, json: [String: AnyObject]) -> Bool {
        guard let bool = json[key] as? Bool
            else { return false}
        
        return bool
    }
    
    //---------------------------------------------------------------------
    func getDateFromJSON(key: String, json: [String: AnyObject]) -> Date? {
        guard let dateString = json[key] as? String
            else { return nil}
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.locale = Locale.init(identifier: "en_US_POSIX")
        return dateFormatter.date(from: dateString)
    }
    
    //*******************************************************************************
    // Cloud functions
    //---------------------------------------------------------
    
    @objc func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data){
        
    }
    
    //---------------------------------------------------------
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        #if DEBUG
            print("DBG: URLSession: didCompleteWithError")
        #endif
    }
    
    //---------------------------------------------------------
    func isCloudSessionEnabled()->Bool{
        return isSessionEnabled
    }
    
    //---------------------------------------------------------    
    func initCloudService (){
        if isConnectionEstablished == false {
            #if DEBUG
                print("DBG: initCloudService: started")
            #endif
            self.cloudSession = {
                let config: URLSessionConfiguration = URLSessionConfiguration.default
                
                config.allowsCellularAccess = true
                config.httpShouldSetCookies = true
                config.httpCookieAcceptPolicy = HTTPCookie.AcceptPolicy.onlyFromMainDocumentDomain
                config.httpCookieStorage?.cookieAcceptPolicy = HTTPCookie.AcceptPolicy.onlyFromMainDocumentDomain
                let session : Foundation.URLSession = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: nil)
                isConnectionEstablished = true
                return session
            }()
            
            localSettings = SessionSettings()
            
            
            if isLoggedIn() == true {
                //The User is logged in
                if centralController.toyNavViewController?.view.window == nil {
                    centralController.present(centralController.toyNavViewController!, animated:true, completion: nil)
                }
                getUserData(){ (success, userData) -> Void in
                    if success == true {
                        centralController.startBLEConnection(userData)
                    } else {
                        self.logMessageToCloud("ERROR: initCloudService: failed getting userData. Will try to use a local one")
                        if userData.clientID != 0 {
                            centralController.startBLEConnection(userData)
                        } else {
                            self.setLoggedIn(0, loginType: "")
                            centralController.present(centralController.loginViewController!, animated:true, completion: nil)
                            centralController.presentLoginViewController = false
                        }
                    }
                }
            } else {
                // Need to pass the User through the Login procedure
                if centralController.presentLoginViewController == true {
                    #if DEBUG
                        self.logMessageToCloud("NORMAL: initCloudService: new User will sign in")
                    #endif
                    centralController.present(centralController.loginViewController!, animated:true, completion: nil)
                    centralController.presentLoginViewController = false
                }
            }
        }
    }
    
    
    //---------------------------------------------------------
    func deinitCloudService (){
        if isConnectionEstablished == true{
            #if DEBUG
                print("DBG: deinitCloudService")
            #endif
            self.cloudSession?.invalidateAndCancel()
            isSessionEnabled = false
            isConnectionEstablished = false
        }
    }
    
    //---------------------------------------------------------
    //base function for all requests to the cloud - sending POST request to the cloud Server
    func makePOSTrequest (_ json: AnyObject, url: URL, completion: @escaping (_ success: Bool, _ response: AnyObject?) -> Void) {
        
        var success = false
        var error = ""
        defer{
            if success == false {
                completion(false, error as AnyObject?)
            }
        }
        guard isConnectionEstablished == true
            else {
                error = "makePOSTrequest -> connection is not established"
                return
        }
        
        let urlRequest : NSMutableURLRequest = NSMutableURLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: 60)
        
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if JSONSerialization.isValidJSONObject(json) {
            guard let httpBody = try? JSONSerialization.data (withJSONObject: json, options: JSONSerialization.WritingOptions(rawValue: 0))
                else {
                    error = "ERROR: makePOSTrequest -> Error in dataWithJSONObject"
                    completion(false, error as AnyObject?)
                    return
            }
            
            urlRequest.httpBody = httpBody
            
            success = true
            let task = self.cloudSession!.dataTask(with: urlRequest as URLRequest){ (data, response, error) -> Void in
                DispatchQueue.main.async{
                    guard error == nil else {
                        let error = "ERROR: makePOSTrequest -> Error in dataTaskWithRequest"
                        completion(false, error as AnyObject?)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode != 200 {
                            let error = "ERROR: makePOSTrequest -> HTTP response statusCode error = " + String(httpResponse.statusCode)
                            completion(false, error as AnyObject?)
                            return
                        }
                    } else {
                        let error = "ERROR: HmakePOSTrequest -> TTP response is invalid "
                        completion(false, error as AnyObject?)
                        return
                    }
                    
                    guard let jsonReceived = try? JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                        else {
                            completion(false, "makePOSTrequest -> ERROR: Received JSON is incorrect" as AnyObject?)
                            return
                    }
                    
                    guard let success = jsonReceived!["success"] as? NSNumber
                        else {
                            completion(false, "makePOSTrequest -> ERROR: Received success is incorrect" as AnyObject?)
                            return
                    }
                    if success != 1 {
                        guard let cloudError = jsonReceived!["error"] as? String
                            else {
                                completion(false, "dataTaskWithRequest unsuccessful, with invalid error" as AnyObject?)
                                return
                        }
                        let error = "error received =  " + cloudError
                        completion(false, error as AnyObject?)
                        return
                    }
                    completion(true, jsonReceived as AnyObject?)
                }
            }
            task.resume()
        } else {
            error = "makePOSTrequest -> isValidJSONObject - false"
        }
    }
    
    //**************************************************************************
    //MARK: Signe Up
    
    //---------------------------------------------------------
    func processFacebookLogin(_ facebookID: String, name: String, email: String, completion: @escaping (_ success: Bool) -> Void){
        var success: Bool = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isConnectionEstablished == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/auth")
            else { return }
        
        let data: [String : AnyObject] = [
            "facebook_id" : facebookID as AnyObject,
            "name" : name as AnyObject,
            "email": email as AnyObject
        ]
        
        let version = UIDevice.current.systemVersion
        let deviceInfo: [String : AnyObject] = [
            "type" : "iOS" as AnyObject,
            "version": version as AnyObject
        ]
        
        var deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as! String?
        if deviceToken == nil {
            deviceToken = ""
        }
        
        let json: [String : AnyObject] = [
            "auth_type": "facebook" as AnyObject,
            "data" : data as AnyObject,
            "device_token": deviceToken! as AnyObject,
            "device_info": deviceInfo as AnyObject,
            "app_version": APP_VERSION as AnyObject
        ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (callbackSuccess, response) -> Void in
            var success = callbackSuccess
            defer {
                if success == false {
                    completion(success)
                }
            }
            if success != true {
                self.logMessageToCloud("ERROR: processFacebookLogin error = " + String(describing: response))
            } else {
                success = false
                guard let user = response!["user"] as? [String : AnyObject],
                    let clientID = user["client_id"] as? Int
                    else { return }
                if clientID != 0 {
                    self.setLoggedIn(UInt32(clientID), loginType: "facebook")
                    success = true
                    self.getUserData(){ (callbackSuccess, response) -> Void in
                        success = callbackSuccess
                        if success == true {
                            completion(true)
                        }
                    }
                } else {
                    self.logMessageToCloud ("ERROR: processFacebookLogin - > ClientID is null")
                }
            }
        }
    }

    // Sending phone number to the server. SMS with a verification code will be sent
    // to the provided phone number.
    //---------------------------------------------------------
    func startPhoneLogin (_ phoneNumber: String, completion: @escaping (_ success: Bool, _ response: String?) -> Void){
        var success: Bool = false
        defer {
            if success == false {
                completion(false, "")
            }
        }
        guard isConnectionEstablished == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/reqSmsCode")
            else { return }
        
        let json: [String : AnyObject] = [
            "phone_number" : phoneNumber as AnyObject
        ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            completion(success, "phone")
        }
    }
    
    //---------------------------------------------------------
    func processSMSCode(_ verificationNumber: String, completion: @escaping (_ success: Bool) -> Void){
        var success: Bool = false
        
        defer {
            if success == false {
                completion(false)
            }
        }
        
        guard isConnectionEstablished == true
            else {
                #if DEBUG
                    print ("ERROR: processFacebookLogin -> connection is not stablished")
                #endif
                return
        }
        
        guard let url = URL(string: serverURL + "/m_app/auth")
            else {
                #if DEBUG
                    print ("ERROR: processFacebookLogin -> can not get NSURL")
                #endif
                return
        }
        
        let name : String = ""
        let email: String = ""
        
        let data: [String : AnyObject] = [
            "smscode" : verificationNumber as AnyObject,
            "name" : name as AnyObject,
            "email": email as AnyObject
        ]
        
        var deviceToken = UserDefaults.standard.object(forKey: "deviceToken") as! String?
        if deviceToken == nil {
            deviceToken = ""
        }
        
        let version = UIDevice.current.systemVersion
        let deviceInfo: [String : AnyObject] = [
            "type" : "iOS" as String as AnyObject,
            "version": version as AnyObject
        ]
        
        let json: [String : AnyObject] = [
            "auth_type": "smscode" as AnyObject,
            "data" : data as AnyObject,
            "device_token": deviceToken! as AnyObject,
            "device_info": deviceInfo as AnyObject,
            "app_version": APP_VERSION as AnyObject
        ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (callbackSuccess, response) -> Void in
            var success = callbackSuccess
            defer {
                if success == false {
                    completion(success)
                }
            }
            if success != true {
                #if DEBUG
                    print ("processSMSCode error = " + String(describing: response))
                #endif
            } else {
                guard let user = response!["user"] as? [String : AnyObject],
                    let clientID = user["client_id"] as? Int
                    else { return }
                if clientID != 0 {
                    if self.localSettings?.sessionType.isEmpty == true {
                        self.setLoggedIn(UInt32(clientID), loginType: "phone")
                    }
                    self.getUserData(){ (callbackSuccess, response) -> Void in
                        success = callbackSuccess
                        if success == true {
                            completion(true)
                        }
                    }
                } else {
                    #if DEBUG
                        print ("ERROR: processSMSCode - > ClientID is null")
                    #endif
                }
            }
        }
    }
    
    //---------------------------------------------------------
    func resendVerificationCode(_ completion: @escaping (_ success: Bool) -> Void){

        var success = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isConnectionEstablished == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/resendSmsCode")
            else { return }
        
        let json: [String : AnyObject] = [
            "code": "resend" as AnyObject
            ]
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            completion(success)
        }
    }
    
    
    
    
    //---------------------------------------------------------
    func getUserData(_ completion: @escaping (_ success: Bool, _ userData: SessionSettings) -> Void){
        getBaseInfo()
        var success = false
        defer {
            if success == false {
                completion(false, localSettings!)
                #if DEBUG
                    print ("ERROR: getUserData failed")
                #endif
            }
        }
        guard isConnectionEstablished == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/getUserData")
            else { return }
        
        let json: [String : AnyObject] = [
            "data": "" as AnyObject
        ]
        
        success = true
        #if DEBUG
            logMessageToCloud("DBG: getUserData -> sending request")
        #endif
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                #if DEBUG
                    print ("ERROR: getUserData error = ", response ?? "Unknown error")
                #endif
                completion(false, self.localSettings!)
            } else {
                //print(response)
                guard let data = response!["data"] as? [String: AnyObject],
                    let userData = data["user_data"] as? [String: AnyObject]
                    else {
                        #if DEBUG
                            self.logMessageToCloud ("ERROR: getUserData: parsing JSON.data")
                        #endif
                        completion(false, self.localSettings!)
                        return
                }
                self.isSessionEnabled = true // Server is responding
                
                self.localSettings!.userProfile.name = self.getStringFromJSON(key: "name", json: userData)
                self.localSettings!.userProfile.email = self.getStringFromJSON(key: "email", json: userData)
                self.localSettings!.userProfile.phone = self.getStringFromJSON(key: "phone_number", json: userData)
                
                if self.localSettings?.toyProfile.toyID.isEmpty == false { // Some toy was already connected to the phone
                    let userToys = userData["user_toys"] as? NSArray
                    if userToys != nil && (userToys?.count)! > 0 {
                        for i in 0 ..< userToys!.count {
                            guard let userToy  = userToys!.object(at: i) as? NSDictionary,
                                let toyID =      userToy.value(forKey: "toy_id") as? String
                                else {
                                    #if DEBUG
                                        print ("ERROR: getUserData: parsing JSON.userToys")
                                    #endif
                                    completion(false, self.localSettings!)
                                    return
                            }
                            if self.localSettings?.toyProfile.toyID == toyID { // This toy was connected to the phone
                                guard let settings =      userToy.value(forKey: "settings") as? [String: AnyObject],
                                    let notifications = settings["notifications"] as? NSDictionary,
                                    let calls =         notifications.value(forKey: "calls") as? [NSDictionary],
                                    let messages =      notifications.value(forKey: "messages") as? [NSDictionary],
                                    let other =         notifications.value(forKey: "other") as? [NSDictionary]
                                else {
                                    #if DEBUG
                                        print ("ERROR: getUserData: parsing JSON.userToys")
                                    #endif
                                    completion(false, self.localSettings!)
                                    return
                                }
                                
                                if self.localSettings!.offlineCahngeMade == false {
                                    self.localSettings!.toyProfile.toyName = self.getStringFromJSON(key: "toy_name", json: settings)
                                    var volume = UInt8(self.getIntFromJSON(key: "volume", json: settings))
                                    if volume == 0 {
                                        volume = self.localSettings!.volume
                                    } else {
                                        self.localSettings!.volume = volume
                                    }
                                    self.localSettings!.voiceType = UInt8(self.getIntFromJSON(key: "voice_type", json: settings))
                                    
                                    self.localSettings!.silentSettings.isDndOn = self.getBoolFromJSON(key: "silent", json: settings)
                                    let silentStart = self.getDateFromJSON(key: "silent_start", json: settings)
                                    let silentEnd = self.getDateFromJSON(key: "silent_end", json: settings)
                                    if silentStart != nil && silentEnd != nil {
                                        self.localSettings!.silentSettings.start = silentStart
                                        self.localSettings!.silentSettings.end = silentEnd
                                        
                                    }
                                    for j in 0 ..< calls.count { // Parsing Settings - Notification Settings -> Calls
                                        let notification = NotificationItem(text: "", on: true, bit: 0)!
                                        notification.text = self.getStringFromJSON(key: "title", json: calls[j] as! [String : AnyObject])
                                        notification.on = self.getBoolFromJSON(key: "value", json: calls[j] as! [String : AnyObject])
                                        notification.bit = self.getIntFromJSON(key: "bit", json: calls[j] as! [String : AnyObject])
                                        if notification.text.isEmpty == true {
                                            #if DEBUG
                                                self.logMessageToCloud ("ERROR: getUserData: parsing Notifications->Calls")
                                            #endif
                                            break
                                        }
                                        if self.localSettings?.toyProfile.notifSettings.count == 0 {
                                            self.localSettings?.toyProfile.notifSettings.append([NotificationItem]())
                                        }
                                        if (self.localSettings?.toyProfile.notifSettings[0].count)! <= j {
                                            self.localSettings?.toyProfile.notifSettings[0].append(notification)
                                        } else {
                                            self.localSettings?.toyProfile.notifSettings[0][j] = notification
                                        }
                                    }
                                    for j in 0 ..< messages.count { // Parsing Settings - Notification Settings -> Messages
                                        let notification = NotificationItem(text: "", on: true, bit: 0)!
                                        notification.text = self.getStringFromJSON(key: "title", json: messages[j] as! [String : AnyObject])
                                        notification.on = self.getBoolFromJSON(key: "value", json: messages[j] as! [String : AnyObject])
                                        notification.bit = self.getIntFromJSON(key: "bit", json: messages[j] as! [String : AnyObject])
                                        
                                        if notification.text.isEmpty == true {
                                            #if DEBUG
                                                self.logMessageToCloud ("ERROR: getUserData: parsing Notifications->Messages")
                                            #endif
                                            break
                                        }
                                        
                                        if self.localSettings?.toyProfile.notifSettings.count == 1 {
                                            self.localSettings?.toyProfile.notifSettings.append([NotificationItem]())
                                        }
                                        if (self.localSettings?.toyProfile.notifSettings[1].count)! <= j {
                                            self.localSettings?.toyProfile.notifSettings[1].append(notification)
                                        } else {
                                            self.localSettings?.toyProfile.notifSettings[1][j] = notification
                                        }
                                    }
                                    for j in 0 ..< other.count { // Parsing Settings - Notification Settings -> Others
                                        let notification = NotificationItem(text: "", on: true, bit: 0)!
                                        notification.text = self.getStringFromJSON(key: "title", json: other[j] as! [String : AnyObject])
                                        notification.on = self.getBoolFromJSON(key: "value", json: other[j] as! [String : AnyObject])
                                        notification.bit = self.getIntFromJSON(key: "bit", json: other[j] as! [String : AnyObject])
                                        
                                        if notification.text.isEmpty == true {
                                            #if DEBUG
                                                self.logMessageToCloud ("ERROR: getUserData: parsing Notifications->Others")
                                            #endif
                                            break
                                        }
                                        
                                        if self.localSettings?.toyProfile.notifSettings.count == 2 {
                                            self.localSettings?.toyProfile.notifSettings.append([NotificationItem]())
                                        }
                                        if (self.localSettings?.toyProfile.notifSettings[2].count)! <= j {
                                            self.localSettings?.toyProfile.notifSettings[2].append(notification)
                                        } else {
                                            self.localSettings?.toyProfile.notifSettings[2][j] = notification
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                
                if self.localSettings!.offlineCahngeMade == true && self.localSettings?.toyProfile.toyID.isEmpty == false{
                    #if DEBUG
                        print ("DBG: There was offline change. Updtating Cloud")
                    #endif
                    self.updateToy(self.localSettings!)
                } else {
                    self.saveBaseInfo()
                }
    
                #if DEBUG
                    print ("DBG: getUserData -> data updated")
                #endif
                completion(true, self.localSettings!)
            }
        }
    }
    
    //**************************************************************************
    //MARK: Processing USER Data
    
    //----------------- Update User -------------------------------
    //---------------------------------------------------------
    func updateUser(_ sessionSettings: SessionSettings, completion: ((_ success: Bool) -> Void)? = nil){
        var success = false
        defer {
            if success == false {
                completion?(false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/updateUserData")
            else { return }
        
        let json: [String : AnyObject] = [
            "email":       sessionSettings.userProfile.email as AnyObject,
            "name":        sessionSettings.userProfile.name as AnyObject
        ]
        success = true
        #if DEBUG
            print ("DBG: updateUser -> sending data")
        #endif
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                #if DEBUG
                    print ("ERROR: updateUser error = ", response ?? "Unknown error")
                #endif
            }
            completion?(success)
        }
    }

    
    //**************************************************************************
    //MARK: Processing TOY Data
    
    //----------------- Add Toy -------------------------------
    //---------------------------------------------------------
    func addToy(_ sessionSettings: SessionSettings, completion: @escaping (_ success: Bool) -> Void){
        var success = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/addToy")
            else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.locale = locale
        
        let settings: [String : AnyObject] = [
            "toy_name":         sessionSettings.toyProfile.toyName as AnyObject
            ]
        
        let json: [String : AnyObject] = [
            "toy_id":       sessionSettings.toyProfile.toyID as AnyObject,
            "settings":     settings as AnyObject,
            "model":        Int(sessionSettings.toyProfile.deviceInfo.model) as AnyObject,
            "revision":     Int(sessionSettings.toyProfile.deviceInfo.revision) as AnyObject,
            //"esp":          Int(sessionSettings.toyProfile.deviceInfo.ESPversion) as AnyObject,
            //"nrf":          Int(sessionSettings.toyProfile.deviceInfo.NRFversion) as AnyObject,
            //"version":         Int(sessionSettings.toyProfile.deviceInfo.packVersion)as AnyObject

        ]
        success = true
        #if DEBUG
            print ("DBG: addToy -> sending data")
        #endif
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                #if DEBUG
                    print ("ERROR: addToy error = ", response ?? "Unknown error")
                #endif
            } else {
                self.localSettings = sessionSettings
                self.saveBaseInfo()
            }
            completion(success)
        }
    }
    
    //----------------- Update Toy -------------------------------
    //---------------------------------------------------------
    func updateToy(_ sessionSettings: SessionSettings){
        localSettings = sessionSettings
        saveBaseInfo()
        var success = false
        defer {
            if success == false {
                offlineChangeMade(true)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/updateToyData")
            else { return }
        
        var call = [String : AnyObject]()
        var calls = [[String : AnyObject]()]
        var message = [String : AnyObject]()
        var messages = [[String : AnyObject]()]
        var other = [String : AnyObject]()
        var others = [[String : AnyObject]()]
        if localSettings!.toyProfile.notifSettings.count == 3 {
            for i in 0 ..< localSettings!.toyProfile.notifSettings[0].count {
                let notification = localSettings!.toyProfile.notifSettings[0][i]
                call.updateValue(notification.text as AnyObject, forKey: "title")
                call.updateValue(notification.on as AnyObject, forKey: "value")
                call.updateValue(notification.bit as AnyObject, forKey: "bit")
                if i == 0 {
                    calls[0] = call
                } else {
                    calls.append(call)
                }
            }
            
            for i in 0 ..< localSettings!.toyProfile.notifSettings[1].count {
                let notification = localSettings!.toyProfile.notifSettings[1][i]
                message.updateValue(notification.text as AnyObject, forKey: "title")
                message.updateValue(notification.on as AnyObject, forKey: "value")
                message.updateValue(notification.bit as AnyObject, forKey: "bit")
                if i == 0 {
                    messages[0] = message
                } else {
                    messages.append(message)
                }

            }
            
            for i in 0 ..< localSettings!.toyProfile.notifSettings[2].count {
                let notification = localSettings!.toyProfile.notifSettings[2][i]
                other.updateValue(notification.text as AnyObject, forKey: "title")
                other.updateValue(notification.on as AnyObject, forKey: "value")
                other.updateValue(notification.bit as AnyObject, forKey: "bit")
                if i == 0 {
                    others[0] = other
                } else {
                    others.append(other)
                }
            }
        }
        let notifications: [String : AnyObject] = [
            "calls":    calls as AnyObject,
            "messages": messages as AnyObject,
            "other":    others as AnyObject
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.locale = locale
        
        let settings: [String : AnyObject] = [
            "volume":       Int(sessionSettings.volume) as AnyObject,
            "voice_type":   Int(sessionSettings.voiceType) as AnyObject,
            "silent":       sessionSettings.silentSettings.isDndOn as AnyObject,
            "silent_start":  dateFormatter.string(from: (sessionSettings.silentSettings.start)!) as AnyObject,
            "silent_end":    dateFormatter.string(from: (sessionSettings.silentSettings.end)!) as AnyObject,
            "toy_name":      sessionSettings.toyProfile.toyName as AnyObject,
            "notifications":  notifications as AnyObject
        ]
        
        let json: [String : AnyObject] = [
            "toy_id":           sessionSettings.toyProfile.toyID as AnyObject,
            "settings":         settings as AnyObject,
            "model":        Int(sessionSettings.toyProfile.deviceInfo.model) as AnyObject,
            "revision":     Int(sessionSettings.toyProfile.deviceInfo.revision) as AnyObject,
            //"esp":          Int(sessionSettings.toyProfile.deviceInfo.ESPversion) as AnyObject,
            //"nrf":          Int(sessionSettings.toyProfile.deviceInfo.NRFversion) as AnyObject,
            //"version":         Int(sessionSettings.toyProfile.deviceInfo.packVersion)as AnyObject,
        ]
        success = true
        #if DEBUG
            print ("DBG: updateToy -> sending data")
        #endif
        //print(json)
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                #if DEBUG
                    print ("ERROR: updateToy error = ", response ?? "Unknown error")
                #endif
                self.offlineChangeMade(true)
            } else {
                self.offlineChangeMade(false)
            }
            #if DEBUG
                print ("DBG: updateToy made with success =", success)
            #endif
        }
    }
    
    // --------------- Remove Toy -----------------------------
    //---------------------------------------------------------
    func forgetToy(_ completion: @escaping ( _ success: Bool) -> Void){
        var success = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/removeToy")
            else { return }
        
        let json: [String : AnyObject] = [
            "toy_id": self.localSettings!.toyProfile.toyID as AnyObject
        ]
        success = true
        #if DEBUG
            print ("DBG: forgetToy with ID ->" , self.localSettings!.toyProfile.toyID, "sending data")
        #endif
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success == true {
                self.localSettings!.toyProfile.toyID = ""
                self.saveBaseInfo()
            }
            completion(success)
        }
    }

    
    //**************************************************************************
    //MARK: Content related functions
    
    //------------- Get a text for jokes ----------------------
    //---------------------------------------------------------
    func updateJokes(jokes: [RecentItem], completion: @escaping (_ success: Bool, _ response: [RecentItem]?) -> Void){
        
        var success = false
        defer {
            if success == false {
                completion(false, jokes)
            }
        }
        guard isSessionEnabled == true,
            jokes.isEmpty != true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/getJokesByIds")
            else { return }
        
        var ids: [Int] = [Int]()
        for joke in jokes {
            ids.append(Int(joke.fileID))
        }
        
        let json: [String : AnyObject] = [
            "ids": ids as AnyObject
            ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (callbackSuccess, response) -> Void in
            var success = callbackSuccess
            defer {
                completion(success, jokes)
            }
            if success != true {
                #if DEBUG
                    print ("ERROR: updateJokes error = ", response ?? "Unknown error")
                #endif
            } else {
                success = false
                guard let data = response!["data"] as? NSArray
                    else { return }

                if data.count > 0 {
                    for i in 0 ..< data.count {
                        guard let dictResult = data.object(at: i) as? NSDictionary,
                            let text = dictResult.value(forKey: "text") as? String,
                            let hash = dictResult.value(forKey: "hash") as? String
                        else { return }
                        
                        var rate = dictResult.value(forKey: "rate") as? Int
                        if rate == nil {
                            rate = 0
                        }
                        jokes[i].rate = rate!
                        if i < jokes.count{
                            if hash.isEmpty == false {
                                jokes[i].fileURL = "https://" + hostname + "/jokes/getText/" + hash
                            } else {
                                jokes[i].fileURL = ""
                            }
                            let mid = dictResult.value(forKey: "male_file_id") as? Int
                            if mid != nil {
                                jokes[i].maleFileID = UInt32(mid!)
                            } else {
                                jokes[i].maleFileID = 0
                            }
                            let fid = dictResult.value(forKey: "female_file_id") as? Int
                            if fid != nil {
                                jokes[i].femaleFileID = UInt32(fid!)
                            } else {
                                jokes[i].femaleFileID = 0
                            }
                            jokes[i].text = text
                        }
                    }
                    success = true
                }
            }
        }
    }
    
    // ------ Like a Joke with ID -----------------------------
    //---------------------------------------------------------
    func likeJoke(_ joke: UInt32, liked: Bool, completion: @escaping (_ success: Bool) -> Void){
        var success = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/rateJoke")
            else { return }
        
        var like: String = "like"
        
        if liked == false{
            like = "dislike"
            
        }
        let json: [String : AnyObject] = [
            "file_id": Int(joke) as AnyObject,
            "rate": like as AnyObject
        ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                #if DEBUG
                    print ("likeJoke error = ", response ?? "Unknown error")
                #endif
            }
            completion(success)
        }
    }

    //--------- Ыутв Ауувифсл ещ еру Cloud ----------------
    //---------------------------------------------------------
    func sendFeedback (_ feedback: String, completion: @escaping (_ success: Bool) -> Void){
        var success = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/feedback")
            else { return }
        
        let json: [String : AnyObject] = [
            "text": feedback as AnyObject
        ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                self.logMessageToCloud("ERROR: sendFeedback error = " + String(describing: response))
            }
            completion(success)
        }
    }
    
    //--------- Logout from App and from Cloud ----------------
    //---------------------------------------------------------
    func logout (_ clientID: UInt32, completion: @escaping (_ success: Bool) -> Void){
        var success = false
        defer {
            if success == false {
                completion(false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/logout")
            else { return }
        
        let json: [String : AnyObject] = [
            "clientID": Int(clientID) as AnyObject
        ]
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                self.logMessageToCloud("ERROR: logout error = " + String(describing: response))
            }
            self.setLoggedIn(0, loginType: "")
            completion(success)
        }
    }
    
    //--------- Get update information ----------------
    //---------------------------------------------------------
    func getUpdateInfo (_ completion: @escaping (_ success: Bool, _ isUpdateRequired : Bool) -> Void){
        var success : Bool = false
        var isUpdateRequired : Bool = false
        defer {
            if success == false {
                completion(false, false)
            }
        }
        guard isSessionEnabled == true
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/getFirmwareByToyId")
            else { return }
        
        let json: [String : AnyObject] = [
            "toy_id": self.localSettings!.toyProfile.toyID as AnyObject,
            "version":   Int(self.localSettings!.toyProfile.deviceInfo.packVersion) as AnyObject
        ]
        
        
        success = true
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                self.logMessageToCloud ("ERROR: getUpdateInfo error = " + String(describing: response))
            } else {
                guard let data = response!["data"] as? [String: AnyObject]
                    else {
                        #if DEBUG
                            self.logMessageToCloud ("ERROR: getUpdateInfo: parsing JSON.data")
                        #endif
                        return
                        }
                isUpdateRequired = self.getBoolFromJSON(key: "required", json: data)
            }
            completion(success, isUpdateRequired)
        }
    }
    
    
    //--------- Loggin messages from application to the Cloud ----------------
    //---------------------------------------------------------
    func logMessageToCloud (_ message : String){

        #if DEBUG
            print (message)
        #endif

        guard isSessionEnabled == true && isLoggedIn()
            else { return }
        
        guard let url = URL(string: serverURL + "/m_app/log")
            else { return }
        
        let json: [String : AnyObject] = [
            "message": message as AnyObject
        ]
        
        makePOSTrequest(json as AnyObject, url: url){ (success, response) -> Void in
            if success != true {
                #if DEBUG
                    print ("ERROR: logMessageToCloud error = ", response ?? "Unknown error")
                #endif
            }
        }
 
    }
    
    //********************************************************************************
    // MARK : Offline functions
    // ----- Supplimentary functions using User Dafaults ------
    //---------------------------------------------------------
    func isLoggedIn () -> Bool{
        let clientID = UserDefaults.standard.integer(forKey: "clientID")
        if clientID == 0 {
            return false
        }
        return true
    }
    
    //---------------------------------------------------------
    func setLoggedIn (_ clientID : UInt32, loginType: String){
        if clientID != 0 {
            self.logMessageToCloud("NORMAL: user with ID: " + String(clientID) + "logged in with " + loginType)
        } else {
            self.logMessageToCloud("NORMAL: user has logged out")
        }
        UserDefaults.standard.set(Int(clientID), forKey: "clientID")
        UserDefaults.standard.set(loginType, forKey: "loginType");
        UserDefaults.standard.synchronize();
    }
    
    //---------------------------------------------------------
    func getCloudBaseInfo () ->SessionSettings {
        getBaseInfo()
        return localSettings!
    }
    
    //---------------------------------------------------------
    func getBaseInfo () {
        if localSettings == nil {
            localSettings = SessionSettings()
        }
        let clientID = UserDefaults.standard.integer(forKey: "clientID")
        localSettings!.clientID = UInt32(clientID)
        
        localSettings!.offlineCahngeMade = UserDefaults.standard.bool(forKey: "offlineChange")
        
        guard let toyID = UserDefaults.standard.string(forKey: "toyID"),
            let toyName = UserDefaults.standard.string(forKey: "toyName"),
            let silentStart = UserDefaults.standard.string(forKey: "silentStart"),
            let silentEnd = UserDefaults.standard.string(forKey: "silentEnd"),
            let sessionType = UserDefaults.standard.string(forKey: "loginType")
            else { return }
        
        let ESPversion = UserDefaults.standard.integer(forKey: "ESPversion")
        let model = UserDefaults.standard.integer(forKey: "model")
        let NRFversion = UserDefaults.standard.integer(forKey: "NRFversion")
        let packVersion = UserDefaults.standard.integer(forKey: "packVersion")
        let revision = UserDefaults.standard.integer(forKey: "revision")
        
        localSettings!.toyProfile.notifSettings.removeAll()
        let phoneCount = UserDefaults.standard.integer(forKey: "phoneCount")
        for i in 0 ..< phoneCount {
            let notification = NotificationItem(text: "", on: true, bit: 0)!
            if self.localSettings?.toyProfile.notifSettings.count == 0 {
                self.localSettings?.toyProfile.notifSettings.append([NotificationItem]())
            }
            notification.on =  UserDefaults.standard.bool(forKey: "phoneOn" + String(i))
            notification.bit =  UserDefaults.standard.integer(forKey: "phoneBit" + String(i))
            let text = UserDefaults.standard.string(forKey: "phoneText" + String(i))
            if text != nil {
                notification.text = text!
            }
            self.localSettings?.toyProfile.notifSettings[0].append(notification)
            
        }
        
        let messageCount = UserDefaults.standard.integer(forKey: "messageCount")
        for i in 0 ..< messageCount {
            let notification = NotificationItem(text: "", on: true, bit: 0)!
            if self.localSettings?.toyProfile.notifSettings.count == 1 {
                self.localSettings?.toyProfile.notifSettings.append([NotificationItem]())
            }
            notification.on =  UserDefaults.standard.bool(forKey: "messageOn" + String(i))
            notification.bit =  UserDefaults.standard.integer(forKey: "messageBit" + String(i))
            let text = UserDefaults.standard.string(forKey: "messageText" + String(i))
            if text != nil {
                notification.text = text!
            }
            self.localSettings?.toyProfile.notifSettings[1].append(notification)
            
        }
        
        let otherCount = UserDefaults.standard.integer(forKey: "otherCount")
        for i in 0 ..< otherCount {
            let notification = NotificationItem(text: "", on: true, bit: 0)!
            if self.localSettings?.toyProfile.notifSettings.count == 2 {
                self.localSettings?.toyProfile.notifSettings.append([NotificationItem]())
            }
            notification.on =  UserDefaults.standard.bool(forKey: "otherOn" + String(i))
            notification.bit =  UserDefaults.standard.integer(forKey: "otherBit" + String(i))
            let text = UserDefaults.standard.string(forKey: "otherText" + String(i))
            if text != nil {
                notification.text = text!
            }
            self.localSettings?.toyProfile.notifSettings[2].append(notification)
            
        }
        
        localSettings!.toyProfile.toyID = toyID
        localSettings!.toyProfile.toyName = toyName
        localSettings!.sessionType = sessionType
        localSettings!.volume = UInt8(UserDefaults.standard.integer(forKey: "volume"))
        localSettings!.voiceType = UInt8(UserDefaults.standard.integer(forKey: "voiceType"))
        
        
        localSettings!.toyProfile.deviceInfo.ESPversion = UInt16(ESPversion)
        localSettings!.toyProfile.deviceInfo.model = UInt16(model)
        localSettings!.toyProfile.deviceInfo.NRFversion = UInt16(NRFversion)
        localSettings!.toyProfile.deviceInfo.packVersion = UInt16(packVersion)
        localSettings!.toyProfile.deviceInfo.revision = UInt16(revision)
        
        localSettings!.silentSettings.isDndOn = UserDefaults.standard.bool(forKey: "silentEnabled")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.locale = locale
        localSettings!.silentSettings.start = dateFormatter.date(from: silentStart)
        localSettings!.silentSettings.end = dateFormatter.date(from: silentEnd)
    }
    
    //---------------------------------------------------------
    func saveCloudBaseInfo (_ settings: SessionSettings){
        localSettings = settings
        saveBaseInfo()
    }
    
    //---------------------------------------------------------
    func saveBaseInfo (){
        UserDefaults.standard.set(String(self.localSettings!.toyProfile.toyID), forKey: "toyID");
        UserDefaults.standard.set(String(self.localSettings!.toyProfile.toyName), forKey: "toyName");
        UserDefaults.standard.set(Int(self.localSettings!.volume), forKey: "volume");
        UserDefaults.standard.set(Int(self.localSettings!.voiceType), forKey: "voiceType");
        UserDefaults.standard.set(self.localSettings!.offlineCahngeMade, forKey: "offlineChange")
        
        UserDefaults.standard.set(Int(self.localSettings!.toyProfile.deviceInfo.ESPversion), forKey: "ESPversion");
        UserDefaults.standard.set(Int(self.localSettings!.toyProfile.deviceInfo.model), forKey: "model");
        UserDefaults.standard.set(Int(self.localSettings!.toyProfile.deviceInfo.NRFversion), forKey: "NRFversion");
        UserDefaults.standard.set(Int(self.localSettings!.toyProfile.deviceInfo.packVersion), forKey: "packVersion");
        UserDefaults.standard.set(Int(self.localSettings!.toyProfile.deviceInfo.revision), forKey: "revision");
        
        if localSettings!.toyProfile.notifSettings.count == 3 {
            UserDefaults.standard.set(localSettings!.toyProfile.notifSettings[0].count, forKey: "phoneCount");
            for i in 0 ..< localSettings!.toyProfile.notifSettings[0].count {
                let notification = localSettings!.toyProfile.notifSettings[0][i]
                UserDefaults.standard.set(String(notification.text), forKey: "phoneText" + String(i));
                UserDefaults.standard.set(notification.on, forKey: "phoneOn" + String(i));
                UserDefaults.standard.set(notification.bit, forKey: "phoneBit" + String(i));
            }
            UserDefaults.standard.set(localSettings!.toyProfile.notifSettings[1].count, forKey: "messageCount");
            for i in 0 ..< localSettings!.toyProfile.notifSettings[1].count {
                let notification = localSettings!.toyProfile.notifSettings[1][i]
                UserDefaults.standard.set(String(notification.text), forKey: "messageText" + String(i));
                UserDefaults.standard.set(notification.on, forKey: "messageOn" + String(i));
                UserDefaults.standard.set(notification.bit, forKey: "messageBit" + String(i));
            }
            UserDefaults.standard.set(localSettings!.toyProfile.notifSettings[2].count, forKey: "otherCount");
            for i in 0 ..< localSettings!.toyProfile.notifSettings[2].count {
                let notification = localSettings!.toyProfile.notifSettings[2][i]
                UserDefaults.standard.set(String(notification.text), forKey: "otherText" + String(i));
                UserDefaults.standard.set(notification.on, forKey: "otherOn" + String(i));
                UserDefaults.standard.set(notification.bit, forKey: "otherBit" + String(i));
            }
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let locale = Locale.init(identifier: "en_US_POSIX")
        dateFormatter.locale = locale
        UserDefaults.standard.set(dateFormatter.string(from: (self.localSettings!.silentSettings.start)!),forKey: "silentStart")
        UserDefaults.standard.set(dateFormatter.string(from: (self.localSettings!.silentSettings.end)!),forKey: "silentEnd")
        UserDefaults.standard.set(self.localSettings!.silentSettings.isDndOn, forKey: "silentEnabled")
        
        UserDefaults.standard.synchronize();
    }
    
    //---------------------------------------------------------
    func offlineChangeMade (_ status: Bool){
        UserDefaults.standard.set(status, forKey: "offlineChange")
    }
}
