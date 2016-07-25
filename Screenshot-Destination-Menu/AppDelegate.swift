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
    
	// store the paths to all directories we want to save as menu options
    var pathList = [NSURL]()

	// a map of NSMenuItem objects to corresponding directory paths, so when an
	// NSMenuItem is clicked, we know which path to set
    var menuToURLs = [NSMenuItem: NSURL]()

	// same as above, except the keys are put in the delete menu instead.
    var deleteMenuToURLs = [NSMenuItem: NSURL]()
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        if let icon = NSImage(named: "statusIcon") {
            //turn it into a "template" image, which makes it so it looks fine in
            //both normal and dark mode. Also, go ahead and force unwrap the icon
            icon.template = true
			statusItem.image = icon
		} else {
			//we didn't find an icon for some reason
			//set a title so we draw something instead of nothing, or crashing
			statusItem.title = "SD"
		}
        statusItem.menu = screenShotMenu
        
        // set default settings
        NSUserDefaults.standardUserDefaults().registerDefaults(["pathsKey":
            [NSURL(fileURLWithPath: NSHomeDirectory()+"/Desktop").path!,
                NSURL(fileURLWithPath: NSHomeDirectory()+"/Documents").path!,
				//this doesn't seem like the canonical way to get at the
				//~/Pictures folder, so any suggestions would be appreciated.
                NSURL(fileURLWithPath: NSHomeDirectory()+"/Pictures").path!]])
        
        self.readPaths()
        self.rebuildMenu()
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        self.savePaths()
    }
    
	// set the screen capture location directory to `file`
    func setScreenShotDirectory(file: NSURL) {
        let task = NSTask()
        task.launchPath = "/usr/bin/defaults"
		// go ahead and force an unwrap of file.path because there's no
		// recovering from that
        task.arguments =
			["write", "com.apple.screencapture", "location", file.path!]
        task.launch()
        task.waitUntilExit()
        resetSystemUIServer()
    }
    
	// get the current setting or, if something goes wrong return the path
	// to the desktop folder, assuming that there's no location set yet.
    func getScreenShotDirectory() -> NSURL {
        let task = NSTask()
        let stdout = NSPipe()
        let errout = NSPipe()//we ignore any error, but we have to make a pipe
							 //to catch it
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.screencapture", "location"]
        task.standardOutput = stdout
        task.standardError = errout //if the default setting doesn't exist,
									//it'll spit out an error which we want to
									//ignore.
        task.launch()
        task.waitUntilExit()
        let output = stdout.fileHandleForReading
        let data = output.readDataToEndOfFile()
        let path =
			NSString(data: data, encoding: NSUTF8StringEncoding) as! String
		if path.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0 {
			//empty output, so assume there has been no change to the setting
			//return the default
			return NSURL(fileURLWithPath: NSHomeDirectory()+"/Desktop");
		}
        return NSURL(fileURLWithPath: path.chomp())
    }
    
	// reset the SystemUIServer task to register the change
    func resetSystemUIServer() {
        let task = NSTask()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["SystemUIServer"]
        task.launch()
        task.waitUntilExit()
    }
    
    func rebuildMenu() {
        screenShotMenu.removeAllItems()
		//throw a rt error if deleteMenuItem has no submenu
        deleteMenuItem.submenu!.removeAllItems()
        for url in pathList {
            self.createMenuItemsForPath(url)
        }
        screenShotMenu.addItem(separatorMenuItem)
        screenShotMenu.addItem(addMenuItem)
        if( !pathList.isEmpty ){
			//don't bother showing delete menu if there's nothing to delete
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
        if url.path! == getScreenShotDirectory().path {
			//this isn't great, because it spawns a new task each time it's
			//called.  Maybe we should call this at the beginning and cache.
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
        //apparently swift lacks a way to easily insert a value into a sorted
		//array, correct me if I'm wrong
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
        //can't save a list of URLS to standard defaults, so let's make an
		//array of strings instead
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
        self.rebuildMenu() //rebuild menu to make sure the correct menu item is
						   //turned on
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
        openPanel.message = "Select a folder to receeve screenshots"
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

