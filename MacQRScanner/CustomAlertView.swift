//
//  CustomAlertView.swift
//  MacQRScanner
//
//  Created by Shuaiwei Yu on 14.02.25.
//

import SwiftUI

struct CustomAlertView: View {
    let title: String
    let message: String
    let qrCodeType: QRCodeType
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
                .padding(.top, 25)

            ScrollView {
                Text(message)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
            }
            .frame(minHeight: 40, maxHeight: 80)

            Spacer()

            Divider()
                .padding(.horizontal, 20)
                .padding(.bottom, 5)

            VStack(spacing: 8) {
                switch qrCodeType {
                case .email(let email, let subject, let body):
                    EmailButtons(email: email, subject: subject, content: body, onAction: onClose)

                case .url(let url):
                    URLButtons(url: url, onAction: onClose)

                case .wifi(let ssid, let password):
                    WiFiButtons(ssid: ssid, password: password)

                case .text:
                    CopyTextButton(content: message)
                }

                OKButton(action: onClose)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: 250)
        }
        .frame(minWidth: 300, maxWidth: 500, minHeight: 250)
    }
    
    /**
     Creates a button for copying text content to clipboard
     
     - Parameters:
        - displayText: The localized text displayed on the button
        - content: The actual string content to be copied
     */
    private struct CopyTextButton: View {
        var displayText: String = String(localized: "result_copy_default")
        let content: String

        var body: some View {
            Button(action: { copyToClipboard(content) }) {
                Text(displayText)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        
        /**
         Copies specified text to the general pasteboard
         
         - Parameters:
            - text: The string content to copy to clipboard
         */
        private func copyToClipboard(_ text: String) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }

    /**
     Creates action buttons for email-type QR codes
     
     - Parameters:
        - email: The email address to use
        - subject: Optional subject line for the email
        - content: Optional body content for the email
     */
    private struct EmailButtons: View {
            let email: String
            var subject: String?
            var content: String?
            let onAction: () -> Void

            var body: some View {
                VStack(spacing: 8) {
                    Button(action: {
                        openMailClient(email: email, subject: subject, content: content)
                        onAction()
                    }) {
                        Text(String(localized: "result_open_email"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    CopyTextButton(content: email)
                }
            }

        /**
         Opens system's default email client with pre-filled content
         
         - Parameters:
            - email: Recipient email address
            - subject: Optional email subject line
            - content: Optional email body content
         */
        private func openMailClient(email: String, subject: String?, content: String?) {
            var mailtoURL = "mailto:\(email)"

            var parameters: [String] = []
            if let subject = subject, !subject.isEmpty {
                parameters.append("subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }
            if let body = content, !body.isEmpty {
                parameters.append("body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }

            if !parameters.isEmpty {
                mailtoURL.append("?" + parameters.joined(separator: "&"))
            }

            if let emailURL = URL(string: mailtoURL) {
                NSWorkspace.shared.open(emailURL)
            }
        }
    }

    /**
     Creates action buttons for URL-type QR codes
     
     - Parameters:
        - url: The URL to handle
     */
    private struct URLButtons: View {
            let url: URL
            let onAction: () -> Void

            var body: some View {
                VStack(spacing: 8) {
                    Button(action: {
                        openInBrowser(url)
                        onAction() // 执行完打开后关闭窗口
                    }) {
                        Text(String(localized: "result_open_in_browser"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    CopyTextButton(content: url.absoluteString)
                }
            }
            
            private func openInBrowser(_ url: URL) {
                NSWorkspace.shared.open(url)
            }
        }

    /**
     Creates action buttons for WiFi-type QR codes
     
     - Parameters:
        - ssid: The network SSID
        - password: The network password
     */
    private struct WiFiButtons: View {
        let ssid: String
        let password: String

        var body: some View {
            VStack(spacing: 8) {
                CopyTextButton(displayText: String(localized: "result_copy_password"), content: password)

                Button(action: { openWiFiSettings() }) {
                    Text(String(localized: "result_open_wifi_settings"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        
        /**
         Opens system network preferences pane
         */
        private func openWiFiSettings() {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Network.prefPane"))
        }
    }

    /**
     Creates a confirmation button to dismiss the alert
     
     - Parameters:
        - action: The closure to execute when pressed
     */
    private struct OKButton: View {
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(String(localized: "result_ok"))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

