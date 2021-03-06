//
//  AppDelegate.swift
//  Show Dock as Menu Bar Extras
//
//  Created by Gira on 11/3/20.
//  Copyright © 2020 Gira. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var statusBarItems: [NSStatusItem] = []
    
    let iconSize = 18
    let itemSlotWidth = 30
    
    var ignoredApplications: [String] = []
    
    public var runningApps: [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications.filter {
            // filtered out they are always accessed through Hammerspoon bindings
            $0.activationPolicy == .regular &&
                !ignoredApplications.contains($0.localizedName!)
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let file: FileHandle? = FileHandle(forReadingAtPath: "/Users/Gira/dotfiles/dock-ignored.txt")
        if file != nil {
            let data = file!.readDataToEndOfFile()
            file!.closeFile()

            let str = String(decoding: data, as: UTF8.self)
            ignoredApplications = str.split(separator: "\n").map(String.init)
        } else {
            print("Can't load dock-ignored.txt!")
        }
        
        trackAppsBeingActivated()
        trackAppsBeingQuit()
        
        updateMenuBar()
    }
    
    func isShowingApp(bundleId: String) -> Bool {
        for item in statusBarItems {
            if item.button!.accessibilityLabel() == bundleId {
                return true
            }
        }
        
        return false
    }
    
    func updateMenuBar() {
        let apps = runningApps
        
        for item in statusBarItems {
            let itemBundleId = item.button!.accessibilityLabel()!
            var isAppStillRunning = false
            
            for app in apps {
                if itemBundleId == app.bundleIdentifier! {
                    isAppStillRunning = true
                    break
                }
            }
            
            if !isAppStillRunning {
                statusBarItems = statusBarItems.filter({ $0 != item })
                NSStatusBar.system.removeStatusItem(item)
            }
        }
        
        for app in apps {
            if isShowingApp(bundleId: app.bundleIdentifier!) {
                continue
            }
            createNewMenuItem(app)
        }
    }
    
    func createNewMenuItem(_ app: NSRunningApplication) {
        let statusBar = NSStatusBar.system
        let statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        let statusBarItemIconBase = app.icon!
        
        let view = NSImageView(frame: NSRect(
            x: (itemSlotWidth - iconSize) / 2,
            y: 2,
            width: iconSize, height: iconSize + 1))
        
        view.image = statusBarItemIconBase
        view.wantsLayer = true
        if let existingSubview = statusBarItem.button?.subviews.first as? NSImageView {
            statusBarItem.button!.replaceSubview(existingSubview, with: view)
        } else {
            statusBarItem.button!.addSubview(view)
        }
        
        statusBarItem.button!.setAccessibilityLabel(app.bundleIdentifier)
        statusBarItem.button!.action = #selector(launchClicked)
        statusBarItem.button!.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusBarItem.button!.target = self
        
        statusBarItems.append(statusBarItem)
    }
    
    @objc func launchClicked(button: NSStatusBarButton) {
        let bundleId = button.accessibilityLabel()!
        let event = NSApp.currentEvent!
        
        if event.type == NSEvent.EventType.rightMouseUp {
            for app in self.runningApps {
                if app.bundleIdentifier! == bundleId {
                    app.terminate()
                    break
                }
            }
        } else {
            openApp(withBundleId: bundleId)
        }
    }
    
    func openApp(withBundleId bundleId: String) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["open", "-b", bundleId]
        task.launch()
        task.waitUntilExit()
    }
    
    func trackAppsBeingActivated() {
        NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { (notification) in
            
            self.updateMenuBar()
        }
    }
    
    func trackAppsBeingQuit() {
        NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { (notification) in
            
            self.updateMenuBar()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
}

