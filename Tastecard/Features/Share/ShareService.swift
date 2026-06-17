//
//  ShareService.swift
//  Tastecard
//
//  Native iOS share sheet (UIActivityViewController) sharing the REAL exported PNG (§3,
//  §11). No fake links, no mock social buttons. The share sheet itself offers Save Image,
//  Messages, Mail, AirDrop, etc. — all real, all system-provided.
//

import UIKit

enum ShareService {
    /// Presents the system share sheet for the given items (typically a PNG file URL).
    static func present(items: [Any], completion: (() -> Void)? = nil) {
        guard let root = topViewController() else { completion?(); return }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // iPad popover anchor.
        if let pop = activity.popoverPresentationController {
            pop.sourceView = root.view
            pop.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.maxY - 40, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        activity.completionWithItemsHandler = { _, _, _, _ in completion?() }
        root.present(activity, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              var top = scene.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
