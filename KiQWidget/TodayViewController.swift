//
//  TodayViewController.swift
//  KiQToyToday
//
//  Created by Maxim Kitaygora on 9/29/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import UIKit
import CoreBluetooth
import NotificationCenter


//------------ UI Colors definition -----------------------------------------------------
let MY_RED_COLOR =  UIColor.init(hexString: "ff3b30")
let MY_PINK_COLOR =  UIColor.init(hexString: "ff2d55")
let MY_BLUE_COLOR = UIColor.init(hexString: "007aff")
let MY_GREEN_COLOR = UIColor.init(hexString: "4cd964")

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

let HS_SERV_ADV_UUID      = CBUUID(string: "0040")
let HS_SERVICE_UUID       = CBUUID(string: "00000040-1212-EFDE-1523-785FEABCD123")

// Content -----------------------------------------------------------------------
let CONTENT_SERVICE_UUID  = CBUUID(string: "00000020-1212-EFDE-1523-785FEABCD123")
let CONT_PLAYFYLE_C       = CBUUID(string: "00000021-1212-EFDE-1523-785FEABCD123")
let CONT_FILEINFO_C       = CBUUID(string: "00000022-1212-EFDE-1523-785FEABCD123")
let CONT_SENDFILE_C       = CBUUID(string: "00000023-1212-EFDE-1523-785FEABCD123")

// Settings ----------------------------------------------------------------------
let SETUP_SERVICE_UUID      = CBUUID(string: "00000030-1212-EFDE-1523-785FEABCD123")
let SETUP_VOICE_C           = CBUUID(string: "00000031-1212-EFDE-1523-785FEABCD123")
let SETUP_STATUS_C          = CBUUID(string: "00000033-1212-EFDE-1523-785FEABCD123")

// Status representing BLE connection status --------------------------------------
enum BLEConnectionStatus {
    case paired
    case clientIdSent
    case connecting
}

struct ToySettings {
    var voiceCharx:         CBCharacteristic?
    var statusCharx:        CBCharacteristic?
    var playFileCharx:      CBCharacteristic?
    var getFileCharx:       CBCharacteristic?
    var filePlaiedCharx:    CBCharacteristic?
    var isCharging:         Bool = false
    var isSilent:           Bool = false
    var batteryLevel:       UInt8 = 0
}

class TodayViewController: UIViewController, NCWidgetProviding, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // Toy BLE status of connection ----------------------------------------------
    var toyStatus: ToyStatus = .disconnected {
        didSet {
            switch toyStatus {  // SEARCHING ----------------------
            case ToyStatus.searching:
                DispatchQueue.main.async{
                    #if DEBUG
                        print("TODAY: ToyStatus.searching")
                    #endif
                    self.scanForPeripheral()
                    self.playActivityIndicator.startAnimating()
                    self.toyStatusLabel.text = ""
                    UIView.animate(withDuration: 0.3) { () -> Void in
                        self.toyStatusLabel.layer.opacity = 0
                        self.playActivityIndicator.layer.opacity = 1
                        self.batteryPicture.layer.opacity = 0
                        self.playButton.layer.opacity = 0
                        self.twitterButton.layer.opacity = 0
                        self.fbButton.layer.opacity = 0
                        self.flashPicture.layer.opacity = 0
                        self.playButton.isEnabled = false
                        self.twitterButton.isEnabled = false
                        self.fbButton.isEnabled = false
                    }
                    
                    if self.toyRescanTimer == nil {
                        self.toyRescanTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(TodayViewController.scanForPeripheral), userInfo: nil, repeats: true)
                    }
                }
                break
                
            case ToyStatus.connected:  //CONNECTED ---------------------------------
                DispatchQueue.main.async{
                    #if DEBUG
                        print("TODAY: ToyStatus.connected")
                    #endif
                    
                    if self.toyCheckStatusTimer == nil {
                        self.toyCheckStatusTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.checkToyBLEStatus), userInfo: nil, repeats: true)
                    }
                    UIView.animate(withDuration: 0.5) { () -> Void in
                        self.toyStatusLabel.layer.opacity = 0
                    }
                }
                break
                
            case ToyStatus.disconnected:  // IDLE ---------------------------
                DispatchQueue.main.async{
                    #if DEBUG
                        print("TODAY:  ToyStatus.disconnected")
                    #endif
                    
                    self.stopAndInvalidatePeripherals()
                    UIView.animate(withDuration: 0.2) { () -> Void in
                        self.playActivityIndicator.layer.opacity = 0
                        self.flashPicture.layer.opacity = 0
                        self.batteryPicture.layer.opacity = 0
                        self.playButton.layer.opacity = 0
                        self.twitterButton.layer.opacity = 0
                        self.fbButton.layer.opacity = 0
                        self.playButton.isEnabled = false
                        self.twitterButton.isEnabled = false
                        self.fbButton.isEnabled = false
                    }
                }
                break
                
            case ToyStatus.upgrading:
                DispatchQueue.main.async{
                    #if DEBUG
                        print("TODAY: ToyStatus.upgrading")
                    #endif
                    self.toyStatusLabel.text = "KiQ is being upgraded"
                    UIView.animate(withDuration: 0.5) { () -> Void in
                        self.toyStatusLabel.layer.opacity = 1
                        self.batteryPicture.layer.opacity = 0
                        self.playButton.layer.opacity = 0
                        self.flashPicture.layer.opacity = 0
                        self.twitterButton.layer.opacity = 0
                        self.fbButton.layer.opacity = 0
                        self.playButton.isEnabled = false
                        self.twitterButton.isEnabled = false
                        self.fbButton.isEnabled = false
                    }
                    
                    if self.toyCheckStatusTimer == nil {
                        self.toyCheckStatusTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(self.checkToyBLEStatus), userInfo: nil, repeats: true)
                    }
                }
                break
                
                
            case ToyStatus.resetting:
                DispatchQueue.main.async{
                    #if DEBUG
                        print("TODAY: ToyStatus.resetting")
                    #endif
                    self.toyStatusLabel.text = "KiQ is being reset"
                    UIView.animate(withDuration: 0.5) { () -> Void in
                        self.toyStatusLabel.layer.opacity = 1
                        self.playActivityIndicator.layer.opacity = 0
                        self.batteryPicture.layer.opacity = 0
                        self.playButton.layer.opacity = 0
                        self.flashPicture.layer.opacity = 0
                        self.twitterButton.layer.opacity = 0
                        self.fbButton.layer.opacity = 0
                        self.playButton.isEnabled = false
                        self.twitterButton.isEnabled = false
                        self.fbButton.isEnabled = false
                    }
                }
                break
            }
        }
    }
    
    private var bleStatus: BLEStatus = .off {
        didSet {
            switch bleStatus {
            case .on:
                self.toyStatus = ToyStatus.searching
                break
            case .off:
                self.toyStatus = ToyStatus.disconnected
                self.toyStatusLabel.text = "Bluetooth is turned Off"
                UIView.animate(withDuration: 0.5) { () -> Void in
                    self.toyStatusLabel.layer.opacity = 1
                }
                break
            }
        }
    }
    
    private var toyCheckStatusTimer:  Timer?
    private var toyConnectionTimeout: Timer?
    private var toyRescanTimer: Timer?
    private var playFileTimer: Timer?
    private var myBLECentralManager : CBCentralManager!

    
    private var toyPeripheral: CBPeripheral?
    private var toySettings : ToySettings?
    private var lastFilePlayed: UInt32 = 0
    private var lastFilePlayedPos: UInt8 = 9
    
    //-----------------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let screenSize: CGRect = UIScreen.main.bounds
        
        switch screenSize.height {
            
        case 480:  //iPhone 4S
            
            break
            
        case 568:  //iPhone 5S
            aiXposConstraint.constant = -25
            playXposConstraint.constant = 20
            fbXposConstraint.constant = -30
            twitterXposConstraint.constant = -80
            playButtonHeigh.constant = 40
            twitterButtonHeigh.constant = 40
            fbButtonHeigh.constant = 40
            break
        default:

            break
        }
        
    }
    
    //-----------------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        toyStatusLabel.layer.opacity = 0
        playActivityIndicator.layer.opacity = 0
        flashPicture.layer.opacity = 0
        batteryPicture.layer.opacity = 0
        playButton.layer.opacity = 0
        twitterButton.layer.opacity = 0
        fbButton.layer.opacity = 0
        playButton.isEnabled = false
        lastFilePlayedPos = 9
    }
    
    //----------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if myBLECentralManager == nil{
            myBLECentralManager = CBCentralManager(delegate: self, queue: nil)
        } else {
            toyStatus = ToyStatus.searching
        }
    }
    
    //----------------------------------------------------
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        toyStatusLabel.text = ""
        toyStatusLabel.layer.opacity = 0
        toyRescanTimer?.invalidate()
        toyRescanTimer = nil
        toyStatus = ToyStatus.disconnected
    }
    
    
    //-----------------------------------------------------------------
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //-----------------------------------------------------------------
    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void) {
        completionHandler(NCUpdateResult.newData)
    }
    
    @IBOutlet weak var popParrentAppButton: UIButton!
    @IBOutlet weak var toyStatusLabel: UILabel!
    @IBOutlet weak var batteryPicture: UIImageView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var batteriPicWidth: NSLayoutConstraint!
    @IBOutlet weak var batteryPicAspect: NSLayoutConstraint!
    @IBOutlet weak var flashPicture: UIImageView!
    @IBOutlet weak var playActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var twitterButton: UIButton!
    @IBOutlet weak var fbButton: UIButton!
    @IBOutlet weak var playXposConstraint: NSLayoutConstraint!
    @IBOutlet weak var fbXposConstraint: NSLayoutConstraint!
    @IBOutlet weak var twitterXposConstraint: NSLayoutConstraint!
    @IBOutlet weak var playButtonHeigh: NSLayoutConstraint!
    @IBOutlet weak var twitterButtonHeigh: NSLayoutConstraint!
    @IBOutlet weak var fbButtonHeigh: NSLayoutConstraint!
    @IBOutlet weak var aiXposConstraint: NSLayoutConstraint!
    
    //-----------------------------------------------------------------
    @IBAction func popParrentAppButtonTapped(_ sender: AnyObject) {
        let url: NSURL? = NSURL(string: "KiQToy://main")!
        
        if let appurl = url {
            self.extensionContext!.open(appurl as URL,
                                        completionHandler: nil)
        }
    }
    
    @IBAction func twitterButtonTapped(_ sender: AnyObject) {
        let url: NSURL? = NSURL(string: "KiQToy://twitter")!
        
        if let appurl = url {
            self.extensionContext!.open(appurl as URL,
                                        completionHandler: nil)
        }
    }

    @IBAction func fbButtonTapped(_ sender: AnyObject) {
        let url: NSURL? = NSURL(string: "KiQToy://fb")!
        
        if let appurl = url {
            self.extensionContext!.open(appurl as URL,
                                        completionHandler: nil)
        }
    }
    
    //-----------------------------------------------------------------
    @IBAction func playButtonTapped(_ sender: AnyObject) {
        if toyStatus == .connected && toySettings?.playFileCharx != nil {
            let dataToWrite = encode(lastFilePlayed)
            toyPeripheral?.writeValue(dataToWrite, for: (toySettings?.playFileCharx)!, type: CBCharacteristicWriteType.withResponse)
            playFileTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(playFileTimeout), userInfo: nil, repeats: false)
            playButton.isEnabled = false
        }
    }
    
    //-----------------------------------------------------------------
    @objc func playFileTimeout(){
        playButton.isEnabled = true
    }
    
    //------------------------------------------------------------
    @objc func scanForPeripheral(){
        if bleStatus == .on && toyStatus == ToyStatus.searching{
            let connectedPeripherals = myBLECentralManager.retrieveConnectedPeripherals(withServices: [HS_SERVICE_UUID])
            
            if(connectedPeripherals.count != 0){
                for peripheral in connectedPeripherals {
                    if toyPeripheral == nil && peripheral.state == CBPeripheralState.disconnected {
                        toyPeripheral = peripheral
                        toyPeripheral!.delegate = self
                        self.myBLECentralManager.connect(toyPeripheral!, options: nil)
                        self.toyConnectionTimeout = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.connectionTimeoutOccured), userInfo: nil, repeats: false)
                        return
                    }
                }
            }
        }
    }
    
    //----------------------------------------------------------
    @objc func connectionTimeoutOccured(){
        if bleStatus == .on && toyStatus == ToyStatus.searching {
            myBLECentralManager.cancelPeripheralConnection(toyPeripheral!)
            toyPeripheral = nil
        }
    }
    
    //----------------------------------------------------------
    @objc func checkToyBLEStatus(){
        if toyStatus == ToyStatus.connected || toyStatus == ToyStatus.upgrading{
            if toyPeripheral?.state == CBPeripheralState.connected {
                return
            } else {
                #if DEBUG
                    print("TODAY: Connection with Toy lost")
                #endif
                toyStatus = ToyStatus.disconnected
                toyStatus = ToyStatus.searching
            }
        }
    }
    
    //--------------------------------------------------------
    func toyStatusDidChange(batteryLevel: UInt8, isCharging: Bool, isSilent: Bool){
        var imageSize = batteryPicture.image?.size
        var toyBatteryLevel: UInt8 = 1
        toyBatteryLevel = batteryLevel
        if imageSize != nil {
            
            flashPicture.isHidden = !isCharging
            
            imageSize?.width = (batteriPicWidth.constant - 6) * CGFloat(toyBatteryLevel)/100
            imageSize?.height = batteriPicWidth.constant / batteryPicAspect.multiplier - 2
            
            let lastView = batteryPicture.subviews.last
            lastView?.removeFromSuperview()
            let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 1, y: 1), size: imageSize!))
            imageView.layer.cornerRadius = 2
            imageView.layer.masksToBounds = true
            batteryPicture.addSubview(imageView)
            guard let image = drawCustomImage(imageSize!, toyBatteryLevel: toyBatteryLevel)
                else {return}
            imageView.image = image
        }
    }
    
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
    
    //----------------------------------------------------------
    func drawCustomImage(_ size: CGSize, toyBatteryLevel: UInt8) -> UIImage? {
        // Setup our context
        let bounds = CGRect(origin: CGPoint.zero, size: size)
        let opaque = false
        let scale: CGFloat = 0
        UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
        guard let context = UIGraphicsGetCurrentContext()
            else {return nil}
        
        if toyBatteryLevel > 20 {
            context.setFillColor(MY_GREEN_COLOR.cgColor)
        } else {
            context.setFillColor(MY_RED_COLOR.cgColor)
        }
        context.fill(bounds)
        
        // Drawing complete, retrieve the finished image and cleanup
        let image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        return image!
    }
    
    //---------------- Central Manager Delegates ---------------
    func stopAndInvalidatePeripherals(){
        
        objc_sync_enter(self) //<--- Enter Critical section
        defer { objc_sync_exit(self) }
        
        if toyPeripheral != nil {
            myBLECentralManager.cancelPeripheralConnection(toyPeripheral!)
            toyPeripheral = nil
            toySettings = nil
        }
        
        toyConnectionTimeout?.invalidate()
        toyConnectionTimeout = nil
        toyCheckStatusTimer?.invalidate()
        toyCheckStatusTimer = nil
    } //<---- Leave Critical section
    
    //----------------------------------------------------------
    // Fail to connect to peripheral
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        #if DEBUG
            print ("TODAY ERROR: Did fail to connect to periheral" + String(describing: peripheral.name))
        #endif
    }//<--- Leave Critical section
    
    //----------------------------------------------------------
    // Peripheral connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if peripheral == toyPeripheral{
            toySettings = ToySettings()
            toyStatus = ToyStatus.connected
            peripheral.discoverServices([SETUP_SERVICE_UUID, CONTENT_SERVICE_UUID])
        }
    }
    
    //----------------------------------------------------------
    // Peripheral disconnected
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral) {
        #if DEBUG
            print("TODAY: Peripheral disconnected: " + String (describing: peripheral.name))
        #endif
        
        myBLECentralManager.cancelPeripheralConnection(peripheral)
    }//<--- Leave Critical section
    
    //----------------------------------------------------------
    // Discover services for the Perepheral
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard  error == nil else {
            #if DEBUG
                print("TODAY ERROR: didDiscoverServices ->" + String(error.debugDescription))
            #endif
            return
        }
        
        if toyStatus == ToyStatus.connected {
            for service in peripheral.services! {
                let thisService = service as CBService
                if thisService.uuid == SETUP_SERVICE_UUID{
                    peripheral.discoverCharacteristics([SETUP_VOICE_C, SETUP_STATUS_C], for: thisService)
                }
                if thisService.uuid == CONTENT_SERVICE_UUID{
                    peripheral.discoverCharacteristics([CONT_PLAYFYLE_C, CONT_FILEINFO_C, CONT_SENDFILE_C], for: thisService)
                }
            }
        } else {
            #if DEBUG
                print("TODAY ERROR: didDiscoverServices: entering, while not .connected")
            #endif
        }
    }
    
    //----------------------------------------------------------
    // Discover characteristic for the service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard  error == nil else  {
            #if DEBUG
                print("TODAY ERROR: didDiscoverCharacteristicsForService ->" + String(error.debugDescription))
            #endif
            return
        }
        
        let charactericsArr = service.characteristics!  as [CBCharacteristic]
        
        // ------ Searching for the Toy ---------------------------------------------------
        // ------ Handshake service discovered HS_SERVICE_UUID ----------------------------
        if toyStatus == ToyStatus.connected {
            for charactericsx in charactericsArr
            {
                if service.uuid == SETUP_SERVICE_UUID {
                    if charactericsx.uuid == SETUP_VOICE_C{
                        toySettings?.voiceCharx = charactericsx
                    }
                    if charactericsx.uuid == SETUP_STATUS_C{
                        toySettings?.statusCharx = charactericsx
                        toyPeripheral?.readValue(for: (toySettings?.statusCharx)!)
                        toyPeripheral?.setNotifyValue(true, for: (toySettings?.statusCharx)!)
                    }
                }
                
                if service.uuid == CONTENT_SERVICE_UUID {
                    if charactericsx.uuid == CONT_PLAYFYLE_C{
                        toySettings?.playFileCharx = charactericsx
                    }
                    if charactericsx.uuid == CONT_SENDFILE_C{
                        toySettings?.getFileCharx = charactericsx
                        let dataToWrite = self.encode(lastFilePlayedPos)
                        self.toyPeripheral?.writeValue(dataToWrite, for: (toySettings?.getFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                    }
                    if charactericsx.uuid == CONT_FILEINFO_C{
                        toySettings?.filePlaiedCharx = charactericsx
                        toyPeripheral?.setNotifyValue(true, for: (toySettings?.filePlaiedCharx)!)
                    }
                }
                
            }
        }
    }
    
    //----------------------------------------------------------
    // Characteristic was updated
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard  error == nil else {
            #if DEBUG
                print("TODAY ERROR: didUpdateValueForCharacteristic: ->" + String(error.debugDescription))
            #endif
            return
        }
        
        if toyStatus == ToyStatus.connected {
            if characteristic.uuid == SETUP_STATUS_C {
                guard let data = characteristic.value as NSData?
                    else {return}
                let array = data.u8s
                
                if array.count >= 3 {
                    var toyBatteryLevel: UInt8 = array[0]
                    let toyBatteryStatus: UInt8 = array[1]
                    var toySilentStatus: UInt8 = 0
                    if array.count > 3 {
                        toySilentStatus = array[3]
                    } else {
                        toySilentStatus = array[2]
                    }
                    if toyBatteryLevel > 100 {
                        toyBatteryLevel = 100
                    }
                    toySettings?.batteryLevel = toyBatteryLevel
                    if toyBatteryStatus >= 1 {
                        toySettings?.isCharging = true
                    } else {
                        toySettings?.isCharging = false
                    }
                    if toySilentStatus == 1 {
                        toySettings?.isSilent = true
                    } else {
                        toySettings?.isSilent = false
                    }

                    toyStatusDidChange(batteryLevel: (toySettings?.batteryLevel)!, isCharging: (toySettings?.isCharging)!, isSilent: (toySettings?.isSilent)!)
                    if self.batteryPicture.layer.opacity == 0 {
                        UIView.animate(withDuration: 1) { () -> Void in
                            self.batteryPicture.layer.opacity = 1
                            self.flashPicture.layer.opacity = 1
                        }
                    }
                }
                return
            }
            
            if characteristic.uuid == CONT_FILEINFO_C {
                guard let data = characteristic.value as NSData?
                    else {return}
                
                let buffer16 = data.u16s

                lastFilePlayed = UInt32(buffer16[1]) + UInt32(buffer16[2])<<16
                if lastFilePlayed == 0 {
                    if Int(lastFilePlayedPos) > 0 {
                        lastFilePlayedPos = lastFilePlayedPos - 1
                        let dataToWrite = self.encode(lastFilePlayedPos)
                        self.toyPeripheral?.writeValue(dataToWrite, for: (toySettings?.getFileCharx)!, type: CBCharacteristicWriteType.withResponse)
                    }
                } else {
                    lastFilePlayedPos = 9
                    playButton.isEnabled = true
                    playButton.layer.opacity = 0
                    twitterButton.isEnabled = true
                    twitterButton.layer.opacity = 0
                    fbButton.isEnabled = true
                    fbButton.layer.opacity = 0
                    UIView.animate(withDuration: 1) { () -> Void in
                        self.playActivityIndicator.layer.opacity = 0
                        self.playButton.layer.opacity = 1
                        self.twitterButton.layer.opacity = 1
                        self.fbButton.layer.opacity = 1
                    }
                    self.playActivityIndicator.stopAnimating()
                }
            }
        } else if toyStatus == ToyStatus.upgrading {
            print("Upgrading")
        }
    }
    
    // NSData to struct and back
    //------------------------------------------------------------
    func encode<T> (_ value_: T) -> Data {
        var value = value_
        return withUnsafePointer(to: &value) { p in
            Data(bytes: p, count: MemoryLayout<T>.size)
        }
    }
    
    //------------------------------------------------------------
    func encodeWithMaxLenght<T> (_ value_: T, length: Int) -> Data {
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
    func decode<T>(_ data: Data) -> T {
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: MemoryLayout<T.Type>.size)
        (data as NSData).getBytes(pointer, length: MemoryLayout<T>.size)
        return pointer.move()
    }
}
