//
//  BLEViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 1/28/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth
import FBSDKCoreKit
import FBSDKShareKit
import FBSDKLoginKit

let APP_VERSION : String = "0.1.3"
let hostname: String = "cloud.kiqtoy.com"

//------------ UI Colors definition -----------------------------------------------------
let MY_RED_COLOR =  UIColor.init(hexString: "ff3b30")
let MY_PINK_COLOR =  UIColor.init(hexString: "ff2d55")
let MY_BLUE_COLOR = UIColor.init(hexString: "007aff")
let MY_GREEN_COLOR = UIColor.init(hexString: "4cd964")

// ------- Extension to simplify working with UInt and String -----------------------------
extension String {
    func toUInt() -> UInt? {
        let scanner = Scanner(string: self)
        var u: UInt64 = 0
        if scanner.scanUnsignedLongLong(&u)  && scanner.isAtEnd {
            return UInt(u)
        }
        return 0
    }
}

// ------- Extension to simplify working with NSData --------------------------------------
extension NSData {
    var i8s:[Int8] { // Array of UInt8, Swift byte array basically
        var buffer:[Int8] = [Int8](repeating: 0, count: self.length)
        self.getBytes(&buffer, length: self.length)
        return buffer
    }
    
    var u8s:[UInt8] { // Array of UInt8, Swift byte array basically
        var buffer:[UInt8] = [UInt8](repeating: 0, count: self.length)
        self.getBytes(&buffer, length: self.length)
        return buffer
    }

    var u16s:[UInt16] { // Array of UInt16, Swift byte array basically
        var buffer:[UInt16] = [UInt16](repeating: 0, count: self.length / 2)
        self.getBytes(&buffer, length: (self.length / 2 * 2))
        return buffer
    }
    
    var u32s:[UInt32] { // Array of UInt32, Swift byte array basically
        var buffer:[UInt32] = [UInt32](repeating: 0, count: self.length / 4)
        self.getBytes(&buffer, length: (self.length / 4) * 4 )
        return buffer
    }
    
    var utf8:String? {
        return String(data: self as Data, encoding: String.Encoding.utf8)
    }
}

// ------- Extension to simplify working with UIColor -----------------------------
extension UIColor {
    // Creates a UIColor from a Hex string.
    convenience init(hexString: String) {
        var cString: String = hexString.trimmingCharacters(in: CharacterSet.uppercaseLetters)
        
        if (cString.hasPrefix("#")) {
            cString = (cString as NSString).substring(from: 1)
        }
        
        if (cString.count != 6) {
            self.init(white: 0.5, alpha: 1.0)
        } else {
            let rString: String = (cString as NSString).substring(to: 2)
            let gString = ((cString as NSString).substring(from: 2) as NSString).substring(to: 2)
            let bString = ((cString as NSString).substring(from: 4) as NSString).substring(to: 2)
            
            var r: CUnsignedInt = 0, g: CUnsignedInt = 0, b: CUnsignedInt = 0;
            Scanner(string: rString).scanHexInt32(&r)
            Scanner(string: gString).scanHexInt32(&g)
            Scanner(string: bString).scanHexInt32(&b)
            
            self.init(red: CGFloat(r) / CGFloat(255.0), green: CGFloat(g) / CGFloat(255.0), blue: CGFloat(b) / CGFloat(255.0), alpha: CGFloat(1))
        }
        
        
    }
}

// ------- Extension to simplify working with NSDate -----------------------------
extension Date
{
    func hour() -> Int
    {
        //Return Hour
        return Calendar.current.component(.hour, from: self)
    }
    
    func minute() -> Int
    {
        //Return Minute
        return Calendar.current.component(.minute, from: self)
    }
}

//-------------------------------------------------------
class RecentItem {
    
    // MARK: Properties
    var text: String = ""
    var fileID: UInt32
    var maleFileID: UInt32
    var femaleFileID: UInt32
    var rate: Int = 0
    var fileURL: String = ""
    
    // MARK: Initialization
    init?(text: String, fileID: UInt32, maleFileID: UInt32, femaleFileID: UInt32, rate: Int, url: String) {
        // Initialize stored properties.
        self.text = text
        self.fileID = fileID
        self.maleFileID = maleFileID
        self.femaleFileID = femaleFileID
        self.rate = rate
        self.fileURL = url
    }
}

var recents = [RecentItem]()

//*********************************************************************************
// MARK: BLE Services, Characteristics, etc.***************************************

// Handshake ----------------------------------------------------------------------
// Handshake procedure:
// 1. App reads ToyId from Toy
// 2. App sends ClientID to Toy
// 3. Toy confirms ClientID

let HS_SERV_ADV_UUID      = CBUUID(string: "0040")
let HS_SERVICE_UUID       = CBUUID(string: "00000040-1212-EFDE-1523-785FEABCD123")
let HS_CLIENTINFO_C       = CBUUID(string: "00000041-1212-EFDE-1523-785FEABCD123")
let HS_DEVICEINFO_C       = CBUUID(string: "00000042-1212-EFDE-1523-785FEABCD123")
let HS_CONFIRMSERV_C      = CBUUID(string: "00000043-1212-EFDE-1523-785FEABCD123")

// This structure is used while discovering and connecting Toys.
struct ToyCharx {
    var hsClientCharx:      CBCharacteristic?      //Used to send ClientId to the Toy
    var hsDeviceCharx:      CBCharacteristic?      //Used to read DeviceID from the toy
    var hsConfirmCharx:     CBCharacteristic?      //Used to confirm the connection. Toy returns the ClientID if confirmed, 0 otherwise
    var toyID:              String = ""
    var deviceInfo:         DeviceInfo?
    var lastResponseTime:   CFAbsoluteTime?        //Used to check if a Toy is not responding properly
    var BLEStatus:          BLEConnectionStatus = BLEConnectionStatus.connecting
    var isCharging:         Bool = false
    var batteryLevel:       UInt8 = 0
    var isSilent:           Bool = false
}

struct DeviceInfo {
    var revision:           UInt16 = 0
    var model:              UInt16 = 0
    var ESPversion:         UInt16 = 0
    var NRFversion:         UInt16 = 0
    var packVersion:        UInt16 = 0
}

// Wi-Fi -------------------------------------------------------------------------
let WIFI_SERVICE_UUID     = CBUUID(string: "00000010-1212-EFDE-1523-785FEABCD123")
let WIFI_STATUS_C         = CBUUID(string: "00000011-1212-EFDE-1523-785FEABCD123")
let WIFI_SSID_C           = CBUUID(string: "00000012-1212-EFDE-1523-785FEABCD123")
let WIFI_PASSWORD_C       = CBUUID(string: "00000013-1212-EFDE-1523-785FEABCD123")
let WIFI_VISIBLENETS_C    = CBUUID(string: "00000014-1212-EFDE-1523-785FEABCD123")
let WIFI_KNOWNNETS_C      = CBUUID(string: "00000015-1212-EFDE-1523-785FEABCD123")
let WIFI_MAKEACTION_C     = CBUUID(string: "00000016-1212-EFDE-1523-785FEABCD123")
let WIFI_UPGRADE_C        = CBUUID(string: "00000017-1212-EFDE-1523-785FEABCD123")

// Make Wi-Fi action commands
let WIFI_GETKNOWN_NETWORKS:     UInt8 = 0
let WIFI_SCAN_NETWORKS:         UInt8 = 1
let WIFI_CONNECT_NETWORK:       UInt8 = 2
let WIFI_FORGET_NETWORK:        UInt8 = 3
let WIFI_UPDATE_TOY:            UInt8 = 4

struct WiFiCharx {
    var networkStatus:      CBCharacteristic?
    var networkSSID:        CBCharacteristic?
    var networkPassword:    CBCharacteristic?
    var visibleWiFi:        CBCharacteristic?
    var knownWiFi:          CBCharacteristic?
    var makeAction:         CBCharacteristic?
    var upgradeStatus:      CBCharacteristic?
}

struct WiFiInfo {
    var isProtected:    UInt8 = 0
    var RSSI:           Int8 = 0
    var SSID:           String?
}

// Content -----------------------------------------------------------------------
let CONTENT_SERVICE_UUID  = CBUUID(string: "00000020-1212-EFDE-1523-785FEABCD123")
let CONT_PLAYFYLE_C       = CBUUID(string: "00000021-1212-EFDE-1523-785FEABCD123")
let CONT_FILEINFO_C       = CBUUID(string: "00000022-1212-EFDE-1523-785FEABCD123")
let CONT_SENDFILE_C       = CBUUID(string: "00000023-1212-EFDE-1523-785FEABCD123")

struct ContentCharxs {
    var playFileCharx:   CBCharacteristic?
    var lastPlaiedCharx: CBCharacteristic?
    var sendFileCharx:   CBCharacteristic?
}

// Settings ----------------------------------------------------------------------
let SETUP_SERVICE_UUID      = CBUUID(string: "00000030-1212-EFDE-1523-785FEABCD123")
let SETUP_VOICE_C           = CBUUID(string: "00000031-1212-EFDE-1523-785FEABCD123")
let SETUP_SETTINGS_C        = CBUUID(string: "00000032-1212-EFDE-1523-785FEABCD123")
let SETUP_STATUS_C          = CBUUID(string: "00000033-1212-EFDE-1523-785FEABCD123")

struct SetupCharxs {
    var volumeCharx:    CBCharacteristic?
    var settingsCharx:  CBCharacteristic?
    var statusCharx:    CBCharacteristic?
}

struct ToyVoiceSettings{
    var volume:     UInt8 = 0
    var voiceType:  UInt8 = 0
}
struct ToyGeneralSettings{
    var fromTime:       UInt16 = 0
    var toTime:         UInt16 = 0
    var notifications:  UInt32 = 0
    var forbidden:      UInt16 = 0
}

// All suplimentary characteristics -----------------------------------------------
struct ToySupplimentaryCharx {
    var setup:               SetupCharxs
    var content:             ContentCharxs
    var network:             WiFiCharx
}

// BLE Status ---------------------------------------------------------------------
enum BLEStatus{
    case on
    case off
}

// App BLE Status -----------------------------------------------------------------
enum ToyStatus {
    case disconnected
    case searching
    case connected
    case upgrading
    case resetting
}

// Status representing BLE connection status --------------------------------------
enum BLEConnectionStatus {
    case paired
    case clientIdSent
    case connecting
}

// Status representing Wi-Fi connection status ------------------------------------
enum ToyWiFiStatus {
    case idle
    case fetching
    case connecting
}

// Status representing Toy Upgrade status ------------------------------------
enum ToyUpgradeStatus : UInt8 {
    case upgradeIdle = 0
    case upgradeStarted = 1
    case upgradeConnecting = 2
    case upgradeSending = 3
    case upgradeReceiving = 4
    case upgradeExtracting = 5
    case upgradeRestarting = 6
    case upgradeReset = 7
    case upgradeUnknoun = 100
    init?(raw: UInt8) {
        if raw >= 0 && raw <= 7 {
            self.init(rawValue: raw)
        } else {
            self.init(rawValue: 100)
        }
    }
}


var centralController: CentralViewController!

//----------------------------------------------------
class CentralViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate  {
    
    // MARK: Properties
    //----------------------------------------------------
    
    var toyNavViewController: MainNavigationController?
    var loginViewController: LoginViewController?
    var verificationViewController: VerificationViewController?
    var wifiSettingsTabBarController: WiFiSettingsTabBarController?
    
    var myToyViewController: MyToyViewController?
    var toySettingsViewController: ToySettingsTableViewController?
    var userSettingsViewController: UserSettingsTableViewController?
    //var recentFilesViewController: RecentViewController?
    var visibleWiFiViewController: VisibleWiFiViewTableViewController?
    var knownWiFiViewController: KnownWiFiTableViewController?
    var updateToyViewController: UpgradeToyTableViewController?
    
    private let cloudReachability: SNNetReachability = SNNetReachability(hostname: hostname)
    let cloundService : CloudService = CloudService()
    
    private var myBLECentralManager : CBCentralManager!
    private var discoveredPeripherals = [CBPeripheral]()
    private var discoveredPerifCharxs = [CBPeripheral: ToyCharx]()
    
    private var toyPeripheral: CBPeripheral?
    private var toyCharx : ToyCharx?
    private var toySuplCharx: ToySupplimentaryCharx?
 
    var getWiFiStatusTimer: Timer?
    
    var knownIsFetching: Bool = false
    var knownIsWaitingForCharx: Bool = false // If requested before Wi-Fi Characteristic becomes available
    var getKnownTimeoutTimer: Timer?
    var getKnownLastRequestedTime:    CFAbsoluteTime?
    
    var visibleIsFetching: Bool = false
    var visibleIsWaitingForCharx: Bool = false // If requested before Wi-Fi Characteristic becomes available
    var getVisibleTimeoutTimer: Timer?
    var getVisibleLastRequestedTime:    CFAbsoluteTime?
    
    var sessionSettings: SessionSettings!
    var expectedToyID : String = ""
    
    var toyCheckStatusTimer: Timer?
    var toyRescanTimer: Timer?
    
    var getLast10TimeoutTimer: Timer?
    var last10PendingUpgradeIdle: Bool = false
    var last10IsFetching: Bool = false
    var last10ReceivedButNotUpdated: Bool = false
    
    var checkStatusSkipCount: Int = 0
    var presentLoginViewController: Bool = true

    
    var upperStatusLabel: String = ""
    var lowerStatusLabel: String = ""
    
    private var toyWiFiStatus: ToyWiFiStatus = ToyWiFiStatus.idle
    private var toyUpgradeStatus : ToyUpgradeStatus = ToyUpgradeStatus.upgradeUnknoun
    
    //MARK: Application states ************************************************************************
    // BLE status ----------------------------------------------
    private var bleStatus: BLEStatus = .off {
        didSet {
            switch bleStatus {
            case .on:
                DispatchQueue.main.async{
                    if self.cloundService.isCloudSessionEnabled() == false {
                        self.sessionSettings = self.cloundService.getCloudBaseInfo()
                        self.expectedToyID = self.sessionSettings.toyProfile.toyID
                        if self.expectedToyID.isEmpty == true {
                            #if DEBUG
                                print("DBG: BLE = .On, no cloud, toyID is empthy -> stay .disconnected")
                            #endif
                            self.upperStatusLabel = "Internet connection is required to connect a new toy."
                            self.myToyViewController?.bleDidChange(isWorking: false)
                            self.myToyViewController?.ConnectAnotherButton.isHidden = true
                            return
                        }
                    }
                    if self.toyStatus == .disconnected && self.sessionSettings.clientID != 0  {
                        self.toyStatus = ToyStatus.searching
                    }
                }
                break
            case .off:
                DispatchQueue.main.async{
                    #if DEBUG
                        print("DBG: BLE = .Off: -> Go .disconnected")
                    #endif
                    self.toyStatus = ToyStatus.disconnected
                    self.upperStatusLabel = "Turn Bluetooth on \nto connect to your KiQ"
                    self.myToyViewController?.bleDidChange(isWorking: false)
                    self.myToyViewController?.ConnectAnotherButton.isHidden = true
                }
                break
            }
        }
    }
    
    // Toy BLE status of connection ----------------------------------------------
    var toyStatus: ToyStatus = .disconnected {
        didSet {
            switch toyStatus {  // SEARCHING ----------------------
            case ToyStatus.searching:
                DispatchQueue.main.async{
                    #if DEBUG
                        print("DBG: bleStatus: Go -> ToyStatus.searching")
                    #endif
                    self.myToyViewController?.navigationItem.rightBarButtonItem?.isEnabled = false
                    
                    if self.expectedToyID == "" {
                        self.upperStatusLabel = "KiQ is not yet connected"
                        self.myToyViewController?.bleDidChange(isWorking: false)
                        self.myToyViewController?.displayConnectionChoiceMessage()
                        return
                    } else {
                        if self.cloundService.isCloudSessionEnabled() == true {
                            self.myToyViewController?.ConnectAnotherButton.isHidden = false
                        }
                        self.upperStatusLabel = "Connecting to " + self.sessionSettings.toyProfile.toyName + "..."
                    }
                    self.myToyViewController?.bleDidChange(isWorking: true)
                    self.scanForPeripheral()
                }
                break
            
            case ToyStatus.connected:  //CONNECTED ---------------------------------
                DispatchQueue.main.async{
                    if self.cloundService.isCloudSessionEnabled() == true {
                        self.upperStatusLabel = self.sessionSettings.toyProfile.toyName + " is connected"
                        self.lowerStatusLabel = "Getting ready...\n"
                        self.myToyViewController?.bleDidChange(isWorking: true)
                    } else {
                        self.upperStatusLabel = self.sessionSettings.toyProfile.toyName + " is connected"
                        self.myToyViewController?.bleDidChange(isWorking: false)
                    }
                    self.myToyViewController?.ConnectAnotherButton.isHidden = true
                    
                    self.myToyViewController?.navigationItem.rightBarButtonItem?.isEnabled = true
                    if self.myBLECentralManager.isScanning{
                        self.myBLECentralManager.stopScan()
                    }
                    self.toyRescanTimer?.invalidate()
                    self.toyRescanTimer = nil
                    if self.toyCheckStatusTimer == nil {
                        self.toyCheckStatusTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(CentralViewController.checkToyBLEStatus), userInfo: nil, repeats: true)
                    }
                    if self.last10PendingUpgradeIdle == true {
                        self.last10IsFetching = true
                        self.last10PendingUpgradeIdle = false
                        self.getPlayedFile(fileNumber: 0)
                    }
                }
                break
                
            case ToyStatus.disconnected:  // IDLE ---------------------------
                DispatchQueue.main.async{
                    #if DEBUG
                        print("DBG: bleStatus:Go -> ToyStatus.disconnected")
                    #endif
                    if self.bleStatus != BLEStatus.off {
                        if self.expectedToyID == "" {
                            self.upperStatusLabel = "KiQ is not yet connected"
                        } else {
                            self.upperStatusLabel = "KiQ is disconnected"
                        }
                    }
                    self.myToyViewController?.navigationItem.rightBarButtonItem?.isEnabled = false
                    if self.cloundService.isCloudSessionEnabled() == true {
                        self.lowerStatusLabel = "\n"
                    }
                    self.myToyViewController?.bleDidChange(isWorking: false)
                    
                    _ = self.myToyViewController?.navigationController?.popToRootViewController(animated: true)
                    
                    self.last10ReceivedButNotUpdated = false
                    
                    self.last10IsFetching = false
                    self.getLast10TimeoutTimer?.invalidate()
                    self.getLast10TimeoutTimer = nil
                    
                    recents.removeAll()
                    self.toyRescanTimer?.invalidate()
                    self.toyRescanTimer = nil
                    self.toyCheckStatusTimer?.invalidate()
                    self.toyCheckStatusTimer = nil
                    
                    self.getKnownTimeoutTimer?.invalidate()
                    self.knownIsFetching = false
                    
                    self.getVisibleTimeoutTimer?.invalidate()
                    self.visibleIsFetching = false
                    
                    self.toyWiFiStatus = ToyWiFiStatus.idle
                    self.toyUpgradeStatus = ToyUpgradeStatus.upgradeUnknoun
                    
                    self.stopAndInvalidatePeripherals()
                    
                    self.visibleIsWaitingForCharx = false
                    self.knownIsWaitingForCharx = false
                    
                }
                break
                
                case ToyStatus.upgrading:
                    DispatchQueue.main.async{
                        #if DEBUG
                            print("DBG: bleStatus:Go -> ToyStatus.upgrading")
                        #endif
                    }
                    self.upperStatusLabel = "KiQ is being upgraded"
                    if self.toyCheckStatusTimer == nil {
                        self.toyCheckStatusTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(CentralViewController.checkToyBLEStatus), userInfo: nil, repeats: true)
                    }

                    self.myToyViewController?.upgradeDidChange(true, progress: 0)
                    
                    self.myToyViewController?.navigationItem.rightBarButtonItem?.isEnabled = false
                    
                    self.toyWiFiStatus = ToyWiFiStatus.idle
                    self.visibleIsWaitingForCharx = false
                    self.knownIsWaitingForCharx = false
                    
                    self.toyRescanTimer?.invalidate()
                    self.toyRescanTimer = nil
                    self.getKnownTimeoutTimer?.invalidate()
                    self.knownIsFetching = false
                    self.getVisibleTimeoutTimer?.invalidate()
                    self.visibleIsFetching = false
                    self.getLast10TimeoutTimer?.invalidate()
                    self.getLast10TimeoutTimer = nil
                    self.last10IsFetching = false
                    
                    self.updateToyViewController?.theToyIsBeingUpgraded()
                break
                
                
            case ToyStatus.resetting:
                DispatchQueue.main.async{
                    #if DEBUG
                        print("DBG: bleStatus:Go -> ToyStatus.resetting")
                    #endif
                }
                self.upperStatusLabel = sessionSettings.toyProfile.toyName + " is being reset"
                self.lowerStatusLabel = "\n"
                
                self.myToyViewController?.navigationItem.rightBarButtonItem?.isEnabled = false
                self.myToyViewController?.PlayButton.isHidden = true
                
                _ = self.myToyViewController?.navigationController?.popToRootViewController(animated: true)
                
                self.visibleIsWaitingForCharx = false
                self.knownIsWaitingForCharx = false
                
                self.toyRescanTimer?.invalidate()
                self.toyRescanTimer = nil
                self.getKnownTimeoutTimer?.invalidate()
                self.knownIsFetching = false
                self.getVisibleTimeoutTimer?.invalidate()
                self.visibleIsFetching = false
                self.getLast10TimeoutTimer?.invalidate()
                self.getLast10TimeoutTimer = nil
                self.last10IsFetching = false
                
                self.myToyViewController?.resetInProgress()
                self.forgetToy({ (success) in
                    if success != true {
                        self.toyStatus = ToyStatus.searching
                        self.myToyViewController?.displayMyAlertMessage("Sorry. We are unable to reset Toy due to some connection issue with the Cloud. Please try again later.")
                    }
                })
                break
            }
        }
    }
    
    // Internet connection status  ----------------------------------------------
    var previousInternetConnectionStatus : InternetConnectionStatus = .undefined
    
    var internetConnectionStatus: InternetConnectionStatus = .notConnected {
        didSet {
            if internetConnectionStatus != previousInternetConnectionStatus{
                previousInternetConnectionStatus = internetConnectionStatus
                switch internetConnectionStatus{
                case .notConnected:
                    DispatchQueue.main.async{
                        if self.cloundService.isLoggedIn() == true && self.toyNavViewController?.view.window == nil {
                            //The User already has the session established
                            centralController.present(centralController.toyNavViewController!, animated:true, completion: nil)
                        } else {
                            // App does not have information about previously established session
                            // Need to pass the User through the Login procedure
                            self.CloudSatusLabel.isHidden = false
                            self.CloudRequiredLabel.isHidden = false
                            self.ToyEyesImg.isHidden = false
                        }
                        
                        self.myToyViewController?.navigationItem.leftBarButtonItem?.isEnabled = false
                        self.cloundService.deinitCloudService()
                        self.lowerStatusLabel = "Some functions are unavailable\nInternet connection is required"
                        self.myToyViewController?.cloudDidChange(false)
                        self.userSettingsViewController?.tableView.reloadData()
                    }
                    break
                    
                case .wiFiConnected:
                    DispatchQueue.main.async{
                        if self.bleStatus == BLEStatus.on{
                            self.ToyEyesImg.isHidden = true
                        }
                        self.CloudSatusLabel.isHidden = true
                        self.CloudRequiredLabel.isHidden = true
                        if self.cloundService.isCloudSessionEnabled() == false {
                            if self.toyStatus != ToyStatus.upgrading {
                                self.lowerStatusLabel = "Connecting to KiQ Cloud...\n"
                            }
                            self.myToyViewController?.cloudDidChange(true)
                            self.cloundService.initCloudService()
                        }
                    }
                    break
                case .cellularConnected:
                    DispatchQueue.main.async{
                        if self.bleStatus == BLEStatus.on{
                            self.ToyEyesImg.isHidden = true
                        }
                        self.CloudSatusLabel.isHidden = true
                        self.CloudRequiredLabel.isHidden = true
                        if self.cloundService.isCloudSessionEnabled() == false {
                            if self.toyStatus != ToyStatus.upgrading {
                                self.lowerStatusLabel = "Connecting to KiQ Cloud...\n"
                            }
                            self.myToyViewController?.cloudDidChange(true)
                            self.cloundService.initCloudService()
                        }
                    }
                    break
                case .undefined:
                    break
                }
            }
        }
    }
    
    //MARK: Initialization ***************************************************************
    //----------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
            print ("DBG: Debug mode On ")
        #endif
        
        NotificationCenter.default.addObserver(self, selector: #selector(CentralViewController.applicationWillEnterForeground(_:)), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(CentralViewController.applicationWillEnterBackground(_:)), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        
        // Reachability status
        NotificationCenter.default.addObserver(self, selector: #selector(CentralViewController.statusChanged), name: NSNotification.Name(rawValue: SNReachabilityNotification), object: nil)
        cloudReachability.startNotifier()
        
        centralController = self
        
        toyNavViewController = self.storyboard?.instantiateViewController(withIdentifier: "MainNavigationController") as? MainNavigationController
        toyNavViewController!.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        
        loginViewController = self.storyboard?.instantiateViewController(withIdentifier: "LoginViewController") as? LoginViewController
        loginViewController!.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        
        CloudRequiredLabel.isHidden = true
        CloudSatusLabel.isHidden = true
        ToyEyesImg.isHidden = true
    }
    
    //----------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if myBLECentralManager == nil{
            myBLECentralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }
    
    //----------------------------------------------------
    @objc func applicationWillEnterForeground(_ application: UIApplication!) {
        cloudReachability.startNotifier()
        if toyStatus == ToyStatus.connected && toyPeripheral?.state == CBPeripheralState.connected {
            checkToyBattery()
            last10IsFetching = true
            last10ReceivedButNotUpdated = false
            getPlayedFile(fileNumber: 0)
            checkStatusSkipCount = 0
            self.toyCheckStatusTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(CentralViewController.checkToyBLEStatus), userInfo: nil, repeats: true)
            return
        }
        
        if bleStatus == .on && self.cloundService.isLoggedIn() == true && toyStatus != ToyStatus.upgrading {
            toyStatus = ToyStatus.searching
            return
        }
        
        if self.toyStatus == ToyStatus.upgrading {
            if toyPeripheral?.state == CBPeripheralState.connected {
                last10PendingUpgradeIdle = true
                last10IsFetching = false
                last10ReceivedButNotUpdated = false
                self.getUpgradeStatus()
            } else {
                toyStatus = ToyStatus.searching
            }
        }
    }
    
    //----------------------------------------------------
    @objc func applicationWillEnterBackground(_ notification: Notification) {
        
        if myBLECentralManager.isScanning{
            myBLECentralManager.stopScan()
        }
        
        self.toyCheckStatusTimer?.invalidate()
        self.toyCheckStatusTimer = nil
 
        self.getLast10TimeoutTimer?.invalidate()
        self.getLast10TimeoutTimer = nil
        self.last10IsFetching = false
 
        self.toyRescanTimer?.invalidate()
        self.toyRescanTimer = nil
        self.getWiFiStatusTimer?.invalidate()
        self.getWiFiStatusTimer = nil
        
        self.getKnownTimeoutTimer?.invalidate()
        self.knownIsFetching = false
        
        self.getVisibleTimeoutTimer?.invalidate()
        self.visibleIsFetching = false
        
        myToyViewController?.resetMainScreen()
        _ = myToyViewController?.navigationController?.popToRootViewController(animated: true)
        cloudReachability.stopNotifier()
        cloundService.deinitCloudService()
        
        self.last10ReceivedButNotUpdated = false
        recents.removeAll()
        knownNetworks.removeAll()
        visibleNetworks.removeAll()
        
        previousInternetConnectionStatus = InternetConnectionStatus.undefined
    }
    
    //----------------------------------------------------
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        #if DEBUG
            print("DBG: didReceiveMemoryWarning")
        #endif
        NotificationCenter.default.removeObserver(self,name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.removeObserver(self,name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        toyStatus = ToyStatus.disconnected
        cloudReachability.stopNotifier()
        cloundService.deinitCloudService()
    }
    
    //----------------------------------------------------
    deinit {
        NotificationCenter.default.removeObserver(self,name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        NotificationCenter.default.removeObserver(self,name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        toyStatus = ToyStatus.disconnected
        cloudReachability.stopNotifier()
        cloundService.deinitCloudService()
    }
    
    // MARK: Outlets
    //----------------------------------------------------
    @IBOutlet var CloudSatusLabel: UILabel!
    @IBOutlet var CloudRequiredLabel: UILabel!
    @IBOutlet var ToyEyesImg: UIImageView!
    
    // MARK: Outlet actions
    
    // MARK: CentralViewController Functions
    //----------------------------------------------------
    func processUserResponseForConnectionChoise(shouldConnect: Bool){
        if shouldConnect == true {
            self.myToyViewController?.ConnectAnotherButton.isHidden = true
            self.upperStatusLabel = "Searching for KiQ..."
            self.myToyViewController?.bleDidChange(isWorking: true)
            self.scanForPeripheral()
        } else {
            toyStatus = ToyStatus.disconnected
            self.myToyViewController?.bleDidChange(isWorking: false)
            myToyViewController?.ConnectAnotherButton.isEnabled = true
            myToyViewController?.ConnectAnotherButton.isHidden = false
            
        }
    }
    
    // This function shall only be used after Cloud session is established !!!
    func startBLEConnection (_ settings: SessionSettings){
        self.sessionSettings = settings
        self.lowerStatusLabel = "\n"
        self.myToyViewController?.cloudDidChange(false)
        self.userSettingsViewController?.tableView.reloadData()
        self.myToyViewController?.navigationItem.leftBarButtonItem?.isEnabled = true
        if self.bleStatus == BLEStatus.on {
            switch self.toyStatus {
                
            case ToyStatus.disconnected:
                if self.bleStatus == BLEStatus.on {
                    self.expectedToyID = self.sessionSettings.toyProfile.toyID
                    self.toyStatus = ToyStatus.searching
                }
                break
                
            case ToyStatus.searching:
                if self.expectedToyID == "" {
                    //self.myToyViewController?.ConnectAnotherButton.isHidden = true
                    //self.upperStatusLabel = "KiQ is not yet connected"
                    //self.myToyViewController?.bleDidChange(false)
                    //self.myToyViewController?.displayConnectionChoiceMessage()
                    return
                } else {
                    self.myToyViewController?.ConnectAnotherButton.isHidden = false
                    self.upperStatusLabel = "Connecting to " + self.sessionSettings.toyProfile.toyName + "..."
                }
                self.myToyViewController?.bleDidChange(isWorking: true)
                break
                
            case ToyStatus.connected:
                if self.last10ReceivedButNotUpdated == true { // Last 10 already received. Updating their text in the Cloud
                    self.upperStatusLabel = self.sessionSettings.toyProfile.toyName + " is connected"
                    self.lowerStatusLabel = "Getting ready...\n"
                    self.myToyViewController?.bleDidChange(isWorking: true)
                    if recents.isEmpty != true {
                        self.cloundService.updateJokes(jokes: recents){ (success, response) -> Void in
                             DispatchQueue.main.async{
                                self.last10ReceivedButNotUpdated = false
                                if success != true {
                                    #if DEBUG
                                        self.logMessageToCloud("ERROR: startBLEConnection: get text for last 10 failed with response: " + String(describing: response))
                                    #endif
                                    
                                    if self.last10IsFetching == false {
                                        self.last10IsFetching = true
                                        self.getPlayedFile(fileNumber: 0)
                                    }
                                } else {
                                    #if DEBUG
                                        self.logMessageToCloud ("DBG: startBLEConnection: 10 Last played updated by text")
                                    #endif

                                    recents = response!
                                    self.lowerStatusLabel = "\n"
                                    self.myToyViewController?.lastPlayedDidChange()
                                }
                            }
                        }
                    }
                } else {
                    if self.last10IsFetching == false && recents.isEmpty != true { // Last 10 already received and and updated
                        self.myToyViewController?.lastPlayedDidChange()
                    } else { // Last 10 have not been yet received
                        self.upperStatusLabel = self.sessionSettings.toyProfile.toyName + " is connected"
                        self.lowerStatusLabel = "Getting ready...\n"
                        self.myToyViewController?.bleDidChange(isWorking: true)
                    }
                }
                break
                
            case ToyStatus.upgrading:
                
                #if DEBUG
                    self.logMessageToCloud ("DBG: startBLEConnection: already .upgrading")
                #endif
                    self.myToyViewController?.ConnectAnotherButton.isHidden = true
                    //self.upperStatusLabel = "The Toy is being upgraded"
                    //self.lowerStatusLabel = " "
                    //self.myToyViewController?.upgradeDidChange(true, progress: 0)
                break
                
            case ToyStatus.resetting:
                #if DEBUG
                    self.logMessageToCloud ("DBG: startBLEConnection: already .resetting")
                #endif
                self.myToyViewController?.ConnectAnotherButton.isHidden = true
                self.upperStatusLabel = sessionSettings.toyProfile.toyName + " is being reset"
                self.lowerStatusLabel = "\n"
                self.myToyViewController?.bleDidChange(isWorking: true)
                break
                
            }
        } else { // BLE is Off ---------------------------------------------------------------
            self.upperStatusLabel = "Turn Bluetooth on \nto connect to your KiQ"
            self.myToyViewController?.bleDidChange(isWorking: false)
            myToyViewController?.ConnectAnotherButton.isHidden = true
            
        }
        // Present mayn view if not yet presented
        if self.toyNavViewController?.view.window == nil {
            #if DEBUG
                print("DBG: startBLEConnection: -> present toyNavViewController")
            #endif
            self.present(self.toyNavViewController!, animated:true, completion: nil)
        }
    }

    
    //-----------------------------------------------------------
    // Reset application from the application
    func logout(completion: @escaping (_ success: Bool) -> Void) {
        #if DEBUG
            print("DBG: logout from KiQ Cloud")
        #endif

        centralController.cloundService.logout(self.sessionSettings.clientID) { (success) -> Void in
            if success == true {
                if self.cloundService.isCloudSessionEnabled() == true{
                    if self.sessionSettings.sessionType == "facebook"{
                        let loginManager: FBSDKLoginManager = FBSDKLoginManager()
                        loginManager.logOut()
                    }
                }
                self.toyNavViewController?.dismiss(animated: true) {
                    self.myToyViewController?.tabBarController?.selectedIndex = 0
                    
                    self.sessionSettings.clientID = 0
                    self.sessionSettings.toyProfile.toyID = ""
                    self.cloundService.saveCloudBaseInfo(self.sessionSettings)
                    
                    self.toyStatus = ToyStatus.disconnected
                    self.previousInternetConnectionStatus = InternetConnectionStatus.undefined
                    self.cloudReachability.stopNotifier()
                    self.presentLoginViewController = true
                    self.cloundService.deinitCloudService()
                    self.userSettingsViewController?.tableView.reloadData()
                    self.cloudReachability.startNotifier()
                }
            } else {
                #if DEBUG
                    self.logMessageToCloud("ERROR: failed to logout from KiQ Cloud")
                #endif
            }
            completion(success)
        }
    }

    //MARK: Cloud Reachability Functions
    //-----------------------------------------
    //Phone connection changed
    @objc func statusChanged() {
        internetConnectionStatus = cloudReachability.currentConnectionStatus
    }
    
    //MARK: BLE Functions 
    //----------------------------------------------------
    // Check status of BLE hardware
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            if central.state == CBManagerState.poweredOn {
                bleStatus = .on
            } else {
                bleStatus = .off
            }
        } else {
            if CBCentralManagerState(rawValue: central.state.rawValue) == CBCentralManagerState.poweredOn {
                bleStatus = .on
            } else {
                bleStatus = .off
            }
        }
    }
    
    //---------------- Central Manager Delegates ---------------
    func stopAndInvalidatePeripherals(){
        if myBLECentralManager.isScanning{
            myBLECentralManager.stopScan()
        }
        
        objc_sync_enter(self) //<--- Enter Critical section
        defer { objc_sync_exit(self) }
        
        for peripheral in discoveredPeripherals {
                myBLECentralManager.cancelPeripheralConnection(peripheral)
        }
        discoveredPeripherals.removeAll()
        discoveredPerifCharxs.removeAll()
        
        if toyPeripheral != nil {
            myBLECentralManager.cancelPeripheralConnection(toyPeripheral!)
            toyPeripheral = nil
            toyCharx = nil
            toySuplCharx = nil
        }
        
    } //<---- Leave Critical section
    
    
    //---------------- Central Manager Delegates ---------------
    //----------------------------------------------------------
    // Peripheral discovered
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        objc_sync_enter(self) //<--- Enter Critical section
        defer { objc_sync_exit(self) }
        
        #if DEBUG
            print("DBG: New peripheral discovered: ", peripheral.name ?? "Wrong name", ", starting connection")
        #endif
            
        if discoveredPeripherals.contains(peripheral) == false{
            peripheral.delegate = self
            discoveredPeripherals.append(peripheral)
            discoveredPerifCharxs[peripheral] = ToyCharx()
            discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent()
            self.myBLECentralManager.connect(peripheral, options: nil)
            #if DEBUG
                print("DBG: Starting connection to", peripheral.name ?? "Wrong name")
            #endif
        }
    } //<---- Leave Critical section
    
    //----------------------------------------------------------
    // Fail to connect to peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        objc_sync_enter(self) //<--- Enter Critical section
        defer { objc_sync_exit(self) }

        #if DEBUG
            logMessageToCloud ("ERROR: Did fail to connect to periheral" + String(describing: peripheral.name))
        #endif
        discoveredPerifCharxs.removeValue(forKey: peripheral)
    }//<--- Leave Critical section
    
    //----------------------------------------------------------
    // Peripheral connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([HS_SERVICE_UUID])
        discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent()
    }
    
    //----------------------------------------------------------
    // Peripheral disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral) {

        objc_sync_enter(self) //<--- Enter Critical section
        defer { objc_sync_exit(self) }
        
        #if DEBUG
            logMessageToCloud("DBG: Peripheral disconnected: " + String (describing: peripheral.name))
        #endif
        
        myBLECentralManager.cancelPeripheralConnection(peripheral)
        discoveredPerifCharxs.removeValue(forKey: peripheral)
        discoveredPeripherals.remove(at: discoveredPeripherals.index(of: peripheral)!)
    }//<--- Leave Critical section
    
    //---------- Perepheral Delegates --------------------------
    //----------------------------------------------------------
    // Discover services for the Perepheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard  error == nil else {
        #if DEBUG
            logMessageToCloud("ERROR: didDiscoverServices ->" + String(error.debugDescription))
        #endif
            return
        }
        
        switch toyStatus{
        case ToyStatus.searching:
            for service in peripheral.services! {
                let thisService = service as CBService
                if thisService.uuid == HS_SERVICE_UUID{
                    peripheral.discoverCharacteristics([HS_CLIENTINFO_C, HS_CONFIRMSERV_C, HS_DEVICEINFO_C], for: thisService)
                    discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent()
                }
            }
            break
            
        case ToyStatus.connected:
            // ---------- Request supplimentary characteristics ----------------------
            for service in peripheral.services! {
                let thisService = service as CBService
                
                switch service.uuid {
                    
                case SETUP_SERVICE_UUID:
                    peripheral.discoverCharacteristics([SETUP_VOICE_C, SETUP_SETTINGS_C, SETUP_STATUS_C], for: thisService)
                    break
                    
                case CONTENT_SERVICE_UUID:
                    peripheral.discoverCharacteristics([CONT_PLAYFYLE_C, CONT_FILEINFO_C, CONT_SENDFILE_C], for: thisService)
                    break
                    
                case WIFI_SERVICE_UUID:
                    peripheral.discoverCharacteristics([WIFI_STATUS_C, WIFI_SSID_C, WIFI_PASSWORD_C, WIFI_VISIBLENETS_C, WIFI_KNOWNNETS_C, WIFI_MAKEACTION_C, WIFI_UPGRADE_C], for: thisService)
                break
                    
                default:
                    break
                }
            }
            break
            
        case ToyStatus.disconnected:
            #if DEBUG
                logMessageToCloud("ERROR: didDiscoverServices: entering, while .disconnected")
            #endif
            break
            
        case ToyStatus.upgrading:
            #if DEBUG
                logMessageToCloud("ERROR: didDiscoverServices: entering, while .upgrading")
            #endif
            break
        case ToyStatus.resetting:
            #if DEBUG
                logMessageToCloud("ERROR: didDiscoverServices: entering, while .resetting")
            #endif
            break
        }
    }
    
    
    
    //----------------------------------------------------------
    // Discover characteristic for the service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard  error == nil else  {
        #if DEBUG
            logMessageToCloud("ERROR: didDiscoverCharacteristicsForService ->" + String(error.debugDescription))
        #endif
            return
        }

        let charactericsArr = service.characteristics!  as [CBCharacteristic]
        
        objc_sync_enter(self) //<------   Enter Critical Section
        defer { objc_sync_exit(self) }
        
        // ------ Searching for the Toy ---------------------------------------------------
        // ------ Handshake service discovered HS_SERVICE_UUID ----------------------------
        if toyStatus == ToyStatus.searching && service.uuid == HS_SERVICE_UUID{
            for charactericsx in charactericsArr
            {
                if charactericsx.uuid == HS_CLIENTINFO_C{
                    discoveredPerifCharxs[peripheral]?.hsClientCharx = charactericsx
                }
                if charactericsx.uuid == HS_CONFIRMSERV_C{
                    discoveredPerifCharxs[peripheral]?.hsConfirmCharx = charactericsx
                }
                if charactericsx.uuid == HS_DEVICEINFO_C{
                    if  toyPeripheral != peripheral && discoveredPerifCharxs.isEmpty == false {
                        discoveredPerifCharxs[peripheral]?.hsDeviceCharx = charactericsx
                        peripheral.readValue(for: (discoveredPerifCharxs[peripheral]?.hsDeviceCharx)!)
                    } else if toyPeripheral == peripheral {
                        #if DEBUG
                            logMessageToCloud("ERROR: didDiscoverCharacteristicsForService toyPeripheral == peripheral")
                        #endif
                        toyStatus = ToyStatus.disconnected
                        toyStatus = ToyStatus.searching
                    } else if discoveredPerifCharxs.isEmpty == true {
                        #if DEBUG
                            logMessageToCloud("ERROR: didDiscoverCharacteristicsForService discoveredPerifCharxs.isEmpty == true")
                        #endif
                    }
                }
            }
            discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent()
            return
        }
        
        // ------ Toy is connected ---------------------------------------------------------
        if toyStatus == .connected{
            
            switch service.uuid {
                
            // ------ Settings service discovered SETUP_SERVICE_UUID ----------------------------
            case SETUP_SERVICE_UUID:
                for charactericsx in charactericsArr
                {
                    switch charactericsx.uuid {
                    
                    case SETUP_VOICE_C:
                        toySuplCharx?.setup.volumeCharx = charactericsx
                        if expectedToyID == "" {
                            var settings = ToyVoiceSettings()
                            settings.volume = sessionSettings.volume
                            settings.voiceType = sessionSettings.voiceType
                            let dataToWrite = encode(settings)
                            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.setup.volumeCharx)!, type: CBCharacteristicWriteType.withResponse)
                        }
                        break
                        
                    case SETUP_SETTINGS_C:
                        toySuplCharx?.setup.settingsCharx = charactericsx
                        if expectedToyID == "" {
                            var silentPeriodBLE = ToyGeneralSettings()
                            if sessionSettings.silentSettings.isDndOn == true {
                                silentPeriodBLE.fromTime = UInt16(((sessionSettings.silentSettings.start?.hour())! * 60) + (sessionSettings.silentSettings.start?.minute())!)
                                silentPeriodBLE.toTime = UInt16(((sessionSettings.silentSettings.end?.hour())! * 60) + (sessionSettings.silentSettings.end?.minute())!)
                            }

                            var notificationsBLE: Int = 0
                            for i in 0 ... 2{
                                for notification in sessionSettings.toyProfile.notifSettings[i]{
                                    if notification.on == true {
                                        notificationsBLE |=  ( 1 << notification.bit)
                                    }
                                }
                            }
                            
                            silentPeriodBLE.forbidden = UInt16(0)
                            silentPeriodBLE.notifications = UInt32(notificationsBLE)
                            let dataToWrite = encode(silentPeriodBLE)
                            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.setup.settingsCharx)!, type: CBCharacteristicWriteType.withResponse)
                        }
                        break
                        
                    case SETUP_STATUS_C:
                        toySuplCharx?.setup.statusCharx = charactericsx
                        toyPeripheral?.readValue(for: (toySuplCharx?.setup.statusCharx)!)
                        toyPeripheral?.setNotifyValue(true, for: (toySuplCharx?.setup.statusCharx)!)
                        break

                    default:
                        break
                    }
                }
                
            // ------ Content service discovered CONTENT_SERVICE_UUID ----------------------------
            case CONTENT_SERVICE_UUID:
                for charactericsx in charactericsArr
                {
                    switch charactericsx.uuid {
                    case CONT_PLAYFYLE_C:
                        toySuplCharx?.content.playFileCharx = charactericsx
                        break
                    case CONT_FILEINFO_C:
                        toySuplCharx?.content.lastPlaiedCharx = charactericsx
                        toyPeripheral?.setNotifyValue(true, for: (toySuplCharx?.content.lastPlaiedCharx)!)
                        break
                    case CONT_SENDFILE_C:
                        toySuplCharx?.content.sendFileCharx = charactericsx
                        if toyUpgradeStatus == ToyUpgradeStatus.upgradeIdle {
                            getPlayedFile(fileNumber: 0)
                            self.last10IsFetching = true
                        } else {
                            last10PendingUpgradeIdle = true
                        }
                        break
                    default:
                        break
                    }
                }
                break
                
            case WIFI_SERVICE_UUID:
                for charactericsx in charactericsArr
                {
                    switch charactericsx.uuid {
                
                    case WIFI_STATUS_C:
                        toySuplCharx?.network.networkStatus = charactericsx
                        toyPeripheral?.setNotifyValue(true, for: (toySuplCharx?.network.networkStatus)!)
                        break
                    case WIFI_SSID_C:
                        toySuplCharx?.network.networkSSID = charactericsx
                        break
                    case WIFI_PASSWORD_C:
                        toySuplCharx?.network.networkPassword = charactericsx
                        break
                    case WIFI_VISIBLENETS_C:
                        toySuplCharx?.network.visibleWiFi = charactericsx
                        toyPeripheral?.setNotifyValue(true, for: (toySuplCharx?.network.visibleWiFi)!)
                        break
                    case WIFI_KNOWNNETS_C:
                        toySuplCharx?.network.knownWiFi = charactericsx
                        toyPeripheral?.setNotifyValue(true, for: (toySuplCharx?.network.knownWiFi)!)
                        break
                    case WIFI_MAKEACTION_C:
                        toySuplCharx?.network.makeAction = charactericsx
                        if visibleIsWaitingForCharx == true { // Request for visible Wi-Fi networks has been made
                            _ = getVisibleWiFiNetworks(0)
                            visibleIsWaitingForCharx = false
                        }
                        if knownIsWaitingForCharx == true { // Request for known Wi-Fi networks has been made
                            knownNetworks.removeAll()
                            _ = getKnownWiFiNetworks(0)
                            knownIsWaitingForCharx = false
                        }
                        break
                    case WIFI_UPGRADE_C:
                        toySuplCharx?.network.upgradeStatus = charactericsx
                        toyPeripheral?.readValue(for: (toySuplCharx?.network.upgradeStatus)!)
                        toyPeripheral?.setNotifyValue(true, for: (toySuplCharx?.network.upgradeStatus)!)
                        break
                        
                    default:
                        break
                    }
                }
                break

            default:
                break
            }
        }
    } //<---- Leave Critical Section
    
    //----------------------------------------------------------
    // Characteristic was updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard  error == nil else {
        #if DEBUG
            logMessageToCloud("ERROR: didUpdateValueForCharacteristic: ->" + String(error.debugDescription))
        #endif
            return
        }
        
        objc_sync_enter(self) //<-------   Enter Critical section
        defer {objc_sync_exit(self)}
        
        // *********** Check if we are still searching for the Toy ******************
        if toyStatus == ToyStatus.searching {
             // We are still searching
            if characteristic.uuid == HS_DEVICEINFO_C { // The some Toy has sent to us its ToyID
                guard let data = characteristic.value as NSData?
                    else {return}
                let buffer16 = data.u16s
                let buffer32 = data.u32s
                
                let toyID64 = UInt64(buffer32[1])<<32 + UInt64(buffer32[2])
                discoveredPerifCharxs[peripheral]?.toyID = String(toyID64)
                
                if  discoveredPerifCharxs[peripheral]?.toyID == expectedToyID || expectedToyID == ""{
                    discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent()
                    discoveredPerifCharxs[peripheral]?.deviceInfo = DeviceInfo()
                    discoveredPerifCharxs[peripheral]?.deviceInfo?.revision = buffer16[0]
                    discoveredPerifCharxs[peripheral]?.deviceInfo?.model = buffer16[1]
                    discoveredPerifCharxs[peripheral]?.deviceInfo?.ESPversion = buffer16[6]
                    discoveredPerifCharxs[peripheral]?.deviceInfo?.NRFversion = buffer16[7]
                    discoveredPerifCharxs[peripheral]?.deviceInfo?.packVersion = buffer16[8]
                    
                    if discoveredPerifCharxs[peripheral]?.BLEStatus != BLEConnectionStatus.paired {
                        logMessageToCloud ("NORMAL: Sending Client ID: " + String(sessionSettings.clientID) + " to Toy " + String(describing: discoveredPerifCharxs[peripheral]?.toyID))
                        let dataToWrite = encode(sessionSettings.clientID)
                        peripheral.setNotifyValue(true, for: (discoveredPerifCharxs[peripheral]?.hsConfirmCharx)!)
                        peripheral.writeValue(dataToWrite, for: (discoveredPerifCharxs[peripheral]?.hsClientCharx)!, type: CBCharacteristicWriteType.withResponse)
                        discoveredPerifCharxs[peripheral]?.BLEStatus = BLEConnectionStatus.clientIdSent
                    } else {
                        theToyIsFound(peripheral)
                    }
                } else {
                    logMessageToCloud("NORMAL: Toy with ID: " + String (describing: discoveredPerifCharxs[peripheral]?.toyID) + " is not the Toy we are looking for")
                }
            } else if characteristic.uuid == HS_CONFIRMSERV_C { // A new Toy has sent us confirmation notification
                
                let readData :UInt32 = decode(characteristic.value!)
                if readData == sessionSettings.clientID && sessionSettings.clientID != 0 { // The Toy has confirmed connection. Stop scanning, store peripheral as Toy peripheral, request services
                    logMessageToCloud("NORMAL: Client ID: " + String(readData) + " was confirmed by Toy " + String(describing: discoveredPerifCharxs[peripheral]?.toyID))
                    theToyIsFound(peripheral)
                } else {
                    logMessageToCloud("NORMAL: the Toy has rejected connection with Client ID: " + String (describing: sessionSettings.clientID))
                    myBLECentralManager.cancelPeripheralConnection(peripheral)
                    discoveredPerifCharxs.removeValue(forKey: peripheral)
                    discoveredPeripherals.remove(at: discoveredPeripherals.index(of: peripheral)!)
                }
            }
        
        // *********** Check if we are connected to the Toy ******************
        } else if toyStatus == ToyStatus.connected {
            
            switch characteristic.uuid { // ---- Toy is connected. Some Characteristic was updated
                
            // -------- Upgrade status is read ---------------------------------------
            case WIFI_UPGRADE_C:
                guard let data = characteristic.value as NSData?
                    else {return}
                let array = data.u8s
                toyUpgradeStatus = ToyUpgradeStatus.init(raw: array[0])!
                let previousState: UInt8 = array[1]
                let stateInfo : UInt8 = array[2]
                let progress : UInt8 = array[3]
                if toyUpgradeStatus != ToyUpgradeStatus.upgradeIdle {
                    if self.toyStatus != ToyStatus.upgrading && toyUpgradeStatus != ToyUpgradeStatus.upgradeReset {
                        self.toyStatus = ToyStatus.upgrading
                        #if DEBUG
                            logMessageToCloud("DBG: .connected-> upgrade received: " + String(describing: toyUpgradeStatus))
                        #endif
                         self.upgradeDidChange(previousState: previousState, stateInfo: stateInfo, progress: progress)
                    }
                    if self.toyStatus != ToyStatus.upgrading && toyUpgradeStatus == ToyUpgradeStatus.upgradeReset {
                        self.toyStatus = ToyStatus.resetting
                        
                        self.sessionSettings.toyProfile.toyID = ""
                        self.sessionSettings.toyProfile.toyName = ""
                        self.expectedToyID = ""
                        self.upperStatusLabel = "KiQ is being reset... \n"
                        self.lowerStatusLabel = "\n"
                        myToyViewController?.upgradeDidChange(true, progress: 0)
                        self.toyStatus = ToyStatus.disconnected
                        #if DEBUG
                            logMessageToCloud("DBG: .connected-> reset received: " + String(describing: toyUpgradeStatus))
                        #endif
                    }
                } else {
                    if last10PendingUpgradeIdle == true && last10IsFetching == false && last10ReceivedButNotUpdated == false {
                        last10PendingUpgradeIdle = false
                        #if DEBUG
                            logMessageToCloud("DBG: .upgradeIdle - > requesting Last 10 Played")
                        #endif
                        last10IsFetching = true
                        getPlayedFile(fileNumber: 0)
                    }
                }
                break
            
            case SETUP_STATUS_C:
                guard let data = characteristic.value as NSData?
                    else {return}
                let array = data.u8s

                if array.count >= 3 {
                    toyCharx?.batteryLevel = array[0]
                    let toyBatteryStatus: UInt8 = array[1]
                    var toySilentStatus: UInt8 = 0
                    if array.count > 3 {
                        toySilentStatus = array[3]
                    } else {
                        toySilentStatus = array[2]
                    }
                    if (toyCharx?.batteryLevel)! > 100 {
                        toyCharx?.batteryLevel = 100
                    }
                    if toyBatteryStatus > 0 {
                        toyCharx?.isCharging = true
                    } else {
                        toyCharx?.isCharging = false
                    }
                    if toySilentStatus == 1 {
                        toyCharx?.isSilent = true
                    } else {
                        toyCharx?.isSilent = false
                    }
                    myToyViewController?.toyStatusDidChange(batteryLevel: (toyCharx?.batteryLevel)!, isCharging: (toyCharx?.isCharging)!, isSilent: (toyCharx?.isSilent)!)
                }
                break
                
            case CONT_FILEINFO_C: // Played files read/notify
                guard let data = characteristic.value as NSData?
                    else {return}
                
                let buffer8 = data.u8s
                let buffer16 = data.u16s
                let fileNumber: UInt8 = buffer8[0]
                let fileStatus: UInt8 = buffer8[1]>>6
                let fileID: UInt32 = UInt32(buffer16[1]) + UInt32(buffer16[2])<<16
                let fileTime: UInt32 = UInt32(buffer16[3]) + UInt32(buffer16[4])<<16
                
                if fileID != 0 && fileNumber <= 9 {
                    guard let recent = RecentItem(text: "", fileID: fileID, maleFileID: 0, femaleFileID: 0, rate: Int(fileStatus), url: "https://kiqtoy.com")
                        else {return}
                    
                    if self.last10IsFetching == true  {      // Last 10 played files are being fetched
                        if fileNumber == 0 {
                            recents.removeAll()
                        }
                        recents.insert(recent, at: 0)
                        let next: UInt8 = fileNumber + 1
                        if next < 10 {
                            getPlayedFile(fileNumber: next)
                        }
                    } else {                                //Last played file received
                        getLast10TimeoutTimer?.invalidate()
                        getLast10TimeoutTimer = nil
                        if recents[0].fileID != recent.fileID {
                            recents.insert(recent, at: 0)
                            if recents.endIndex > 9 {
                                recents.removeLast()
                            }
                        } else {
                            recents[0].rate = Int(fileStatus)
                        }

                        if cloundService.isCloudSessionEnabled() == true {  // Cloud is available
                            cloundService.updateJokes(jokes: recents) { (success, response) -> Void in  // Updating last file played by text
                                DispatchQueue.main.async{
                                    if success != true {
                                        self.logMessageToCloud ("ERROR: get text for last file played failed, fileID = " +
                                            String(describing: recents[0].fileID))
                                        if self.last10IsFetching == false && self.last10ReceivedButNotUpdated == false { // requesting last 10 played if they have not been already requested
                                            self.getPlayedFile(fileNumber: 0)
                                        }
                                    } else {
                                        if response?.isEmpty == false && response?[0].text.isEmpty == false{
                                            self.myToyViewController?.lastPlayedDidChange()
                                            self.cloundService.saveCloudBaseInfo(self.sessionSettings)
                                        } else {
                                            self.logMessageToCloud ("ERROR: get text for last file played -> response is empthy")
                                        }
                                    }
                                }
                            }
                        }
                        return
                    }
                }
                
                if fileID == 0 || fileNumber == 9 { // All recent files received
                    if recents.isEmpty != true && recents[0].fileID != 0 {
                        last10IsFetching = false
                        getLast10TimeoutTimer?.invalidate()
                        getLast10TimeoutTimer = nil
                        self.myToyViewController?.PlayButton.isHidden = false // now we can play last file played, it is in recents[0]
                        
                        if cloundService.isCloudSessionEnabled() == true && recents.isEmpty != true {
                            cloundService.updateJokes(jokes: recents){ (success, response) -> Void in
                                DispatchQueue.main.async{
                                    self.last10ReceivedButNotUpdated = false
                                    
                                    if success != true {
                                        self.logMessageToCloud("ERROR: get text for last 10 files failed with response: " + String(describing: response))
                                        if self.last10IsFetching == false {
                                            self.getPlayedFile(fileNumber: 0)
                                        }
                                    } else {

                                        recents = response!
                                        self.lowerStatusLabel = "\n"
                                        if recents.isEmpty == false && recents[0].text.isEmpty == false {
                                            #if DEBUG
                                                self.logMessageToCloud("DBG: 10 Last played updated by text")
                                            #endif
                                            self.myToyViewController?.lastPlayedDidChange()
                                        } else {
                                            self.logMessageToCloud("ERROR: get text for last 10 played -> response is empthy")
                                        }
                                    }
                                    self.upperStatusLabel = self.sessionSettings.toyProfile.toyName + " is connected"
                                }
                            }
                        } else {
                            self.last10ReceivedButNotUpdated = true
                        }
                    } else {
                        logMessageToCloud ("ERROR: last 10 played list is empty")
                    }
                }

                break
                
            case WIFI_STATUS_C: // Current connected network status. SSID is empty if not connected
                if toyWiFiStatus == ToyWiFiStatus.connecting {
                    getWiFiStatusTimer?.invalidate()
                    getWiFiStatusTimer = nil
                }
                var array = [UInt8]()
                
                guard let data = characteristic.value as NSData?
                    else {return}
                let buffer = data.u8s
                
                var length: Int = 0
                for i in 2...18{
                    if buffer[i] == 0 {
                        break
                    }
                    array.append(buffer[i])
                    length = length + 1
                }
                let SSID = NSString(bytes: array, length: length, encoding: String.Encoding.utf8.rawValue) as String!
                let response  = data.i8s  //response[0] - status code, response[1] - RSSI if connected
                
                if (response[0] > 1 || SSID == nil || SSID?.isEmpty == true){ // Wi-Fi has been disconnected due to some reson resported in response[0]
                    
                    #if DEBUG
                        logMessageToCloud ("DBG: Wi-Fi status received for SSID = " + String (describing: SSID!))
                    #endif
                    
                    // We are connecting a new Wi-Fi network to the toy and corresponding view is being presented
                    if toyWiFiStatus == ToyWiFiStatus.connecting {
                        objc_sync_enter(visibleNetworks) // Lock Visible
                        defer { objc_sync_exit(visibleNetworks) }
                        
                        for i in 0 ..< visibleNetworks.count {
                            if visibleNetworks[i].status == WiFiNetworkStatus.connecting {
                                if visibleNetworks[i].RSSI == 1 {
                                    visibleNetworks.remove(at: i)
                                    visibleNetworks.append(WiFiItems(SSID: "Other...", RSSI: 1, isProtected: false, status: WiFiNetworkStatus.unknown)!)
                                } else {
                                    visibleNetworks[i].status = WiFiNetworkStatus.unknown
                                }
                            }
                        }
                        
                        if visibleWiFiViewController?.isModal() == true {
                            visibleWiFiViewController?.networkUpdated(true, response: UInt8(response[0]))
                        }
                    
                        if  knownWiFiViewController?.isModal() == true {
                            knownWiFiViewController?.networkUpdated(true, response: UInt8(response[0]))
                        }
                        toyWiFiStatus = ToyWiFiStatus.idle
                    }
                } else if response[0] <= 1 { // We are connected to a Wi-Fi network
                    
                    // WiFi work is in progress ----------------------------------------------
                    if toyWiFiStatus == ToyWiFiStatus.connecting && response [0] == 0 { // The toy has connected to a wi-Fi network
                        
                        var isKnown = false
                        objc_sync_enter(visibleNetworks) // Lock Visible
                        defer { objc_sync_exit(visibleNetworks) }
                        
                        objc_sync_enter(knownNetworks) // Lock Known
                        defer { objc_sync_exit(knownNetworks) }
                        
                        for i in 0 ..< visibleNetworks.count {
                            if visibleNetworks[i].SSID == SSID {
                                visibleNetworks[i].status = WiFiNetworkStatus.known
                                if visibleNetworks[i].RSSI == 1 {
                                     visibleNetworks.append(WiFiItems(SSID: "Other...", RSSI: 1, isProtected: false, status: WiFiNetworkStatus.unknown)!)
                                }
                                
                                visibleNetworks[i].RSSI = response[1]
                                for j in 0 ..< knownNetworks.count {
                                    if knownNetworks[j].SSID == SSID && knownNetworks[j].isProtected == visibleNetworks[i].isProtected {
                                        knownNetworks[j].RSSI = visibleNetworks[i].RSSI
                                        knownNetworks[j].status = WiFiNetworkStatus.visible
                                        isKnown = true
                                    }
                                }
                                if isKnown == false {
                                    knownNetworks.insert(WiFiItems(SSID: SSID!, RSSI: visibleNetworks[i].RSSI, isProtected: visibleNetworks[i].isProtected, status: WiFiNetworkStatus.visible)!, at: 0)
                                }
                            }
                        }
                        if visibleWiFiViewController?.isModal() == true {
                            visibleWiFiViewController?.networkUpdated(true, response: UInt8(response[0]))
                        }
                        if knownWiFiViewController?.isModal() == true {
                            knownWiFiViewController?.networkUpdated(true, response: UInt8(response[0]))
                        }
                        toyWiFiStatus = ToyWiFiStatus.idle
                    }
                }
                break
              
            case WIFI_KNOWNNETS_C: // List of known networks ---------------------------------------
                var array = [UInt8]()
                guard let data = characteristic.value as NSData?
                    else {return}
                let buffer = data.u8s
                var length: Int = 0
                for i in 2...19{
                    if buffer[i] == 0 {
                        break
                    }
                    array.append(buffer[i])
                    length = length + 1
                }
                
                let SSID = NSString(bytes: array, length: length, encoding: String.Encoding.utf8.rawValue) as String!
                if SSID != nil {
                    if SSID?.isEmpty == false {
                        var isPtotected : Bool = false
                        if buffer[0] != 0 {
                            isPtotected = true
                        }
                        let item = WiFiItems(SSID: SSID!, RSSI: 0, isProtected: isPtotected, status: WiFiNetworkStatus.known)
                        knownNetworks.insert(item!, at: 0)
                        knownWiFiViewController?.networkUpdated(false, response: 0)
                    } else {
                        getKnownTimeoutTimer?.invalidate()
                        knownIsFetching = false
                        knownWiFiViewController?.networkUpdated(true, response: 0)
                        #if DEBUG
                            logMessageToCloud ("DBG: Known Wi-Fi received and updated")
                        #endif
                        
                        if visibleIsFetching == false {
                            toyWiFiStatus = ToyWiFiStatus.idle
                        }
                    }
                }  else {
                    #if DEBUG
                        logMessageToCloud ("DBG: Incorrect Known Wi-Fi SSID received")
                    #endif
                    getKnownTimeoutTimer?.invalidate()
                    knownIsFetching = false
                    knownWiFiViewController?.networkUpdated(true, response: 0)
                    if visibleIsFetching == false {
                        toyWiFiStatus = ToyWiFiStatus.idle
                    }
                }
                
                break
                
            case WIFI_VISIBLENETS_C: // List of visible networks ---------------------------------------
                var array = [UInt8]()
                guard let data = characteristic.value as NSData?
                    else {return}
                let buffer = data.u8s
                var length: Int = 0
                for i in 2...18{
                    if buffer[i] <= 0 {
                        break
                    }
                    array.append(buffer[i])
                    length = length + 1
                }
                let ssid = NSString(bytes: array, length: length, encoding: String.Encoding.utf8.rawValue) as String!
                let rssiBuffer  = data.i8s
                
                if ssid != nil {
                    if ssid?.isEmpty == false {
                        var isPtotected : Bool = false
                        if buffer[0] != 0 {
                            isPtotected = true
                        }
                        let rssi = rssiBuffer[1]

                        var status: WiFiNetworkStatus = WiFiNetworkStatus.unknown
                        if knownNetworks.isEmpty != true { // Update known networks list

                            objc_sync_enter(knownNetworks) // Lock Known
                            defer { objc_sync_exit(knownNetworks) }

                            for i in 0 ..< knownNetworks.count {
                                if knownNetworks[i].SSID == ssid && knownNetworks[i].isProtected == isPtotected{
                                    knownNetworks[i].status = WiFiNetworkStatus.visible
                                    knownNetworks[i].RSSI = rssi
                                    status = WiFiNetworkStatus.known
                                }
                            }
                        }
                        
                        objc_sync_enter(visibleNetworks)
                        defer { objc_sync_exit(visibleNetworks) }
                        
                        if status == WiFiNetworkStatus.known {
                            visibleNetworks.insert(WiFiItems(SSID: ssid!, RSSI: rssi, isProtected: isPtotected, status: status)!, at: 0)
                        } else {
                            var count = visibleNetworks.count - 1
                            if count < 0 {
                                count = 0
                            }
                            visibleNetworks.insert(WiFiItems(SSID: ssid!, RSSI: rssi, isProtected: isPtotected, status: status)!,at: count)
                        }
                        visibleWiFiViewController?.networkUpdated(false, response: 0)

                    } else {
                        #if DEBUG
                            logMessageToCloud ("DBG: Visible received")
                        #endif
                        
                        getVisibleTimeoutTimer?.invalidate()
                        visibleIsFetching = false
                        visibleWiFiViewController?.networkUpdated(true, response: 0)
                        
                        if knownIsFetching == false {
                            knownWiFiViewController?.networkUpdated(true, response: 0)
                            toyWiFiStatus = ToyWiFiStatus.idle
                        }
                    }
                }
                break
                
            default:
                break
            }
        } else if toyStatus == ToyStatus.upgrading {
            switch characteristic.uuid {
                
            case WIFI_UPGRADE_C:
                guard let data = characteristic.value as NSData?
                else {return}
                
                let array = data.u8s
                toyUpgradeStatus = ToyUpgradeStatus.init(raw: array[0])!
                let previousState: UInt8 = array[1]
                let stateInfo : UInt8 = array[2]
                let progress : UInt8 = array[3]
                if toyUpgradeStatus == ToyUpgradeStatus.upgradeIdle {
                    self.myToyViewController?.upgradeDidChange(false, progress: 0)
                    last10PendingUpgradeIdle = true
                    last10IsFetching = false
                    last10ReceivedButNotUpdated = false
                    self.toyStatus = ToyStatus.connected
                } else {
                    self.upgradeDidChange(previousState: previousState, stateInfo: stateInfo, progress: progress)
                }
                break
            
            case WIFI_STATUS_C: // Current connected network status. SSID is empty if not connected
                if toyWiFiStatus == ToyWiFiStatus.connecting {
                    getWiFiStatusTimer?.invalidate()
                    getWiFiStatusTimer = nil
                }
                var array = [UInt8]()
                
                guard let data = characteristic.value as NSData?
                    else {return}
                let buffer = data.u8s
                
                var length: Int = 0
                for i in 2...18{
                    if buffer[i] == 0 {
                        break
                    }
                    array.append(buffer[i])
                    length = length + 1
                }
                let SSID = NSString(bytes: array, length: length, encoding: String.Encoding.utf8.rawValue) as String!
                let response  = data.i8s  //response[0] - status code, response[1] - RSSI if connected
                
                if response[0] == 0 && SSID != nil && SSID?.isEmpty == false {
                    myToyViewController?.ConnectedWiFi.isHidden = false
                    myToyViewController?.ConnectedWiFi.text = "Connected to: " + String(describing: SSID!)
                    #if DEBUG
                        logMessageToCloud ("DBG: .upgrading -> connected to " + String (describing: SSID!))
                    #endif
                } else if response[0] == 1 && SSID != nil && SSID?.isEmpty == false {
                    myToyViewController?.ConnectedWiFi.isHidden = true
                    myToyViewController?.ConnectedWiFi.text = ""
                    #if DEBUG
                        logMessageToCloud ("DBG: .upgrading -> disconnected from " + String (describing: SSID!))
                    #endif
                } else {
                    myToyViewController?.ConnectedWiFi.isHidden = true
                    myToyViewController?.ConnectedWiFi.text = ""
                    wifiErrorOccured(UInt8(response[0]))
                }
                break
                
            default:
                break
            }
        }
    } //<------ Leave Critical section
    
    
    //----------------------------------------------------------
    func theToyIsFound (_ peripheral: CBPeripheral) {
        self.myBLECentralManager.stopScan()
        toyRescanTimer?.invalidate()
        toyRescanTimer = nil
        
        defer {
            // Clean all previously discovered peripheral, they are not required anymore
            for periph in discoveredPeripherals{
                if periph != peripheral {
                    myBLECentralManager.cancelPeripheralConnection(periph)
                }
            }
            discoveredPerifCharxs.removeAll()
            discoveredPeripherals.removeAll()
        }
        
        self.toyPeripheral = peripheral
        self.toyCharx = self.discoveredPerifCharxs[peripheral]
        self.toySuplCharx = ToySupplimentaryCharx (setup: SetupCharxs(), content: ContentCharxs(), network: WiFiCharx())
        sessionSettings.toyProfile.toyID = (toyCharx?.toyID)!
        sessionSettings.toyProfile.deviceInfo = (toyCharx?.deviceInfo)!

        
        // Post Toy information to the Cloud
        if expectedToyID == ""{
            expectedToyID = sessionSettings.toyProfile.toyID
            sessionSettings.toyProfile.toyName = "KiQ " + String(sessionSettings.toyProfile.toyID)

            cloundService.addToy(sessionSettings){ (success) -> Void in
                if success != true {
                    self.logMessageToCloud("ERROR: Failed to add Toy.")
                    var text : String = ""
                    if self.sessionSettings.sessionType == "facebook" {
                        text = "Try to sign up with your phone number."
                    } else {
                        text = "Try to aign up with your Facebook account."
                    }
                    self.myToyViewController?.displayMyAlertMessage("KiQ you are trying to connect seems to be belonged to another account. " + text)
                    self.resetToy()
                    self.sessionSettings.toyProfile.toyID = ""
                    self.sessionSettings.toyProfile.toyName = ""
                    self.expectedToyID = ""
                    self.toyStatus = ToyStatus.disconnected
                    self.toyStatus = ToyStatus.searching
                }
                else {
                    self.cloundService.getUserData(){ (success, userData) -> Void in
                        if success == true {
                            self.sessionSettings = userData
                            self.logMessageToCloud("NORMAL: New Toy " + String(self.sessionSettings.toyProfile.toyID) + " is added and connected")
                            self.toyStatus = ToyStatus.connected
                            
                            // Request services for the Toy
                            peripheral.discoverServices([SETUP_SERVICE_UUID, CONTENT_SERVICE_UUID, WIFI_SERVICE_UUID])
                            
                        } else {
                            self.myToyViewController?.displayMyAlertMessage("Sorry, there was a connection problem with KiQ Cloud. Please try again later.")
                            self.toyStatus = ToyStatus.disconnected
                            self.upperStatusLabel = "Toy Disconnected"
                            self.myToyViewController?.ConnectAnotherButton.isHidden = false
                            self.logMessageToCloud("ERROR: Failed to get User Data. Disconnecting.")
                        }
                    }
                }
            }
        } else {
            self.logMessageToCloud("DBG: Known Toy " + String(self.sessionSettings.toyProfile.toyID) + " is connected")
            self.toyStatus = ToyStatus.connected
            // Request services for the Toy
            peripheral.discoverServices([SETUP_SERVICE_UUID, CONTENT_SERVICE_UUID, WIFI_SERVICE_UUID])
            cloundService.updateToy(sessionSettings)
        }
    }
    
    //----------------------------------------------------------
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        
        guard  error == nil else {
            #if DEBUG
                logMessageToCloud("ERROR: didWriteValueForCharacteristic ->" + String(error.debugDescription))
            #endif
            return
        }
        
        objc_sync_enter(self) //<---   Enter Critical section
        defer { objc_sync_exit(self) }
        
        if  characteristic.uuid == HS_CLIENTINFO_C { //Reset was sent to the Toy
            if self.toyStatus == ToyStatus.resetting {
                self.sessionSettings.toyProfile.toyID = ""
                self.sessionSettings.toyProfile.toyName = ""
                self.expectedToyID = ""
                self.upperStatusLabel = "KiQ is disconnected for reset"
                self.myToyViewController?.ConnectAnotherButton.isHidden = false
                self.toyStatus = ToyStatus.disconnected
            myToyViewController?.displayMyAlertMessage(" Toy settings were reset to their defaults. !!! However Apple does not allow any application to completly \"Unpair\" devices from from iPhones !!!  To make the toy visible to other devices, you will need to manually \"Forget this Device\" in Bluetooth Settings of your iPhone")
            } else if self.toyStatus == ToyStatus.searching {
                discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent() // Clint ID for handshake was sent to the peripheral
            }
            return
        }
        /*
        if  characteristic.uuid == CONT_SENDFILE_C {
            print("2", CFAbsoluteTimeGetCurrent())
        }*/
    } //<---   Leave Critical section
    
    
    //----------------------------------------------------------
    // Read RSSI forPerepheral
    func checkToyBattery() {
        objc_sync_enter(self) //<-----   Enter Critical section
        defer { objc_sync_exit(self) }
        if toySuplCharx != nil {
            if toySuplCharx?.setup.statusCharx != nil {
                toyPeripheral?.readValue(for: (toySuplCharx?.setup.statusCharx)!)
                checkStatusSkipCount = 0
            }
        }
    }//<----  Leave Critical section
    
    
    //------------ Timer Callbacks -----------------------------
    //----------------------------------------------------------
    @objc func checkToyBLEStatus(){
        if toyStatus == ToyStatus.connected || toyStatus == ToyStatus.upgrading{
            if toyPeripheral?.state == CBPeripheralState.connected {
                if checkStatusSkipCount > 30 && toySuplCharx != nil {
                    let currentTime = (((Date().hour()) * 60) + (Date().minute()))
                    let start = (sessionSettings.silentSettings.start?.hour())! * 60 + (sessionSettings.silentSettings.start?.minute())!
                    let end = ((sessionSettings.silentSettings.end?.hour())! * 60 + (sessionSettings.silentSettings.end?.minute())!)

                    if centralController.sessionSettings.volume == 0 || (centralController.sessionSettings.silentSettings.isDndOn == true &&
                        (currentTime >= start && currentTime < end)) && myToyViewController?.CatPicture.image != UIImage(named: "BigCatSilent"){
                        myToyViewController?.CatPicture.image = UIImage(named: "BigCatSilent")
                    } else if myToyViewController?.CatPicture.image != UIImage(named: "BigCat"){
                        myToyViewController?.CatPicture.image = UIImage(named: "BigCat")
                    }
                    checkStatusSkipCount = 0
                    
                } else {
                    checkStatusSkipCount = checkStatusSkipCount + 1
                }
                //self.toyPeripheral?.readRSSI()
                return
            } else {
                #if DEBUG
                    logMessageToCloud("DBG: Connection with Toy lost: .connected -> .disconnected -> .searching ")
                #endif
                toyStatus = ToyStatus.disconnected
                toyStatus = ToyStatus.searching
            }
        }
    }
    
    /*
    @objc func peripheral(_ peripheral: CBPeripheral, didReadRSSI: NSNumber, error: Error?){
        myToyViewController?.RSSILabel.text = "RSSI: " + String(describing: didReadRSSI)
    }*/
    
    //------------------------------------------------------------
    @objc func scanForPeripheral(){
        if bleStatus == .on && toyStatus == ToyStatus.searching {
            let connectedPeripherals = myBLECentralManager.retrieveConnectedPeripherals(withServices: [HS_SERVICE_UUID])
            
            objc_sync_enter(self) //<-----   Enter Critical section
            defer { objc_sync_exit(self) }
            
            if(connectedPeripherals.count != 0){
                for peripheral in connectedPeripherals {
                    if !discoveredPeripherals.contains(peripheral) {
                        peripheral.delegate = self
                        self.discoveredPerifCharxs[peripheral] = ToyCharx()
                        self.discoveredPerifCharxs[peripheral]?.lastResponseTime = CFAbsoluteTimeGetCurrent()
                        self.discoveredPerifCharxs[peripheral]?.BLEStatus = BLEConnectionStatus.paired
                        self.discoveredPeripherals.append(peripheral)
                        self.myBLECentralManager.connect(peripheral, options: nil)
                        #if DEBUG
                            logMessageToCloud("DBG: scanForPeripheral: KiQ already paired. Connecting...")
                        #endif
                    }
                }
            }
            
            if !myBLECentralManager.isScanning && (expectedToyID == "" || connectedPeripherals.count == 0){
                #if DEBUG
                    logMessageToCloud("DBG: scanForPeripheral: Start scanning for NEW peripherals")
                #endif
                myBLECentralManager.scanForPeripherals(withServices: [HS_SERV_ADV_UUID], options: nil)
            }
            
            let currentTime = CFAbsoluteTimeGetCurrent()
            
            for peripheral in discoveredPeripherals {
                let timeDiff = currentTime - (discoveredPerifCharxs[peripheral]?.lastResponseTime)!
                if peripheral.state == CBPeripheralState.disconnected || peripheral.state == CBPeripheralState.disconnecting ||
                    (timeDiff > 15 && self.discoveredPerifCharxs[peripheral]?.BLEStatus == BLEConnectionStatus.connecting) ||
                    (timeDiff > 15 && self.discoveredPerifCharxs[peripheral]?.BLEStatus == BLEConnectionStatus.paired) ||
                    (timeDiff > 20 && self.discoveredPerifCharxs[peripheral]?.BLEStatus == BLEConnectionStatus.clientIdSent) {
                    #if DEBUG
                        logMessageToCloud("DBG: scanForPeripheral: resetting connection with:" + String (describing: peripheral.name))
                    #endif
                    myBLECentralManager.cancelPeripheralConnection(peripheral)
                    discoveredPerifCharxs.removeValue(forKey: peripheral)
                    discoveredPeripherals.remove(at: discoveredPeripherals.index(of: peripheral)!)
                }
            }
            if self.toyRescanTimer == nil {
                self.toyRescanTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(CentralViewController.scanForPeripheral), userInfo: nil, repeats: true)
            }
        } else {
            toyRescanTimer?.invalidate()
            toyRescanTimer = nil
        }
    }
    
    // NSData to struct and back
    //------------------------------------------------------------
    private func encode<T> (_ value_: T) -> Data {
        var value = value_
        return withUnsafePointer(to: &value) { p in
            Data(bytes: p, count: MemoryLayout<T>.size)
        }
    }
    
    
    //------------------------------------------------------------
    private func encodeWithMaxLenght<T> (_ value_: T, length: Int) -> Data {
        var value = value_
        if MemoryLayout<T>.size < length {
            return withUnsafePointer(to: &value) { p in
                Data(bytes: p, count: MemoryLayout<T>.size)
            }
        } else {
            return withUnsafePointer(to: &value) { p in
                Data(bytes: p, count: length)
            }
        }
    }


    //------------------------------------------------------------
    private func decode<T>(_ data: Data) -> T {
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        (data as NSData).getBytes(pointer, length: MemoryLayout<T>.size)
        return pointer.move()
    }
    

    //*****************************************************************
    //-----------------------------------------------------------------
    // Toy Control functions - available even if Internet connection is down
    
    //Tpy name --------------------------------------------------------
    //-----------------------------------------------------------------------
    func toyNameDidChange (_ name: String)
    {
        sessionSettings.toyProfile.toyName = name
        cloundService.updateToy(sessionSettings)
        if self.cloundService.isCloudSessionEnabled() == false {
            self.upperStatusLabel = self.sessionSettings.toyProfile.toyName + " is connected"
            self.myToyViewController?.bleDidChange(isWorking: (self.myToyViewController?.FetchingDataIndicator.isAnimating)!)
        }
    }
    
    // Toy Settings / Sound Voulme ------------------------------------
    //-----------------------------------------------------------------------
    func soundVoulumeDidChange (_ volume: Float) ->Float{
        
        objc_sync_enter(self) //<-----   Enter Critical section
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected && toySuplCharx?.setup.volumeCharx != nil {
            
            var settings = ToyVoiceSettings()
            settings.volume = UInt8(volume * 100)
            settings.voiceType = sessionSettings.voiceType
            let dataToWrite = encode(settings)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.setup.volumeCharx)!, type: CBCharacteristicWriteType.withResponse)
            sessionSettings.volume = settings.volume
            cloundService.updateToy(sessionSettings)
            return volume
            }
        return Float(sessionSettings.volume) / 100
    }
    
    //-----------------------------------------------------------------------
    func voiceTypeDidChange (_ type: UInt8) -> Bool{
        
        objc_sync_enter(self) //<-----   Enter Critical section
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected && toySuplCharx?.setup.volumeCharx != nil {
            var settings = ToyVoiceSettings()
            settings.volume = sessionSettings.volume
            settings.voiceType = type
            let dataToWrite = encode(settings)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.setup.volumeCharx)!, type: CBCharacteristicWriteType.withResponse)
            sessionSettings.voiceType = type
            cloundService.updateToy(sessionSettings)
            return true
        }
        return false
    }
    
    //---- Change Silent Period Settings -------------------------------
    //-----------------------------------------------------------------------
    func silentPeriodDidChange(_ silentSettings: SilentTimeSettings?){
        sessionSettings.silentSettings = silentSettings!
        generalSettingDidChange()
            
    }
    
    //---- Change General Settings -------------------------------
    //-----------------------------------------------------------------------
    func generalSettingDidChange(){
        objc_sync_enter(self) //<-----   Lock BLE Characteristics
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected && toySuplCharx?.setup.settingsCharx != nil {
            var settingsBLE = ToyGeneralSettings()
            if sessionSettings.silentSettings.isDndOn == true {
                settingsBLE.fromTime = UInt16(((sessionSettings.silentSettings.start?.hour())! * 60) + (sessionSettings.silentSettings.start?.minute())!)
                settingsBLE.toTime = UInt16(((sessionSettings.silentSettings.end?.hour())! * 60) + (sessionSettings.silentSettings.end?.minute())!)
            }

            var notificationsBLE: Int = 0
            for i in 0 ... 2{
                for notification in sessionSettings.toyProfile.notifSettings[i]{
                    if notification.on == true {
                        notificationsBLE |=  ( 1 << notification.bit)
                    }
                }
            }
            
            settingsBLE.forbidden = UInt16(0)
            settingsBLE.notifications = UInt32(notificationsBLE)
            let dataToWrite = encode(settingsBLE)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.setup.settingsCharx)!, type: CBCharacteristicWriteType.withResponse)
            cloundService.updateToy(sessionSettings)
        }
    }
    
    //*****************************************************************
    //-----------------------------------------------------------------
    // Content related functions
    // get last 10 played -------------------------------------------
    func getPlayedFile(fileNumber: UInt8){
        
        DispatchQueue.main.async{
            objc_sync_enter(self) //<-----   Lock BLE characteristics
            defer { objc_sync_exit(self) }
            
            if self.toyStatus == .connected && self.toySuplCharx?.content.sendFileCharx != nil{
                let dataToWrite = self.encode(fileNumber)
                self.toyPeripheral?.writeValue(dataToWrite, for: (self.toySuplCharx?.content.sendFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                if self.getLast10TimeoutTimer == nil{
                    self.getLast10TimeoutTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(CentralViewController.playedFileFetchingTimeout), userInfo: nil, repeats: false)
                }
            }
        }
    }
    
    // Last 10 played were requested, but were not received --------------
    //-----------------------------------------------------------------
    @objc func playedFileFetchingTimeout(){
        #if DEBUG
            logMessageToCloud("DBG: last10requsetTimeout")
        #endif
        getLast10TimeoutTimer?.invalidate()
        getLast10TimeoutTimer = nil
        if last10IsFetching == true && last10ReceivedButNotUpdated == false {
            getPlayedFile(fileNumber: 0)
        }
    }
    
    
    // Toy Settings / Forget Toy -------------------------------------------
    // Sending command to the Cloud to remove a Toy from a User
    // Resseting Toy if success
    //-----------------------------------------------------------------
    func forgetToy (_ completion: @escaping ( _ success: Bool) -> Void){
        cloundService.forgetToy() { (success) in
            if success == true {
                self.resetToy()
            }
            completion(success)
        }
    }
    
    // Toy Settings / Reset Toy -------------------------------------------
    // Sending BLE command to Toy to reset it to defailts
    //-----------------------------------------------------------------
    func resetToy (){
        objc_sync_enter(self) //<-----   Lock BLE Characteristics
        defer { objc_sync_exit(self) }
        
        if self.toyCharx?.hsClientCharx != nil {
            let value : UInt32 = 0xFFFFFFFF
            let dataToWrite = self.encode(value)
            self.toyPeripheral?.writeValue(dataToWrite, for: (self.toyCharx?.hsClientCharx)!, type: CBCharacteristicWriteType.withResponse)
            self.logMessageToCloud("NORMAL: Toy with ID: " + String(self.sessionSettings.toyProfile.toyID) + " was reset")
        }
    }
    
    //************************************************************************
    // MARK: Wi-Fi Settings **************************************************
    
    //-----------------------------------------------------------------------
    func getWiFiStatus() -> ToyWiFiStatus {
        return toyWiFiStatus
    }
    
    //-----------------------------------------------------------------------
    @objc func getWiFiStatusTimeoutOccured(){
        #if DEBUG
            logMessageToCloud("DBG: getWiFiStatusTimeoutOccured")
        #endif
        getWiFiStatusTimer?.invalidate()
        getWiFiStatusTimer = nil
        
        objc_sync_enter(visibleNetworks)
        defer { objc_sync_exit(visibleNetworks) }
        
        for i in 0 ..< visibleNetworks.count {
            if visibleNetworks[i].status == WiFiNetworkStatus.connecting {
                if visibleNetworks[i].RSSI == 1 {
                    visibleNetworks.remove(at: i)
                    visibleNetworks.append(WiFiItems(SSID: "Other...", RSSI: 1, isProtected: false, status: WiFiNetworkStatus.unknown)!)
                } else {
                    visibleNetworks[i].status = WiFiNetworkStatus.unknown
                }
            }
        }
        toyWiFiStatus = ToyWiFiStatus.idle
        visibleWiFiViewController?.networkUpdated(false, response: 101)
    }
    
    //---- Toy Settings / Wi-Fi networks list -------------------------------
    //-----------------------------------------------------------------------
    func getKnownWiFiNetworks(_ timeout: Double) -> Bool{
        if knownIsFetching == true || toyWiFiStatus == ToyWiFiStatus.connecting {
            return false
        }
        
        if getKnownLastRequestedTime == nil {
            getKnownLastRequestedTime = CFAbsoluteTimeGetCurrent()
        } else if CFAbsoluteTimeGetCurrent() - getKnownLastRequestedTime! < timeout {
            return false
        }
        
        objc_sync_enter(self) //<-----  Lock BLE Characteristics
        defer { objc_sync_exit(self) }
    
        if toyStatus == .connected && toySuplCharx?.network.makeAction != nil {

            let dataToWrite = encode(WIFI_GETKNOWN_NETWORKS)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.makeAction)!, type: CBCharacteristicWriteType.withResponse)
            toyWiFiStatus = ToyWiFiStatus.fetching
            knownIsFetching = true
            
            #if DEBUG
                logMessageToCloud("DBG: Requesting known WiFi networks")
            #endif

            getKnownLastRequestedTime = CFAbsoluteTimeGetCurrent()
            getKnownTimeoutTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(CentralViewController.getKnownWiFiTimeoutOccured), userInfo: nil, repeats: false)
            
            
        } else {
            knownIsWaitingForCharx = true
            #if DEBUG
                logMessageToCloud("DBG: Requesting known WiFi networks with delay")
            #endif
        }
        return true
    }
    
    //-----------------------------------------------------------------------
    @objc func getKnownWiFiTimeoutOccured(){
        #if DEBUG
            logMessageToCloud("DBG: getKnownWiFiTimeoutOccured")
        #endif
        getKnownTimeoutTimer?.invalidate()
        knownIsFetching = false
        if visibleIsFetching == false && toyWiFiStatus == ToyWiFiStatus.fetching {
            toyWiFiStatus = ToyWiFiStatus.idle
        }
        knownWiFiViewController?.networkUpdated(true, response: 100)
    }
    
    //---- Toy Settings / Get Visible Networks -------------------------------
    //-----------------------------------------------------------------------
    func getVisibleWiFiNetworks(_ timeout: Double) -> Bool{
        if visibleIsFetching == true || toyWiFiStatus == ToyWiFiStatus.connecting {
                return false
        }
        
        if getVisibleLastRequestedTime == nil {
            getVisibleLastRequestedTime = CFAbsoluteTimeGetCurrent()
        } else if CFAbsoluteTimeGetCurrent() - getVisibleLastRequestedTime! < timeout {
            return false
        }
        
        objc_sync_enter(self) //<----- Lock BLE Characteristics
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected && toySuplCharx?.network.makeAction != nil {
            visibleIsFetching = true
            toyWiFiStatus = ToyWiFiStatus.fetching
            
            let dataToWrite = encode(WIFI_SCAN_NETWORKS)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.makeAction)!, type: CBCharacteristicWriteType.withResponse)
            
            #if DEBUG
                logMessageToCloud("DBG: Requesting visible WiFi networks")
            #endif
            
            objc_sync_enter(visibleNetworks) //<---- Lock Visible Networks
            defer { objc_sync_exit(visibleNetworks) }
            
            visibleNetworks.removeAll()
            visibleNetworks.append(WiFiItems(SSID: "Other...", RSSI: 1, isProtected: false, status: WiFiNetworkStatus.unknown)!)
            getVisibleLastRequestedTime = CFAbsoluteTimeGetCurrent()
            
            getVisibleTimeoutTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(CentralViewController.getVisibleWiFiTimeoutOccured), userInfo: nil, repeats: false)
        } else {
            visibleIsWaitingForCharx = true
            #if DEBUG
                logMessageToCloud("DBG: Requesting visible WiFi networks with delay")
            #endif
        }
        return true
    }
    
    //-----------------------------------------------------------------------
    @objc func getVisibleWiFiTimeoutOccured(){
        #if DEBUG
            logMessageToCloud("DBG: getVisibleWiFiTimeoutOccured")
        #endif
        getVisibleTimeoutTimer?.invalidate()
        visibleIsFetching = false
        if knownIsFetching == false && toyWiFiStatus == ToyWiFiStatus.fetching {
            toyWiFiStatus = ToyWiFiStatus.idle
        }
        visibleWiFiViewController?.networkUpdated(true, response: 100)
    }

    //---- Toy Settings / Connect Wi-Fi Network -------------------------------
    //-----------------------------------------------------------------------
    func connectWiFiNetwork(_ index: Int, password: String) ->Bool{
        
        objc_sync_enter(self) //<-------- Lock BLE characteristics
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected &&
             toySuplCharx?.network.makeAction != nil && toySuplCharx?.network.networkSSID != nil && toySuplCharx?.network.networkPassword != nil {
                
            objc_sync_enter(visibleNetworks) // <-------- Lock Visible Networks
            defer { objc_sync_exit(visibleNetworks) }
            
            var array: [UInt8] = Array(visibleNetworks[index].SSID.utf8)
            
            var length = visibleNetworks[index].SSID.lengthOfBytes(using: String.Encoding.utf8)
            if length < 18 {
                array.append(0)
                length = length + 1
            }
            var dataToWrite : Data = Data(bytes: UnsafePointer<UInt8>(array), count: length) // encodeWithMaxLenght(array, length: 18)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.networkSSID)!, type: CBCharacteristicWriteType.withResponse)
            toyWiFiStatus = ToyWiFiStatus.connecting
            if visibleNetworks[index].isProtected == true {
                var passArray: [UInt8] = Array(password.utf8)
                
                for _ in password.lengthOfBytes(using: String.Encoding.utf8)...59{
                    passArray.append(0)
                }
                
                dataToWrite = Data(bytes: UnsafePointer<UInt8>(passArray), count: 20)
                toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.networkPassword)!, type: CBCharacteristicWriteType.withResponse)
                dataToWrite = Data  (bytes: UnsafePointer<UInt8>(Array(passArray.dropFirst(20))), count: 20)
                toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.networkPassword)!, type: CBCharacteristicWriteType.withResponse)
                dataToWrite = Data(bytes: UnsafePointer<UInt8>(Array(passArray.dropFirst(40))), count: 20)
                toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.networkPassword)!, type: CBCharacteristicWriteType.withResponse)
            }
            
            dataToWrite = encode(WIFI_CONNECT_NETWORK)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.makeAction)!, type: CBCharacteristicWriteType.withResponse)
            visibleNetworks[index].status = WiFiNetworkStatus.connecting
            
            if getWiFiStatusTimer == nil {
                getWiFiStatusTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(CentralViewController.getWiFiStatusTimeoutOccured), userInfo: nil, repeats: false)
            }
            
            return true
        }
        return false
    } //<-----   Leave Critical section
    
    //---- Toy Settings /Forget Network -------------------------------
    //-----------------------------------------------------------------------
    func forgetWiFiNetwork(_ index: Int){ // Index is index in Known Networks
        
        objc_sync_enter(self) //<----- Lock BLE characteristics
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected &&
            toySuplCharx?.network.makeAction != nil && toySuplCharx?.network.networkSSID != nil && toySuplCharx?.network.networkPassword != nil {
                
            objc_sync_enter(knownNetworks) // <-------- Lock Known Networks
            defer { objc_sync_exit(knownNetworks) }

            var array: [UInt8] = Array(knownNetworks[index].SSID.utf8)
            var length = knownNetworks[index].SSID.lengthOfBytes(using: String.Encoding.utf8)
            if length < 18 {
                array.append(0)
                length = length + 1
            }
            var dataToWrite : Data = Data(bytes: UnsafePointer<UInt8>(array), count: length) // encodeWithMaxLenght(array, length: 18)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.networkSSID)!, type: CBCharacteristicWriteType.withResponse)
            
            dataToWrite = encode(WIFI_FORGET_NETWORK)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.makeAction)!, type: CBCharacteristicWriteType.withResponse)
            
            objc_sync_enter(visibleNetworks) // <---- Lock Visible Networks
            defer { objc_sync_exit(visibleNetworks) }
            
            for i in 0 ..< visibleNetworks.count{
                if visibleNetworks[i].SSID == knownNetworks[index].SSID && visibleNetworks[i].isProtected == knownNetworks[index].isProtected {
                    visibleNetworks[i].status = WiFiNetworkStatus.unknown
                    break
                }
            }
            knownNetworks.remove(at: index)
            return
        }
    }
    
    
    //---- Toy Settings /Forget Network -------------------------------
    //-----------------------------------------------------------------------
    func updateToyFirmware(){
        objc_sync_enter(self) //<----- Lock BLE characteristics
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected && toySuplCharx?.network.makeAction != nil  {
            let dataToWrite = encode(WIFI_UPDATE_TOY)
            toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.network.makeAction)!, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    //-----------------------------------------------------------------------
    func getUpgradeStatus(){
        objc_sync_enter(self) //<----- Lock BLE characteristics
        defer { objc_sync_exit(self) }
        
        if (toyStatus == .upgrading || toyStatus == .connected) && toySuplCharx?.network.upgradeStatus != nil  {
            toyPeripheral?.readValue(for: (toySuplCharx?.network.upgradeStatus)!)
        }
    }
    
    //************************************************************************
    // MARK: BLE Content
    
    //---- Play File with ID -------------------------------
    //-----------------------------------------------------------------------
    func playFile(_ joke: RecentItem){
        objc_sync_enter(self) //<-----   Lock BLE characteristics
        defer { objc_sync_exit(self) }
        
        if toyStatus == .connected && toySuplCharx?.content.playFileCharx != nil {
            if self.sessionSettings.voiceType == 0 {
                if joke.maleFileID != 0 {
                    let dataToWrite = encode(joke.maleFileID)
                    toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.content.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                } else if joke.femaleFileID != 0 {
                        let dataToWrite = encode(joke.femaleFileID)
                        toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.content.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                    #if DEBUG
                        logMessageToCloud("ERROR: playFile -> No Male FileID for FileID: " + String(joke.fileID))
                    #endif
                } else {
                    let dataToWrite = encode(joke.fileID)
                    toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.content.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                    #if DEBUG
                        logMessageToCloud("ERROR: playFile -> No Male AND Femail FileID for FileID: " + String(joke.fileID))
                    #endif
                }
            }
            if self.sessionSettings.voiceType == 1 {
                if joke.femaleFileID != 0 {
                    let dataToWrite = encode(joke.femaleFileID)
                    toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.content.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                } else if joke.maleFileID != 0 {
                    let dataToWrite = encode(joke.maleFileID)
                    toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.content.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                    #if DEBUG
                        logMessageToCloud("ERROR: playFile -> No Female FileID for FileID: " + String(joke.fileID))
                    #endif
                } else {
                    let dataToWrite = encode(joke.fileID)
                    toyPeripheral?.writeValue(dataToWrite, for: (toySuplCharx?.content.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                    #if DEBUG
                        logMessageToCloud("ERROR: playFile -> No Male AND Femail FileID for FileID: " + String(joke.fileID))
                    #endif
                }
            }
        }
    }
    
    //-----------------------------------------------------------------------
    func logMessageToCloud (_ message : String){
        cloundService.logMessageToCloud(message)
    }
    
    //----------------------------------------------------
    func upgradeDidChange (previousState: UInt8, stateInfo: UInt8, progress: UInt8) {
        if toyUpgradeStatus != ToyUpgradeStatus.upgradeIdle {
            switch toyUpgradeStatus {
            case ToyUpgradeStatus.upgradeReceiving:
                if stateInfo == 1 {
                    lowerStatusLabel = "Connecting to KiQ Cloud ... \n"
                    myToyViewController?.upgradeDidChange(true, progress: 0)
                }
                if stateInfo == 7 {
                    lowerStatusLabel = "Downloading ... " + String(describing: progress) + "%\n"
                    myToyViewController?.upgradeDidChange(true, progress: (Float(progress) / 100))
                }
                break
            case ToyUpgradeStatus.upgradeExtracting:
                lowerStatusLabel = "Extracting ... " + String(describing: progress) + "%\n"
                myToyViewController?.upgradeDidChange(true, progress: (Float(progress) / 100))
                break
                
            case ToyUpgradeStatus.upgradeRestarting:
                lowerStatusLabel = "Upgrading ... \n"
                myToyViewController?.upgradeDidChange(true, progress: 0)
                break
                
            default:
                upperStatusLabel = String(describing: toyUpgradeStatus) + " i = " + String(describing: stateInfo) + " p = " + String(describing: progress)
                break
            }
        }
    }
    
    //----------------------------------------------------
    func wifiErrorOccured(_ error: UInt8) {
        switch error {
        case 5:
            myToyViewController?.displayMyAlertMessage("Unable to connect to known Wi-Fi network. Probably network password was changed")
            break
        case 6:
            myToyViewController?.displayMyAlertMessage("Unable to connect to KiQ cloud server. Probably some DNS problem occured.")
            break
        case 7:
            myToyViewController?.displayMyAlertMessage("Unable to connect to KiQ cloud server. Probably beacause of a Captive Portal.")
            break
        case 8:
            myToyViewController?.displayMyAlertMessage("Battery is too low to start the update procedure")
            break
        case 10:
            myToyViewController?.displayMyAlertMessage("Тhere are no known Wi-Fi networks found. Wi-Fi connection is requared to get upgrade data from KiQ Cloud. Please try again or connect to a new Wi-Fi network.")
            break
        default:
            break
        }
    }
    
    //----------------------------------------------------
    func batteryLevel() -> UInt8 {
        if toyCharx != nil {
            return (toyCharx?.batteryLevel)!
        }
        return 0
    }
    
    
    //----------------------------------------------------
    func isCharging() -> Bool {
        if toyCharx != nil {
            return (toyCharx?.isCharging)!
        }
        return false
    }
    
    //----------------------------------------------------
    func isSilent() -> Int {
        let currentTime = (((Date().hour()) * 60) + (Date().minute()))
        if centralController.sessionSettings != nil && toyCharx != nil {
            let start = (centralController.sessionSettings?.silentSettings.start?.hour())! * 60 + (centralController.sessionSettings?.silentSettings.start?.minute())!
            let end = ((centralController.sessionSettings?.silentSettings.end?.hour())! * 60 + (centralController.sessionSettings?.silentSettings.end?.minute())!)
            
            if centralController.sessionSettings.volume < 3 {
                return 1
            }
            if centralController.sessionSettings.silentSettings.isDndOn == true && (currentTime >= start && currentTime < end){
                return 2
            }
            if toyCharx?.isSilent == true {
                return 3
            }
        }
        return 0
    }
}




