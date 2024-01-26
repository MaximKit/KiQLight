//
//  MyToyViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 1/21/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit
import Social
import FBSDKCoreKit
import FBSDKShareKit

//------------------------------------
extension UILabel {
    func setFontSize (_ sizeFont: CGFloat) {
        self.font =  UIFont(name: "Comic Neue", size: sizeFont)!
        self.sizeToFit()
    }
}

//------------------------------------
extension UIButton {
    func setFontSize (_ sizeFont: CGFloat) {
        self.titleLabel!.font =  UIFont(name: "Comic Neue", size: sizeFont)
        self.sizeToFit()
    }
}


//------------------------------------
class MyToyViewController: UIViewController, UIScrollViewDelegate {
   
    var playFileTimer: Timer?
    
    //-------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        let screenSize: CGRect = UIScreen.main.bounds
        centralController.myToyViewController = self
        
        switch screenSize.height {
            
        case 480:  //iPhone 4S
            break
        case 568:  //iPhone 5S
            ToyPictureHeigh.constant = 160
            ToyViewBottomPosition.constant = -95
            ConnectAnotherButton.setFontSize(17)
            CentralMessageLabel.setFontSize(18)
            break
        default:
            ToyViewBottomPosition.constant = -120
            ToyPictureHeigh.constant = 220
            ConnectAnotherButton.setFontSize(20)
            CentralMessageLabel.setFontSize(20)
            break
        }
        
        FacebookBtnConstraint.constant = screenSize.width / 4
        TwitterBtnConstraint.constant = screenSize.width / 4
        ConnectAnotherButton.layer.cornerRadius = 10

        resetMainScreen()
        UITabBar.appearance().tintColor = MY_PINK_COLOR
    }
    
    
    //-----------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tabBarController?.navigationItem.title="My KiQ"
        
        if centralController.expectedToyID == "" {
            ConnectAnotherButton.setTitle("     Connect My KiQ      ", for: UIControlState.normal)
        } else {
            ConnectAnotherButton.setTitle("   Connect another KiQ   ", for: UIControlState.normal)
        }
        
        if centralController.toyStatus == ToyStatus.searching{
            bleDidChange(isWorking: true)
            if centralController.expectedToyID != "" && centralController.cloundService.isCloudSessionEnabled() == true{
                self.ConnectAnotherButton.isHidden = false
            }
        } else if centralController.toyStatus == ToyStatus.disconnected {
            upgradeDidChange(false, progress: 0)
        }
        
        if centralController.isSilent() == 1 || centralController.isSilent() == 2 {
                CatPicture.image = UIImage(named: "BigCatSilent")
        } else {
                CatPicture.image = UIImage(named: "BigCat")
        }
        
    }
    
    //-----------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    //-----------------------------------------
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    //--------------------------------------------------------
    // MARK: Outlets
    @IBOutlet var CentralMessageLabel: UILabel!
    @IBOutlet var PlayButton: UIButton!
    @IBOutlet var TwitterShareButton: UIButton!
    @IBOutlet var CatPicture: UIImageView!
    @IBOutlet weak var CatNoPowerPicture: UIImageView!
    @IBOutlet weak var CatOnBackPicture: UIImageView!
    @IBOutlet var ToyMessageHeigh: NSLayoutConstraint!
    @IBOutlet var ToyPictureHeigh: NSLayoutConstraint!
    @IBOutlet var ToyViewBottomPosition: NSLayoutConstraint!
    @IBOutlet var FetchingDataIndicator: UIActivityIndicatorView!
    @IBOutlet var FacebookBtnConstraint: NSLayoutConstraint!
    @IBOutlet var TwitterBtnConstraint: NSLayoutConstraint!
    @IBOutlet var FacebookShareButton: UIButton!
    @IBOutlet weak var ConnectAnotherButton: UIButton!
    @IBOutlet weak var BatteryView: UIImageView!
    @IBOutlet weak var batteryViewWidth: NSLayoutConstraint!
    @IBOutlet weak var batteryViewAspect: NSLayoutConstraint!
    @IBOutlet weak var FlashPicture: UIImageView!
    @IBOutlet weak var UpgradeProgressIndicator: UIProgressView!
    @IBOutlet weak var ConnectedWiFi: UILabel!
    @IBOutlet weak var JokeScrollViewController: UIScrollView!
    @IBOutlet weak var JokeScrollViewHeigh: NSLayoutConstraint!

    //--------------------------------------------------------
    // MARK: Outlets Actions
    //--------------------------------------------------------
    @IBAction func connectAnotherTapped(_ sender: AnyObject) {
        if centralController.toyStatus == ToyStatus.disconnected {
            centralController.toyStatus = ToyStatus.searching
        } else if centralController.toyStatus == ToyStatus.searching{
            centralController.toyStatus = ToyStatus.disconnected
            centralController.expectedToyID = ""
            centralController.toyStatus = ToyStatus.searching
        }
    }
    
    //--------------------------------------------------------
    @IBAction func playButtonTapped(_ sender: AnyObject) {
        let jokeNumber : Int = Int(JokeScrollViewController.contentOffset.x / UIScreen.main.bounds.width)
        if recents.count < (jokeNumber + 1) {
            return
        }
        if !recents.isEmpty {
            let silentStatus = centralController.isSilent()
            if silentStatus == 0 {
                centralController.playFile(recents[jokeNumber])
                self.playFileTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(playFileTimeout), userInfo: nil, repeats: false)
                PlayButton.isEnabled = false
            } else if silentStatus == 1 {
                displayMyAlertMessage("The Sound Volume was set to its minimum position. Please increase Sound Volume to play the joke.")
            } else {
                displayPlayChoiceMessage(silentStatus)
            }
        }
    }
        //--------------------------------------------------------
    @IBAction func shareOnTwitter(_ sender: AnyObject) {
        let jokeNumber : Int = Int(JokeScrollViewController.contentOffset.x / UIScreen.main.bounds.width)
        if recents.count < (jokeNumber + 1) {
            return
        }
        if recents[jokeNumber].fileURL.isEmpty == false {
            postOnTwitter(recents[jokeNumber].text)
        } else {
            displayMyAlertMessage("Sorry. We can not share this joke on Twitter :(")
        }
    }
    //--------------------------------------------------------
    @IBAction func shareOnFacebook(_ sender: AnyObject) {
        let jokeNumber : Int = Int(JokeScrollViewController.contentOffset.x / UIScreen.main.bounds.width)
        if recents.count < (jokeNumber + 1) {
            return
        }
        if recents[jokeNumber].fileURL.isEmpty == false {
            postOnFacebook(recents[jokeNumber].fileURL, text: recents[jokeNumber].text)
        } else {
            displayMyAlertMessage("Sorry. We can not share this joke on Facebook :(")
        }
    }
    
    // Joke Scroll View delegates
    //-----------------------------------------
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let jokeNumber : Int = Int(scrollView.contentOffset.x / UIScreen.main.bounds.width)
        if recents.count < (jokeNumber + 1) {
            return
        }
        if recents[jokeNumber].fileURL.isEmpty == false {
            self.TwitterShareButton.isHidden = false
            self.FacebookShareButton.isHidden = false
        }
    }
    
    //--------------------------------------------------------
    // MARK: Functions
    //--------------------------------------------------------
    
    //--------------------------------------------------------
    func cloudDidChange(_ inProgress: Bool){
        CentralMessageLabel.text = centralController.upperStatusLabel + "\n\n" + centralController.lowerStatusLabel
        if inProgress == true {
            //FetchingDataIndicator.startAnimating()
        } else {
            TwitterShareButton.isHidden = true
            FacebookShareButton.isHidden = true
        }
    }
    
    //--------------------------------------------------------
    func upgradeDidChange(_ inProgress: Bool, progress: Float){
        DispatchQueue.main.async{
            self.resetMainScreen()
            self.CentralMessageLabel.text = centralController.upperStatusLabel + "\n\n" + centralController.lowerStatusLabel
            if inProgress == true {
                self.ConnectedWiFi.isHidden = false
                if progress != 0 {
                    self.UpgradeProgressIndicator.progress = progress
                    self.UpgradeProgressIndicator.isHidden = false
                    self.FetchingDataIndicator.stopAnimating()
                } else {
                    self.UpgradeProgressIndicator.isHidden = true
                    self.FetchingDataIndicator.startAnimating()
                }
            } else {
                self.ConnectedWiFi.isHidden = true
                self.UpgradeProgressIndicator.isHidden = true
                self.UpgradeProgressIndicator.progress = 0
                self.FetchingDataIndicator.stopAnimating()
            }
        }
    }

    //--------------------------------------------------------
    func lastPlayedDidChange(){
        DispatchQueue.main.async{
            objc_sync_enter(recents) // Lock recent files
            defer { objc_sync_exit(recents) }

            for view in self.JokeScrollViewController.subviews {
                view.removeFromSuperview()
            }
            if recents.count == 0{
                return
            }
            for i in 0 ... (recents.count - 1){
                let vc = JokeViewController(nibName: "JokeViewController", bundle: nil)
                vc.view.frame.origin.x = UIScreen.main.bounds.width * CGFloat(i)
                vc.view.frame.size.width = UIScreen.main.bounds.width
                switch UIScreen.main.bounds.height {
                    
                case 480:  //iPhone 4S
                    break
                case 568:  //iPhone 5S
                    vc.jokeLabel.setFontSize(18)
                    self.JokeScrollViewHeigh.constant = 130
                    vc.jokeLabelHeigh.constant = self.JokeScrollViewController.bounds.height - 30
                    break
                default:
                    vc.jokeLabel.setFontSize(20)
                    vc.jokeLabelHeigh.constant = self.JokeScrollViewController.bounds.height - 20
                    break
                }
                
                vc.jokeLabel.text = "\"" + recents[i].text + "\""
                vc.jokeCounterLabel.text? = String(i + 1) + " of " + String(recents.count)
                self.addChildViewController(vc)
                self.JokeScrollViewController.addSubview(vc.view)
                vc.didMove(toParentViewController: self)
            }
            
            self.JokeScrollViewController.contentSize.width = (UIScreen.main.bounds.width) * CGFloat(recents.count)
            self.JokeScrollViewController.delegate = self
            self.JokeScrollViewController.contentOffset.x = 0
            
            if recents[0].fileURL.isEmpty == false {
                self.TwitterShareButton.isHidden = false
                self.FacebookShareButton.isHidden = false
            }
            self.PlayButton.isHidden = false
            self.JokeScrollViewController.isHidden = false
            self.FetchingDataIndicator.stopAnimating()
            
            let isActionRequired = UserDefaults.standard.object(forKey: "launchedFor") as! String?
            
            if isActionRequired == "twitter" {
                self.postOnTwitter(recents[0].text)
            }
            
            if isActionRequired == "fb" {
                self.postOnFacebook(recents[0].fileURL, text: recents[0].text)
            }
            UserDefaults.standard.set("main", forKey: "launchedFor")
            UserDefaults.standard.synchronize();
        }
    }
    
    //--------------------------------------------------------
    func toyStatusDidChange(batteryLevel: UInt8, isCharging: Bool, isSilent: Bool){
        var imageSize = BatteryView.image?.size
        var toyBatteryLevel: UInt8 = 1
        BatteryView.isHidden = false
        toyBatteryLevel = batteryLevel
        if imageSize != nil {
            
            if toyBatteryLevel <= 20 && isCharging == false{
                CatPicture.isHidden = true
                CatOnBackPicture.isHidden = true
                CatNoPowerPicture.isHidden = false
            } else {
                CatOnBackPicture.isHidden = !isSilent
                CatPicture.isHidden = isSilent
                CatNoPowerPicture.isHidden = true
            }
            FlashPicture.isHidden = !isCharging

            imageSize?.width = (batteryViewWidth.constant - 4) * CGFloat(toyBatteryLevel)/100
            imageSize?.height = batteryViewWidth.constant / batteryViewAspect.multiplier - 2
            
            let lastView = BatteryView.subviews.last
            lastView?.removeFromSuperview()
            let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 1, y: 1), size: imageSize!))
            BatteryView.addSubview(imageView)
            imageView.layer.cornerRadius = 2
            imageView.layer.masksToBounds = true
            guard let image = drawCustomImage(imageSize!, toyBatteryLevel: toyBatteryLevel)
                else {return}
            imageView.image = image
        }
    }
    
    //--------------------------------------------------------
    func resetInProgress(){
        DispatchQueue.main.async{
            self.resetMainScreen()
            self.CentralMessageLabel.text = centralController.upperStatusLabel + "\n\n" + centralController.lowerStatusLabel
            self.FetchingDataIndicator.startAnimating()
        }
    }
    
    //--------------------------------------------------------
    func bleDidChange(isWorking: Bool){
        DispatchQueue.main.async{
            if isWorking == true {
                self.FetchingDataIndicator.startAnimating()
            } else {
                self.resetMainScreen()
            }
            self.CentralMessageLabel.text = centralController.upperStatusLabel + "\n\n" + centralController.lowerStatusLabel
        }
    }
        
    //--------------------------------------------------------
    func resetMainScreen(){
        UpgradeProgressIndicator.isHidden = true
        ConnectedWiFi.isHidden = true
        CentralMessageLabel.text = ""
        PlayButton.isHidden = true
        TwitterShareButton.isHidden = true
        FacebookShareButton.isHidden = true
        FlashPicture.isHidden = true
        BatteryView.isHidden = true
        CatPicture.isHidden = false
        CatNoPowerPicture.isHidden = true
        CatOnBackPicture.isHidden = true
        JokeScrollViewController.isHidden = true
        FetchingDataIndicator.stopAnimating()
        objc_sync_enter(recents) // Lock recent files
        defer { objc_sync_exit(recents) }
        for view in self.JokeScrollViewController.subviews {
            view.removeFromSuperview()
        }
    }
    
    // MARK: SocialFunctions
    // ----- Twitter --------------------------------
    func postOnTwitter(_ text: String)
    {
        if SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter){
            let twitterController:SLComposeViewController = SLComposeViewController(forServiceType: SLServiceTypeTwitter)
            let preparedText = prepareForTwitter(text)
            twitterController.setInitialText("#KiqToy: " + preparedText)
            twitterController.view.tintColor = UIColor(red: 137/255, green: 29/255, blue: 36/255, alpha: 1)
            self.present(twitterController, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "Twitter Account", message: "Please login to your Twitter account.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            alert.view.tintColor = UIColor(red: 137/255, green: 29/255, blue: 36/255, alpha: 1)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    // ----- Facebook --------------------------------
    func postOnFacebook(_ url: String, text: String)
    {
        let content : FBSDKShareLinkContent = FBSDKShareLinkContent()
        content.contentURL = URL(string: url)
        content.setValue(title, forKeyPath: "Joke from my KiqToy")
        content.setValue(description, forKeyPath: "Joke from my KiqToy")
        FBSDKShareDialog.show(from: self, with: content, delegate: nil)
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
    
    //----------------------------------------------------
    func displayMyAlertMessage(_ userMessage:String)
    {
        if isModal() == true {
            let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
            let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil);
            myAlert.addAction(okAction);
            self.present(myAlert , animated: true, completion: nil)
        }
    }
    
    //----------------------------------------------------
    func displayConnectionChoiceMessage()
    {
        let myAlert = UIAlertController(title: "KiQ is not yet connected", message: "Would you like to connect your KiQ?", preferredStyle: UIAlertControllerStyle.actionSheet);
        
        myAlert.view.tintColor = UIColor(red: 137/255, green: 29/255, blue: 36/255, alpha: 1)
        let playAction = UIAlertAction(title: "Connect my KiQ", style: UIAlertActionStyle.default) { action -> Void in
            centralController.processUserResponseForConnectionChoise(shouldConnect: true)
        }
        myAlert.addAction(playAction);

        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Stay offline", style: UIAlertActionStyle.default) { action -> Void in
            centralController.processUserResponseForConnectionChoise(shouldConnect: false)
        }
        myAlert.addAction(cancelAction)
        
        self.present(myAlert , animated: true, completion: nil)
    }

    
    
     //----------------------------------------------------
     func isModal() -> Bool {
         if self.presentingViewController != nil {
            return true
         }
         
         if self.presentingViewController?.presentedViewController == self {
            return true
         }
         
         if self.navigationController?.presentingViewController?.presentedViewController == self.navigationController  {
            return true
         }
         
         if self.tabBarController?.presentingViewController is UITabBarController {
            return true
         }
         
         return false
     }
    
    //------------ Timer Callbacks -----------------------------
    //----------------------------------------------------------
    @objc func playFileTimeout () {
        playFileTimer?.invalidate()
        PlayButton.isEnabled = true
    }
    //----------------------------------------------------
    func displayPlayChoiceMessage(_ id: Int)
    {
        var title = "Your KiQ is in Do Not Disturb mode"
        if id == 3 {
            title = "Your KiQ is in Silent mode"
        }
        let myAlert = UIAlertController(title: title, message: "Do you really want to play this joke?", preferredStyle: UIAlertControllerStyle.actionSheet);
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        myAlert.addAction(cancelAction)
        
        myAlert.view.tintColor = UIColor(red: 137/255, green: 29/255, blue: 36/255, alpha: 1)
        let playAction = UIAlertAction(title: "Play", style: UIAlertActionStyle.default) { action -> Void in
            let jokeNumber : Int = Int(self.JokeScrollViewController.contentOffset.x / UIScreen.main.bounds.width)
            if recents.count < (jokeNumber + 1) {
                return
            }
            centralController.playFile(recents[jokeNumber])
            self.playFileTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.playFileTimeout), userInfo: nil, repeats: false)
            self.PlayButton.isEnabled = false
        }
        myAlert.addAction(playAction);
        
        self.present(myAlert , animated: true, completion: nil)
    }
    
}

//----------------------------------------------------
//Twitter shortener
func prepareForTwitter(_ text: String) -> String{
    
    var result : String = text
    let dict : Dictionary = [
        "@": "at",
        "you": "u",
        "You": "U",
        "be": "b",
        "Be": "B",
        "Because": "Coz",
        "because": "coz",
        "see": "c",
        "See": "C",
        "favorite": "fav",
        "Favorite": "Fav",
        "problem": "prob",
        "Problem": "Prob",
        "The": "Da",
        "the": "da",
        "Does": "Duz",
        "does": "duz",
        "And": "&",
        "and": "&",
        "One": "1",
        "one": "1",
        "To": "2",
        "to": "2",
        "Two": "2",
        "two": "2",
        "Three": "3",
        "three": "3",
        "for": "4",
        "For": "4",
        "four": "4",
        "Four": "4",
        "forever": "4rever",
        "Forever": "4rever",
        "Five": "5",
        "five": "5",
        "Six": "6",
        "six": "6",
        "Seven": "7",
        "seven": "7",
        "Eight": "8",
        "eight": "8",
        "nine": "9",
        "Nine": "9",
        "What": "wat",
        "what": "wat",
        "When": "Wn",
        "when": "wn",
        "Why": "Y",
        "why": "y",
        "Love": "Luv",
        "love": "luv",
        "Facebook": "FB",
        "Forward": "Fwd",
        "forward": "fwd",
        "Before": "B4re",
        "before": "b4re"
    ]
    for (source, destination) in dict {
        result = result.replacingOccurrences(of: source + " ", with: destination + " ")
        result = result.replacingOccurrences(of: " " + source, with: " " + destination)
        if result.count < 132 {
            return result
        }
    }
    return result
}

//-----------------------------------------------------------------------
// View controller to show last played jokes
class JokeViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBOutlet weak var jokeLabel: UILabel!
    @IBOutlet weak var jokeLabelHeigh: NSLayoutConstraint!
    @IBOutlet weak var jokeCounterLabel: UILabel!
    
    
}

