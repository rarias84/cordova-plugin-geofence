//
//  GeofencePlugin.swift
//  ionic-geofence
//
//  Created by tomasz on 07/10/14.
//
//

import Foundation
import AudioToolbox

let TAG = "GeofencePlugin"
let iOS8 = floor(NSFoundationVersionNumber) > floor(NSFoundationVersionNumber_iOS_7_1)
let iOS7 = floor(NSFoundationVersionNumber) <= floor(NSFoundationVersionNumber_iOS_7_1)

func log(_ message: String){
    NSLog("%@ - %@", TAG, message)
}

@available(iOS 8.0, *)
@objc(HWPGeofencePlugin) class GeofencePlugin : CDVPlugin {
    lazy var geoNotificationManager = GeoNotificationManager()
    let priority = DispatchQueue.GlobalQueuePriority.default
    
    override func pluginInitialize () {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(GeofencePlugin.didReceiveLocalNotification(_:)),
            name: NSNotification.Name(rawValue: "CDVLocalNotificationGeofence"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(GeofencePlugin.didReceiveTransition(_:)),
            name: NSNotification.Name(rawValue: "handleTransition"),
            object: nil
        )
    }
    
    func initialize(_ command: CDVInvokedUrlCommand) {
        log("Plugin initialization")
        //let faker = GeofenceFaker(manager: geoNotificationManager)
        //faker.start()
        
        if iOS8 {
            promptForNotificationPermission()
        }
        
        geoNotificationManager = GeoNotificationManager()
        geoNotificationManager.registerPermissions()
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    
    func deviceReady(_ command: CDVInvokedUrlCommand) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    
    func ping(_ command: CDVInvokedUrlCommand) {
        log("Ping")
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
        commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    
    func promptForNotificationPermission() {
        UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(
            types: [UIUserNotificationType.sound, UIUserNotificationType.alert, UIUserNotificationType.badge],
            categories: nil
            )
        )
    }
    
    func addOrUpdate(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            // do some task
            for geo in command.arguments {
                self.geoNotificationManager.addOrUpdateGeoNotification(JSON(geo))
            }
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }
    
    func getWatched(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            let watched = self.geoNotificationManager.getWatchedGeoNotifications()!
            let watchedJsonString = watched.description
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: watchedJsonString)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }
    
    func remove(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            for id in command.arguments {
                self.geoNotificationManager.removeGeoNotification(id as! String)
            }
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }
    
    func removeAll(_ command: CDVInvokedUrlCommand) {
        DispatchQueue.global(priority: priority).async {
            self.geoNotificationManager.removeAllGeoNotifications()
            DispatchQueue.main.async {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }
    
    func didReceiveTransition (_ notification: Notification) {
        log("didReceiveTransition")
        if let geoNotificationString = notification.object as? String {
            
            let js = "setTimeout(geofence.onTransitionReceived([" + geoNotificationString + "]),0)"
            
            evaluateJs(js)
        }
    }
    
    func didReceiveLocalNotification (_ notification: Notification) {
        log("didReceiveLocalNotification")
        if UIApplication.shared.applicationState != UIApplicationState.active {
            //var data = "undefined"
            if let uiNotification = notification.object as? UILocalNotification {
                if let notificationData = uiNotification.userInfo?["geofence.notification.data"] as? String {
                    let data = notificationData
                    let js = "setTimeout(geofence.onTransitionReceived([" + data + "]),0)"
                    
                    evaluateJs(js)
                }
            }
        }
    }
    
    func evaluateJs (_ script: String) {
        if webView is UIWebView {
            if let uiWebView = webView as? UIWebView {
                uiWebView.stringByEvaluatingJavaScript(from: script)
            }
            else{
                log("webView is not available")
            }
        }
        else{
            if webViewEngine != nil {
                webViewEngine!.evaluateJavaScript(script, completionHandler: nil)
            } else {
                log("webViewEngine is null")
            }
        }
    }
}

// class for faking crossing geofences
@available(iOS 8.0, *)
class GeofenceFaker {
    let priority = DispatchQueue.GlobalQueuePriority.default
    let geoNotificationManager: GeoNotificationManager
    
    init(manager: GeoNotificationManager) {
        geoNotificationManager = manager
    }
    
    func start() {
        DispatchQueue.global(priority: priority).async {
            while (true) {
                log("FAKER")
                let notify = arc4random_uniform(4)
                if notify == 0 {
                    log("FAKER notify chosen, need to pick up some region")
                    var geos = self.geoNotificationManager.getWatchedGeoNotifications()!
                    if geos.count > 0 {
                        //WTF Swift??
                        let index = arc4random_uniform(UInt32(geos.count))
                        let geo = geos[Int(index)]
                        let id = geo["id"].stringValue
                        DispatchQueue.main.async {
                            if let region = self.geoNotificationManager.getMonitoredRegion(id) {
                                log("FAKER Trigger didEnterRegion")
                                self.geoNotificationManager.locationManager(
                                    self.geoNotificationManager.locationManager,
                                    didEnterRegion: region
                                )
                            }
                        }
                    }
                }
                Thread.sleep(forTimeInterval: 3)
            }
        }
    }
    
    func stop() {
        
    }
}

@available(iOS 8.0, *)
class GeoNotificationManager : NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    let store = GeoNotificationStore()
    
    override init() {
        log("GeoNotificationManager init")
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        if (!CLLocationManager.locationServicesEnabled()) {
            log("Location services is not enabled")
        } else {
            log("Location services enabled")
        }
        
        if (!CLLocationManager.isMonitoringAvailable(for: CLRegion.self)) {
            log("Geofencing not available")
        }
    }
    
    func registerPermissions() {
        if iOS8 {
            locationManager.requestAlwaysAuthorization()
        } else if (iOS7) {
            log("ERRORR")
        }
    }
    
    func addOrUpdateGeoNotification(_ geoNotification: JSON) {
        log("GeoNotificationManager addOrUpdate")
        
        checkRequirements()
        
        let location = CLLocationCoordinate2DMake(
            geoNotification["latitude"].doubleValue,
            geoNotification["longitude"].doubleValue
        )
        log("AddOrUpdate geo: \(geoNotification)")
        let radius = geoNotification["radius"].doubleValue as CLLocationDistance
        //let uuid = NSUUID().UUIDString
        let id = geoNotification["id"].stringValue
        
        let region = CLCircularRegion(center: location, radius: radius, identifier: id)
        
        var transitionType = 0
        if let i = geoNotification["transitionType"].int {
            transitionType = i
        }
        region.notifyOnEntry = 0 != transitionType & 1
        region.notifyOnExit = 0 != transitionType & 2
        
        //store
        store.addOrUpdate(geoNotification)
        locationManager.startMonitoring(for: region)
    }
    
    func checkRequirements() {
        if (!CLLocationManager.locationServicesEnabled()) {
            log("Warning: Locationservices is not enabled")
        }
        
        let authStatus = CLLocationManager.authorizationStatus()
        
        if (authStatus != CLAuthorizationStatus.authorizedAlways) {
            log("Warning: Location always permissions not granted, have you initialized geofence plugin?")
        }
        
        if let notificationSettings = UIApplication.shared.currentUserNotificationSettings {
            if !notificationSettings.types.contains(.sound) {
                log("Warning: notification settings - sound permission missing")
            }
            
            if !notificationSettings.types.contains(.alert) {
                log("Warning: notification settings - alert permission missing")
            }
            
            if !notificationSettings.types.contains(.badge) {
                log("Warning: notification settings - badge permission missing")
            }
        } else {
            log("Warning: notification permission missing")
        }
    }
    
    func getWatchedGeoNotifications() -> [JSON]? {
        return store.getAll()
    }
    
    func getMonitoredRegion(_ id: String) -> CLRegion? {
        for object in locationManager.monitoredRegions {
            let region = object
            
            if (region.identifier == id) {
                return region
            }
        }
        return nil
    }
    
    func removeGeoNotification(_ id: String) {
        store.remove(id)
        let region = getMonitoredRegion(id)
        if (region != nil) {
            log("Stoping monitoring region \(id)")
            locationManager.stopMonitoring(for: region!)
        }
    }
    
    func removeAllGeoNotifications() {
        store.clear()
        for object in locationManager.monitoredRegions {
            let region = object
            log("Stoping monitoring region \(region.identifier)")
            locationManager.stopMonitoring(for: region)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        log("update location")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log("fail with error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        log("deferred fail error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        log("Entering region \(region.identifier)")
        handleTransition(region, transitionType: 1)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        log("Exiting region \(region.identifier)")
        handleTransition(region, transitionType: 2)
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if region is CLCircularRegion {
            let lat = (region as! CLCircularRegion).center.latitude
            let lng = (region as! CLCircularRegion).center.longitude
            let radius = (region as! CLCircularRegion).radius
            
            log("Starting monitoring for region \(region) lat \(lat) lng \(lng) of radius \(radius)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        log("State for region " + region.identifier)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        log("Monitoring region " + region!.identifier + " failed " + error.localizedDescription)
    }

    func callService(){
         //Aquí llamar a servicio. Primero en duro, después programable.
         let url : String = "http://dev.adderou.cl/transanpbl/busdata.php?paradero=PC903"
         //var request : NSMutableURLRequest = NSMutableURLRequest()
         let requestURL = URL(string:"\(url)")!
         let request = NSMutableURLRequest(url: requestURL)
         request.httpMethod = "GET"
         request.addValue("application/json", forHTTPHeaderField: "Content-Type")
         request.addValue("application/json", forHTTPHeaderField: "Accept")
         
//         let session = URLSession.shared
        
         let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: {data, response, error -> Void in
             print("Response: \(response)")
             if response == nil {
                 return
             }
             let httpResponse = response as! HTTPURLResponse
             let statusCode = httpResponse.statusCode
             print(statusCode)
             
             if (statusCode == 200) {
                 do{
                     let json = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.allowFragments) as! [String:AnyObject]
                     print(json)
                 }catch {
                     print("Error with Json: \(error)")
                 }
             }
             
         })
         task.resume()
    }
    
    func handleTransition(_ region: CLRegion!, transitionType: Int) {
        //callService()
        if region is CLCircularRegion {
            if var geoNotification = store.findById(region.identifier) {
                geoNotification["transitionType"].int = transitionType
                let appState : UIApplicationState = UIApplication.shared.applicationState;
                if (appState == UIApplicationState.background  || appState == UIApplicationState.inactive)
                {
                    geoNotification["openedFromNotification"].bool = true
                } else {
                    geoNotification["openedFromNotification"].bool = false
                }
                
                if (appState == UIApplicationState.active)
                {
                    let geoNotificationStr = geoNotification.rawString(String.Encoding.utf8, options: [])
                    let dispatchEvent = GeofenceHelper.validateTimeInterval(with: geoNotificationStr)

                    if geoNotification["notification"].exists() {
                        if(dispatchEvent) {
                            notifyAbout(geoNotification)
                        }
                    }
                    
                    if(dispatchEvent) {
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "handleTransition"), object: geoNotification.rawString(String.Encoding.utf8, options: []))
                    }
                }
            }
        }
    }

    func notifyAbout(_ geo: JSON) {
        /*let appState : UIApplicationState = UIApplication.sharedApplication().applicationState;
         if (appState == UIApplicationState.Background  || appState == UIApplicationState.Inactive)
         {
         log("Creating notification")
         let notification = UILocalNotification()
         notification.timeZone = NSTimeZone.defaultTimeZone()
         let dateTime = NSDate()
         notification.fireDate = dateTime
         notification.soundName = UILocalNotificationDefaultSoundName
         //notification.alertTitle = geo["notification"]["title"].stringValue
         notification.alertBody = geo["notification"]["text"].stringValue
         if let json = geo["notification"]["data"] as JSON? {
         //notification.userInfo = ["geofence.notification.data": json.rawString(NSUTF8StringEncoding, options: [])!]
         notification.userInfo = ["geofence.notification.data": json.rawString(NSUTF8StringEncoding, options: [])!, "DeepLinkURLKey": json.rawString(NSUTF8StringEncoding, options: [])!]
         }
         UIApplication.sharedApplication().scheduleLocalNotification(notification)
         
         if let vibrate = geo["notification"]["vibrate"].array {
         if (!vibrate.isEmpty && vibrate[0].intValue > 0) {
         AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
         }
         }
         } */
    }
}

@objc class WrapperStore : NSObject {
    
    let store = GeoNotificationStore()
    
    @objc func getGeofencingById(_ id: String) -> String {
        store.createDBStructure();
        return store.findByIdStr(id)!
    }
    
    @objc func updateDB(_ geoNotification: String) {
        store.createDBStructure();
        
        let jsonGeoNotification = JSON(data: geoNotification.data(using: String.Encoding.utf8)!)
        
        store.update(jsonGeoNotification)
    }
}

class GeoNotificationStore{
    
    init() {
        createDBStructure()
    }
    
    func createDBStructure() {
        let (tables, err) = SD.existingTables()
        
        if (err != nil) {
            log("Cannot fetch sqlite tables: \(err)")
            return
        }
        
        if (tables.filter { $0 == "GeoNotifications" }.count == 0) {
            if let err = SD.executeChange("CREATE TABLE GeoNotifications (ID TEXT PRIMARY KEY, Data TEXT)") {
                //there was an error during this function, handle it here
                log("Error while creating GeoNotifications table: \(err)")
            } else {
                //no error, the table was created successfully
                log("GeoNotifications table was created successfully")
            }
        }
        
    }
    
    func addOrUpdate(_ geoNotification: JSON) {
        if (findById(geoNotification["id"].stringValue) != nil) {
            update(geoNotification)
        }
        else {
            add(geoNotification)
        }
    }
    
    func add(_ geoNotification: JSON) {
        let id = geoNotification["id"].stringValue
        let err = SD.executeChange("INSERT INTO GeoNotifications (Id, Data) VALUES(?, ?)",
                                   withArgs: [id as AnyObject, geoNotification.description as AnyObject])
        
        if err != nil {
            log("Error while adding \(id) GeoNotification: \(err)")
        }
    }
    
    func update(_ geoNotification: JSON) {
        let id = geoNotification["id"].stringValue
        let err = SD.executeChange("UPDATE GeoNotifications SET Data = ? WHERE Id = ?",
                                   withArgs: [geoNotification.description as AnyObject, id as AnyObject])
        
        if err != nil {
            log("Error while adding \(id) GeoNotification: \(err)")
        }
    }
    
    func findById(_ id: String) -> JSON? {
        let (resultSet, err) = SD.executeQuery("SELECT * FROM GeoNotifications WHERE Id = ?", withArgs: [id as AnyObject])
        
        if err != nil {
            //there was an error during the query, handle it here
            log("Error while fetching \(id) GeoNotification table: \(err)")
            return nil
        } else {
            if (resultSet.count > 0) {
                let jsonString = resultSet[0]["Data"]!.asString()!
                return JSON(data: jsonString.data(using: String.Encoding.utf8)!)
            }
            else {
                return nil
            }
        }
    }
    func findByIdStr(_ id: String) -> String? {
        let (resultSet, err) = SD.executeQuery("SELECT * FROM GeoNotifications WHERE Id = ?", withArgs: [id as AnyObject])
        
        if err != nil {
            //there was an error during the query, handle it here
            log("Error while fetching \(id) GeoNotification table: \(err)")
            return nil
        } else {
            if (resultSet.count > 0) {
                let jsonString = resultSet[0]["Data"]!.asString()!
                let jason = JSON(data: jsonString.data(using: String.Encoding.utf8)!)
                return jason.rawString(String.Encoding(rawValue: String.Encoding.utf8.rawValue), options: [])
                
            }
            else {
                return nil
            }
        }
    }
    
    func getAll() -> [JSON]? {
        let (resultSet, err) = SD.executeQuery("SELECT * FROM GeoNotifications")
        
        if err != nil {
            //there was an error during the query, handle it here
            log("Error while fetching from GeoNotifications table: \(err)")
            return nil
        } else {
            var results = [JSON]()
            for row in resultSet {
                if let data = row["Data"]?.asString() {
                    results.append(JSON(data: data.data(using: String.Encoding.utf8)!))
                }
            }
            return results
        }
    }
    
    func remove(_ id: String) {
        let err = SD.executeChange("DELETE FROM GeoNotifications WHERE Id = ?", withArgs: [id as AnyObject])
        
        if err != nil {
            log("Error while removing \(id) GeoNotification: \(err)")
        }
    }
    
    func clear() {
        let err = SD.executeChange("DELETE FROM GeoNotifications")
        
        if err != nil {
            log("Error while deleting all from GeoNotifications: \(err)")
        }
    }
}
