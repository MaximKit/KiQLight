//
//  NotificationViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 6/8/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit


//-------------------------------------------------------
class NotificationItem {
    
    // MARK: Properties
    var text: String = ""
    var on: Bool = true
    var bit: Int = 0
    
    // MARK: Initialization
    init?(text: String, on: Bool, bit: Int) {
        // Initialize stored properties.
        self.text = text
        self.on = on
        self.bit = bit
    }
}

//-------------------------------------------------------
class NotificationtItemViewCell: UITableViewCell{
    
    // MARK: Properties
    @IBOutlet weak var TextLabel: UILabel!
    @IBOutlet weak var StatusSwitch: UISwitch!
    
}

//-------------------------------------------------------
class NotificationTableViewController: UITableViewController {
    
    // MARK: Properties
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.reloadData()
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    //-------------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    //-------------------------------------------------------
    @IBAction func settingDidChange(_ sender: AnyObject) {
        let settingSwitch : UISwitch = sender as! UISwitch
        centralController.sessionSettings.toyProfile.notifSettings[Int(settingSwitch.tag / 100)][settingSwitch.tag - (Int(settingSwitch.tag / 100) * 100)].on = settingSwitch.isOn
        centralController.generalSettingDidChange()
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //-------------------------------------------------------
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return centralController.sessionSettings.toyProfile.notifSettings.count
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return centralController.sessionSettings.toyProfile.notifSettings[section].count
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Calls"
        }
        if section == 1 {
            return "Messages"
        }
        return "Other"
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationtItemViewCell", for: indexPath) as! NotificationtItemViewCell
        let settingItem = centralController.sessionSettings.toyProfile.notifSettings[(indexPath as NSIndexPath).section][(indexPath as NSIndexPath).row]
        cell.TextLabel.text = settingItem.text
        cell.StatusSwitch.isOn = settingItem.on
        cell.StatusSwitch.tag = (indexPath as NSIndexPath).row + (indexPath as NSIndexPath).section * 100
        return cell
    }
}

