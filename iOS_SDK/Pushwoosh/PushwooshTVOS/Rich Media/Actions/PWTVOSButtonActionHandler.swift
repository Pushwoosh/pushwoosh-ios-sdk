//
//  PWTVOSButtonActionHandler.swift
//  PushwooshTVOS
//
//  Created by André Kis on 13.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

import Foundation
import UIKit

@available(tvOS 11.0, *)
class PWTVOSButtonActionHandler {

    weak var viewController: UIViewController?
    weak var richMediaManager: PWTVOSRichMediaManager?

    init(viewController: UIViewController?, richMediaManager: PWTVOSRichMediaManager?) {
        self.viewController = viewController
        self.richMediaManager = richMediaManager
    }

    func handleCloseButton() {
        sendRichMediaAction(actionType: 3, actionAttributes: nil)

        if let vc = viewController as? PWTVOSRichMediaViewController {
            vc.dismissWithAnimation()
        } else {
            richMediaManager?.dismiss(animated: true)
        }
    }

    func handleOpenSettingsButton() {
        sendRichMediaAction(actionType: 4, actionAttributes: nil)

        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        richMediaManager?.dismiss(animated: true)
    }

    func handlePostEventButton(eventName: String, eventAttributes: [String: Any]?) {
        var mergedAttributes = eventAttributes ?? [:]

        if let vc = viewController as? PWTVOSRichMediaViewController {
            let textFieldValues = vc.getTextFieldValues()
            mergedAttributes.merge(textFieldValues) { (_, new) in new }
        }

        guard let inAppManagerClass = NSClassFromString("PWInAppManager") as? NSObject.Type else {
            return
        }

        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard let sharedManager = inAppManagerClass.perform(sharedManagerSelector)?.takeUnretainedValue() else {
            return
        }

        let postEventSelector = NSSelectorFromString("postEvent:withAttributes:completion:")
        if sharedManager.responds(to: postEventSelector) {
            let method = sharedManager.method(for: postEventSelector)
            typealias PostEventFunction = @convention(c) (AnyObject, Selector, String, [String: Any]?, @escaping (Error?) -> Void) -> Void
            let postEventFunc = unsafeBitCast(method, to: PostEventFunction.self)
            postEventFunc(sharedManager, postEventSelector, eventName, mergedAttributes) { _ in }
        }

        sendRichMediaAction(actionType: 1, actionAttributes: mergedAttributes)
    }

    private func sendRichMediaAction(actionType: Int, actionAttributes: [String: Any]?) {
        guard let inAppManagerClass = NSClassFromString("PWInAppManager") as? NSObject.Type else {
            return
        }

        let sharedManagerSelector = NSSelectorFromString("sharedManager")
        guard let sharedManager = inAppManagerClass.perform(sharedManagerSelector)?.takeUnretainedValue() else {
            return
        }

        let inAppMessagesManagerSelector = NSSelectorFromString("inAppMessagesManager")
        guard let inAppMessagesManager = sharedManager.perform(inAppMessagesManagerSelector)?.takeUnretainedValue() else {
            return
        }

        guard let vc = viewController as? PWTVOSRichMediaViewController else {
            return
        }

        let inAppCode = vc.inAppCode
        let richMediaCode = vc.richmediaCode
        let messageHash = vc.messageHash

        var attributesString = ""
        if let attributes = actionAttributes, !attributes.isEmpty {
            if let jsonData = try? JSONSerialization.data(withJSONObject: attributes),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                attributesString = jsonString
            }
        }

        let richMediaActionSelector = NSSelectorFromString("richMediaAction:richMediaCode:actionType:actionAttributes:messageHash:completion:")
        if inAppMessagesManager.responds(to: richMediaActionSelector) {
            let method = inAppMessagesManager.method(for: richMediaActionSelector)
            typealias RichMediaActionFunction = @convention(c) (AnyObject, Selector, String, String, NSNumber, String, String?, @escaping (Error?) -> Void) -> Void
            let richMediaActionFunc = unsafeBitCast(method, to: RichMediaActionFunction.self)
            richMediaActionFunc(inAppMessagesManager, richMediaActionSelector, inAppCode, richMediaCode, NSNumber(value: actionType), attributesString, messageHash) { _ in }
        }
    }

    func handleSendTagsButton(tags: [String: Any]) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            return
        }

        let sharedInstanceSelector = NSSelectorFromString("sharedInstance")
        guard let pushwoosh = pushwooshClass.perform(sharedInstanceSelector)?.takeUnretainedValue() else {
            return
        }

        let setTagsSelector = NSSelectorFromString("setTags:")
        if pushwoosh.responds(to: setTagsSelector) {
            _ = pushwoosh.perform(setTagsSelector, with: tags)
        }

        sendRichMediaAction(actionType: 2, actionAttributes: tags)
    }

    func handleSetEmailButton(email: String) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            return
        }

        let sharedInstanceSelector = NSSelectorFromString("sharedInstance")
        guard let pushwoosh = pushwooshClass.perform(sharedInstanceSelector)?.takeUnretainedValue() else {
            return
        }

        let setEmailSelector = NSSelectorFromString("setEmail:")
        if pushwoosh.responds(to: setEmailSelector) {
            _ = pushwoosh.perform(setEmailSelector, with: email)
        }
    }

    func handleGetTagsButton(completion: @escaping ([String: Any]?) -> Void) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            completion(nil)
            return
        }

        let sharedInstanceSelector = NSSelectorFromString("sharedInstance")
        guard let pushwoosh = pushwooshClass.perform(sharedInstanceSelector)?.takeUnretainedValue() else {
            completion(nil)
            return
        }

        let getTagsSelector = NSSelectorFromString("getTags:onFailure:")
        if pushwoosh.responds(to: getTagsSelector) {
            let method = pushwoosh.method(for: getTagsSelector)
            typealias GetTagsFunction = @convention(c) (AnyObject, Selector, @escaping ([String: Any]?) -> Void, @escaping (Error?) -> Void) -> Void
            let getTagsFunc = unsafeBitCast(method, to: GetTagsFunction.self)
            getTagsFunc(pushwoosh, getTagsSelector, { tags in
                completion(tags)
            }, { error in
                completion(nil)
            })
        } else {
            completion(nil)
        }
    }

    func handleGetHwidButton(completion: @escaping (String?) -> Void) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            completion(nil)
            return
        }

        let sharedInstanceSelector = NSSelectorFromString("sharedInstance")
        guard let pushwoosh = pushwooshClass.perform(sharedInstanceSelector)?.takeUnretainedValue() else {
            completion(nil)
            return
        }

        let hwidSelector = NSSelectorFromString("getHWID")
        if pushwoosh.responds(to: hwidSelector) {
            if let hwid = pushwoosh.perform(hwidSelector)?.takeUnretainedValue() as? String {
                completion(hwid)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    func handleGetVersionButton(completion: @escaping (String?) -> Void) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            completion(nil)
            return
        }

        let versionSelector = NSSelectorFromString("version")
        if pushwooshClass.responds(to: versionSelector) {
            if let version = pushwooshClass.perform(versionSelector)?.takeUnretainedValue() as? String {
                completion(version)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    func handleGetApplicationButton(completion: @escaping (String?) -> Void) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            completion(nil)
            return
        }

        let sharedInstanceSelector = NSSelectorFromString("sharedInstance")
        guard let pushwoosh = pushwooshClass.perform(sharedInstanceSelector)?.takeUnretainedValue() else {
            completion(nil)
            return
        }

        let applicationCodeSelector = NSSelectorFromString("applicationCode")
        if pushwoosh.responds(to: applicationCodeSelector) {
            if let applicationCode = pushwoosh.perform(applicationCodeSelector)?.takeUnretainedValue() as? String {
                completion(applicationCode)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    func handleGetUserIdButton(completion: @escaping (String?) -> Void) {
        guard let pushwooshClass = NSClassFromString("Pushwoosh") as? NSObject.Type else {
            completion(nil)
            return
        }

        let sharedInstanceSelector = NSSelectorFromString("sharedInstance")
        guard let pushwoosh = pushwooshClass.perform(sharedInstanceSelector)?.takeUnretainedValue() else {
            completion(nil)
            return
        }

        let userIdSelector = NSSelectorFromString("getUserId")
        if pushwoosh.responds(to: userIdSelector) {
            if let userId = pushwoosh.perform(userIdSelector)?.takeUnretainedValue() as? String {
                completion(userId)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }

    func handleGetRichmediaCodeButton(completion: @escaping (String?) -> Void) {
        if let vc = viewController as? PWTVOSRichMediaViewController {
            completion(vc.richmediaCode)
        } else {
            completion(nil)
        }
    }

    func handleGetDeviceTypeButton(completion: @escaping (String?) -> Void) {
        completion("7")
    }

    func handleGetMessageHashButton(completion: @escaping (String?) -> Void) {
        if let vc = viewController as? PWTVOSRichMediaViewController {
            completion(vc.messageHash)
        } else {
            completion(nil)
        }
    }

    func handleGetInAppCodeButton(completion: @escaping (String?) -> Void) {
        if let vc = viewController as? PWTVOSRichMediaViewController {
            completion(vc.inAppCode)
        } else {
            completion(nil)
        }
    }
}
