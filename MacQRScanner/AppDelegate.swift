//
//  AppDelegate.swift
//  MacQRScanner
//
//  Created by Shuaiwei Yu on 09.02.25.
//

import Cocoa
import Vision
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var parser = QRCodeParser()
    private var customWindow: NSWindow?

    /**
     Configures application after launch completion

     Initializes menu bar interface and global hotkey monitoring
     */
    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissions()
        setupMenuBar()
        setupGlobalHotKey()
    }
    
    /**
     request the accessibility permission to listen to the global hot key
     */
    private func requestAccessibilityPermissions() {
        let doNotShowAgain = UserDefaults.standard.bool(forKey: "doNotShowAccessibilityAlert")
        if doNotShowAgain {
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if !isTrusted {
            showAccessibilityAlert()
        }
    }

    /**
     Creates system status bar item with menu options
     
     Adds QR scanner icon to menu bar with two actions:
     - Scan QR Code: Initiate scanning process
     - Quit: Terminate application
     */
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "QR Scanner")
        }

        let menu = NSMenu()

        let scanMenuItem = NSMenuItem(
            title: String(localized: "menu_scan_qr_code"),
            action: #selector(scanQRCode),
            keyEquivalent: "R"
        )
        scanMenuItem.keyEquivalentModifierMask = [.command, .shift]

        menu.addItem(scanMenuItem)
        menu.addItem(.separator())

        let quitMenuItem = NSMenuItem(
            title: String(localized: "menu_quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        menu.addItem(quitMenuItem)

        statusItem?.menu = menu
    }

    /**
     Registers global hotkey (Cmd+Shift+R) for scanning
     
     > Warning: Requires Accessibility permissions for global key monitoring
     Uses both global and local event monitors for comprehensive coverage
     */
    private func setupGlobalHotKey() {
        // NOTE: Needs Accessibility permissions to monitor global keys
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 15 { // 'R' key
                self?.scanQRCode()
            }
        }

        // Local monitor (when app is frontmost)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 15 {
                self.scanQRCode()
                return nil
            }
            return event
        }
    }
    
    /**
     Displays accessibility alert window
     */
    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "accessibility_alert_title")
        alert.informativeText = String(localized: "accessibility_alert_content")
        alert.alertStyle = .warning

        alert.addButton(withTitle: String(localized: "accessibility_alert_button_ok"))
        alert.addButton(withTitle: String(localized: "accessibility_alert_button_open_setting"))

        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = String(localized: "accessibility_alert_button_no_remind")

        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()

        if let suppressionButton = alert.suppressionButton,
           suppressionButton.state == .on
        {
            UserDefaults.standard.set(true, forKey: "doNotShowAccessibilityAlert")
        }

        switch response {
        case .alertFirstButtonReturn:
            break
        case .alertSecondButtonReturn:
            openAccessibilitySettings()
        default:
            break
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - QR Code Scanning

    /**
     Initiates screen capture and QR code detection process
     
     Workflow:
     1. Captures screen area using `screencapture` CLI tool
     2. Processes temporary screenshot file
     3. Performs QR code detection
     4. Cleans up temporary files
     */
    @objc func scanQRCode() {
        // 1. Use `screencapture -i` to let user select a region.
        // 2. Wait for the user to finish, then process the temporary file.
        
        let fileManager = FileManager.default
        let tempFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("temp_screenshot.png")

        // Remove old file if it exists
        if fileManager.fileExists(atPath: tempFilePath) {
            try? fileManager.removeItem(atPath: tempFilePath)
        }

        let task = Process()
        // Depending on your system, `screencapture` may live in /usr/bin or /usr/sbin
        // You can verify by running `which screencapture` in Terminal.
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", tempFilePath]

        task.launch()
        task.waitUntilExit()

        // Check if screenshot was saved
        guard fileManager.fileExists(atPath: tempFilePath) else {
            // The user may have canceled the screenshot, or an error occurred.
            return
        }

        // 3. Create NSImage from the captured file
        let screenshotURL = URL(fileURLWithPath: tempFilePath)
        guard let screenshotImage = NSImage(contentsOf: screenshotURL) else {
            showAlert(result: String(localized: "alert_failure_unable_loading_screenshot"))
            return
        }

        // 4. Perform QR detection
        detectQRCode(in: screenshotImage)

        // 5. Clean up temp file
        try? fileManager.removeItem(atPath: tempFilePath)
    }

    /**
     Performs QR code detection on captured image
     
     - Parameters:
        - image: The NSImage containing potential QR codes
     
     Uses Vision framework's barcode detection with completion handler:
     - Shows error message for detection failures
     - Displays results through appropriate UI
     */
    private func detectQRCode(in image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            showAlert(result: String(localized: "alert_failure_unable_reading_screenshot"))
            return
        }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                self.showAlert(result: String(localized: "alert_failure_detection_details").appending(error.localizedDescription))
                return
            }

            guard let results = request.results as? [VNBarcodeObservation], !results.isEmpty else {
                self.showAlert(result: String(localized: "alert_warn_no_qr_code"))
                return
            }

            let qrText = results.first?.payloadStringValue ?? String(localized: "alert_warn_cant_parsing")
            let qrType = parser.parseQRCodeType(qrText)
            self.showCustomSwiftUIWindow(result: qrText, qrCodeType: qrType)
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            showAlert(result: String(localized: "alert_failure_recognition_details").appending(error.localizedDescription))
        }
    }
    
    // MARK: - Customized Results Window
    
    /**
     Displays standard alert dialog with scan results
     
     - Parameters:
        - result: The message text to display in alert
     */
    private func showAlert(result: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = String(localized: "alert_title")
            alert.informativeText = result
            alert.alertStyle = .informational
            alert.addButton(withTitle: String(localized: "alert_ok"))
            alert.runModal()
        }
    }

    /**
     Creates and displays custom SwiftUI result window
     
     - Parameters:
        - result: The decoded QR code content
        - qrCodeType: The categorized type of QR code
     
     Window features:
     - Centered position
     - Custom close behavior
     */
    private func showCustomSwiftUIWindow(result: String, qrCodeType: QRCodeType) {
        let alertView = CustomAlertView(
            title: "QR Code Result",
            message: result,
            qrCodeType: qrCodeType,
            onClose: { [weak self] in
                self?.customWindow?.close()
                self?.customWindow = nil
            }
        )
        
        let hostingController = NSHostingController(rootView: alertView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.isReleasedWhenClosed = false
        window.center()
        
        window.contentViewController = hostingController
        
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        customWindow = window
    }
    
    /**
     Terminates application
     */
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
