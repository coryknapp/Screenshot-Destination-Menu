//
//  AppDelegate.swift
//  Screenshot-Destination-Menu
//
//  Created by Cory Knapp on 7/22/16.
//  Copyright © 2016 Cory Knapp. All rights reserved.
//

import Cocoa

extension String {
    /// Removes a single trailing newline if the string has one.
    func chomp() -> String {
        if self.hasSuffix("\n") {
            return self[self.startIndex..<self.endIndex.predecessor()]
        } else {
            return self
        }
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSOpenSavePanelDelegate {
    
    @IBOutlet weak var screenShotMenu: NSMenu!
    @IBOutlet weak var addMenuItem: NSMenuItem!
    @IBOutlet weak var deleteMenuItem: NSMenuItem!
    @IBOutlet weak var separatorMenuItem: NSMenuItem!
    @IBOutlet weak var quitMenuItem: NSMenuItem!
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(-1)
    
    var pathList = [NSURL]()
    var menuToURLs = [NSMenuItem: NSURL]()
    var deleteMenuToURLs = [NSMenuItem: NSURL]()
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let icon = NSImage(named: "statusIcon")
        icon?.template = true
        self.getScreenShotDirectory()
        statusItem.image = icon
        statusItem.menu = screenShotMenu
        
        deleteMenuItem.submenu?.removeAllItems()
        
        // set default settings
        NSUserDefaults.standardUserDefaults().registerDefaults(["pathsKey":
            [NSURL(fileURLWithPath: NSHomeDirectory()+"/Desktop").path!,
                NSURL(fileURLWithPath: NSHomeDirectory()+"/Documents").path!,
                NSURL(fileURLWithPath: NSHomeDirectory()+"/Pictures").path!]]) //this doesn't seem like the cononical way to get at the ~/Pictures folder, so any suggestions would be aprituated.
        
        self.readPaths()
        self.rebuildMenu()
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        self.savePaths()
    }
    
    func setScreenShotDirectory(file: NSURL) {
        let task = NSTask()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", "com.apple.screencapture", "location", file.path!]
        task.launch()
    }
    
    func getScreenShotDirectory() -> NSURL {
        let task = NSTask()
        let stdout = NSPipe()
        let errout = NSPipe()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.screencapture", "location"]
        task.standardOutput = stdout
        task.standardError = errout //if the default setting doesn't exist, it'll spit out an error which we want to ignore.
        task.launch()
        task.waitUntilExit()
        let output = stdout.fileHandleForReading
        let data = output.readDataToEndOfFile()
        let path = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        return NSURL(fileURLWithPath: path.chomp())
    }
    
    func rebuildMenu() {
        screenShotMenu.removeAllItems()
        deleteMenuItem.submenu?.removeAllItems()
        for url in pathList {
            self.createMenuItemsForPath(url)
        }
        screenShotMenu.addItem(separatorMenuItem)
        screenShotMenu.addItem(addMenuItem)
        if( !pathList.isEmpty ){ //don't bother showing delete menu if there's nothing to delete
            screenShotMenu.addItem(deleteMenuItem)
        }
        screenShotMenu.addItem(quitMenuItem)
    }
    
    func createMenuItemsForPath(url: NSURL){
        // make menu to select the path
        let menuItem = NSMenuItem()
        menuItem.title = url.lastPathComponent!
        menuItem.image = self.getImageForURL(url)
        menuToURLs[menuItem] = url
        menuItem.action = #selector(AppDelegate.directoryMenuClicked(_:))
        menuItem.target = self
        if url.path! == getScreenShotDirectory().path! {//this isn't great, because it spawns a new task each time it's called.  Maybe we should call this at the beginning and cache.
            menuItem.state = NSOnState
        }
        screenShotMenu.addItem(menuItem)
        // make menu to delete the path
        let deletePathItem = NSMenuItem()
        deletePathItem.title = url.lastPathComponent!
        deletePathItem.image = self.getImageForURL(url)
        deleteMenuToURLs[deletePathItem] = url
        deletePathItem.action = #selector(AppDelegate.deleteMenuClicked(_:))
        deletePathItem.target = self
        deleteMenuItem.submenu!.addItem(deletePathItem)
    }
    
    func addPathToMenu(url: NSURL) {
        if(pathList.contains(url)){
            return
        }
        //apperently swift lacks a way to easliy insert a value into a sorted array
        pathList.append(url)
        pathList.sortInPlace {
            return $0.path! < $1.path!
        }
        
        savePaths()
        rebuildMenu()
        
    }
    
    func readPaths() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let paths = defaults.arrayForKey("pathsKey")
        if( paths != nil ){
            for url in paths! {
                pathList.append(NSURL(fileURLWithPath: url as! String))
            }
        }
    }
    
    func savePaths() {
        let defaults = NSUserDefaults.standardUserDefaults()
        //can't save a list of URLS to standard defaults, so let's make an array of strings instead
        var pathArray = [String]()
        for url in pathList{
            pathArray.append(url.path!)
        }
        defaults.setObject(pathArray, forKey: "pathsKey")
    }
    
    func getImageForURL(url: NSURL) -> NSImage {
        return NSWorkspace.sharedWorkspace().iconForFile(url.path!)
    }
    
    @IBAction func directoryMenuClicked(sender: NSMenuItem) {
        self.setScreenShotDirectory(menuToURLs[sender]!)
        self.rebuildMenu()//rebuild menu to make sure the correct menu item is turned on
    }
    
    @IBAction func deleteMenuClicked(sender: NSMenuItem) {
        let path = deleteMenuToURLs[sender]!.path!
        pathList = pathList.filter({ $0.path! != path })
        savePaths()
        rebuildMenu()
    }
    
    @IBAction func addClicked(sender: NSMenuItem) {
        // select a folder
        let openPanel = NSOpenPanel();
        openPanel.title = "Select a folder to receeve screenshots"
        openPanel.message = "MESSAGE?"
        openPanel.showsResizeIndicator=true;
        openPanel.canChooseDirectories = true;
        openPanel.canChooseFiles = false;
        openPanel.allowsMultipleSelection = false;
        openPanel.canCreateDirectories = true;
        openPanel.delegate = self;
        
        openPanel.beginWithCompletionHandler { (result) -> Void in
            if(result == NSFileHandlingPanelOKButton){
                self.addPathToMenu(openPanel.URL!)
            }
        }
    }
    
}

