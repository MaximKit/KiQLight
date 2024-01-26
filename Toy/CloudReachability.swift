//
//  CloudReachability.swift
//  Toy
//
//  Created by Maxim Kitaygora on 2/18/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import SystemConfiguration

// Connection Changed Notification
public let SNReachabilityNotification = "SNReachabilityNotification"

// Protocol
public protocol SNReachabilityProtocol {
    // check the connection using host name
    static func connectionWithHostName(_ hostName: String) -> InternetConnectionStatus
    // check the connection using IP address name
    static func connectionWithIPAddress(_ address: UnsafePointer<sockaddr>) -> InternetConnectionStatus
    // start listening for the connection notifications
    func startNotifier()
    // stop listening for the connection notifications
    func stopNotifier()
    // current connection status
    var currentConnectionStatus: InternetConnectionStatus { get }
}

// Connection Status
public enum InternetConnectionStatus {
    case notConnected
    case wiFiConnected
    case cellularConnected
    case undefined
}

private func & (lhs: SCNetworkReachabilityFlags, rhs: SCNetworkReachabilityFlags) -> UInt32 { return lhs.rawValue & rhs.rawValue }

/// Net Reachability
public class SNNetReachability: SNReachabilityProtocol {
    
    public static func connectionWithHostName(_ hostName: String) -> InternetConnectionStatus {
        let connection = SNNetReachability(hostname: hostName)
        return connection.currentConnectionStatus
    }
    
    public class func connectionWithIPAddress(_ address: UnsafePointer<sockaddr>) -> InternetConnectionStatus {
        
        let connection = SNNetReachability(ipaddress: address)
        return connection.currentConnectionStatus
    }
    
    private var reachability: SCNetworkReachability?
    
    // Reachability to Host
    public init(hostname: String) {
        
        reachability = SCNetworkReachabilityCreateWithName(nil, hostname)!
    }
    
    // Reachability to IP Address
    public init(ipaddress: UnsafePointer<sockaddr>) {
        
        reachability = SCNetworkReachabilityCreateWithAddress(nil, ipaddress)!
    }
    
    //-----------------------------------------
    deinit {
        stopNotifier()
        if reachability != nil {
            reachability = nil
        }
    }
    
    /// start listening for reachability notifications
    public func startNotifier() {
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        
        SCNetworkReachabilitySetCallback(reachability!, { (_, _, _) in
            NotificationCenter.default.post(name: Notification.Name(rawValue: SNReachabilityNotification), object: nil)
            }, &context)
        
        SCNetworkReachabilityScheduleWithRunLoop(reachability!, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue )
    }
    
    /// stop listening for reachability notifications
    public func stopNotifier() {
        if reachability != nil {
            SCNetworkReachabilityUnscheduleFromRunLoop(reachability!, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
    }
    
    // current connection status
    public var currentConnectionStatus: InternetConnectionStatus {
        
        if reachability == nil {
            return .notConnected
        }
        
        var flags = SCNetworkReachabilityFlags(rawValue: 0)
        SCNetworkReachabilityGetFlags(reachability!, &flags)
        
        return networkStatus(flags)
    }
    
    // current network status
    func networkStatus(_ flags: SCNetworkReachabilityFlags) -> InternetConnectionStatus {
        if (flags & SCNetworkReachabilityFlags.reachable == 0) {
            //The target host is not connected.
            return .notConnected;
        }
        
        var returnValue = InternetConnectionStatus.notConnected;
        if flags & SCNetworkReachabilityFlags.connectionRequired == 0 {
            // If the target host is reachable and no connection is required
            // then we'll assume (for now) that you're on Wi-Fi...
            returnValue = .wiFiConnected
        }
        
        if flags & SCNetworkReachabilityFlags.connectionOnDemand != 0 || flags & SCNetworkReachabilityFlags.connectionOnTraffic != 0 {
            // ... and the connection is on-demand (or on-traffic)
            // if the calling application is using the CFSocketStream or higher APIs...
            if flags & SCNetworkReachabilityFlags.interventionRequired == 0 {
                // ... and no [user] intervention is needed...
                returnValue = .wiFiConnected
            }
        }
        
        if (flags & SCNetworkReachabilityFlags.isWWAN) == SCNetworkReachabilityFlags.isWWAN.rawValue {
            // ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
            returnValue = .cellularConnected
        }
        return returnValue;
    }
}
