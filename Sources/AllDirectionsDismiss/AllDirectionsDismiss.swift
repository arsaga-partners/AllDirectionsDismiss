//
//  AllDirectionsDismiss.swift
//  AllDirectionsDismiss
//
//  Created by kohei saito on 2020/06/14.
//  Copyright © 2020 kohei. All rights reserved.
//

import UIKit

public class AllDirectionsDismiss: NSObject {
    public struct Defaults {
        private init() {}
        public static let dismissPercent: CGFloat = 0.3
        public static let dismissVelocity: CGFloat = 500
        public static let allowDismissDirection: [PanDirection] = [.down, .up, .left, .right]
        public static let backgroundAlpha: CGFloat = 0.9
        public static let backgroundColor: UIColor = .black
    }

    public convenience init?(scrollView: UIScrollView) {
        guard let viewController = type(of: self).viewControllerFromScrollView(scrollView) else {
            fatalError("The scrollView must be on the view controller")
        }
        self.init(viewController: viewController, scrollView: scrollView)
    }

    public init(viewController: UIViewController, scrollView: UIScrollView? = nil, navigationBar: UINavigationBar? = nil) {
        self.scrollView = scrollView
        self.viewController = viewController
        super.init()

        viewController.navigationController?.delegate = self
        viewController.transitioningDelegate = self
        viewController.navigationController?.transitioningDelegate = self
        addDismissGesture(navigationBar: navigationBar ?? viewController.navigationController?.navigationBar)
    }

    public var dismissPercent: CGFloat = Defaults.dismissPercent {
        didSet {
            interactionController.dimissPercent = dismissPercent
            dismissPercent = min(max(0.0, dismissPercent), 1.0)
        }
    }

    public var dismissVelocity: CGFloat = Defaults.dismissVelocity {
        didSet {
            dismissVelocity = min(max(0.0, dismissVelocity), 100000)
        }
    }

    public var allowDismissDirection: [PanDirection] = Defaults.allowDismissDirection
    public var backgroundAlpha: CGFloat = Defaults.backgroundAlpha
    public var backgroundColor: UIColor = Defaults.backgroundColor
    public var shouldRelease: Bool = true

    private weak var viewController: UIViewController?
    private var scrollView: UIScrollView?
    private let interactionController = DragInteractionController()
    private var animationController: UIViewControllerAnimatedTransitioning?
    private var currentDirection: PanDirection?

    public func addDismissGesture(panGesture: DragDismissGestureRecognizer) {
        panGesture.addTarget(self, action: #selector(handleDismissGestureRecognizer(_:)))
    }

    public func addDismissGesture(view: UIView) {
        let gesture = DragDismissGestureRecognizer()
        view.addGestureRecognizer(gesture)
        gesture.addTarget(self, action: #selector(handleDismissGestureRecognizer(_:)))
    }

    @objc private func handlePopGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            if animationController == nil {
                guard let direction = sender.direction else {
                    return
                }
                guard allowDismissDirection.contains(direction) else {
                    return
                }
                currentDirection = direction
                scrollView?.bounces = false
                animationController = DragDismissAnimationController(direction: direction == .right ? .right : .left, backgroundAlpha: backgroundAlpha, backgroundColor: backgroundColor)
                sender.setTranslation(CGPoint.zero, in: sender.view)
                viewController?.presentingViewController?.dismiss(animated: true, completion: nil)
                guard #available(iOS 13.0, *) else {return}
                if let navi = viewController?.navigationController {
                    if let presentationController = navi.presentationController {
                        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
                    }
                } else {
                    if let presentationController = viewController?.presentationController {
                        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
                    }
                }
            }

            let translation = sender.translation(in: sender.view)
            let percent = translation.x / (viewController?.view.bounds.width ?? 0)
            if currentDirection != sender.direction {
                if sender.direction == .right, percent > 0 {
                    return
                }
                if sender.direction == .left, percent < 0 {
                    return
                }
            }
            viewController?.view.endEditing(true)
            interactionController.update(percent)
            return
        case .ended:
            scrollView?.bounces = true
            currentDirection = nil
            if interactionController.shouldFinish {
                if sender.direction == .right, sender.velocity(in: nil).x < dismissVelocity {
                    fallthrough
                }
                if sender.direction == .left, sender.velocity(in: nil).x > -dismissVelocity {
                    fallthrough
                }
                interactionController.finish()
                animationController = nil
                dismiss()
                break
            }
            fallthrough
        default:
            currentDirection = nil
            interactionController.cancel()
            animationController = nil
        }
    }

    @objc private func handleDismissGestureRecognizer(_ sender: UIPanGestureRecognizer) {
        switch sender.state {
        case .began, .changed:
            guard let direction = sender.direction else {
                return
            }
            let translation = sender.translation(in: sender.view)
            let percent = translation.y / (viewController?.view.bounds.height ?? 0)
            if animationController == nil {
                guard allowDismissDirection.contains(direction) else {
                    return
                }
                if let scrollView = sender.view as? UIScrollView {
                    guard (scrollView.isAtTop && direction != .up) || (scrollView.isAtBottom && direction != .down) else {
                        return
                    }
                    animationController = DragDismissAnimationController(direction: scrollView.isAtTop ? .down : .up, backgroundAlpha: backgroundAlpha, backgroundColor: backgroundColor)
                } else {
                    animationController = DragDismissAnimationController(direction: direction == .down ? .down : .up, backgroundAlpha: backgroundAlpha, backgroundColor: backgroundColor)
                }
                currentDirection = direction
                scrollView?.bounces = false
                sender.setTranslation(CGPoint.zero, in: sender.view)
                viewController?.presentingViewController?.dismiss(animated: true, completion: nil)
                guard #available(iOS 13.0, *) else {return}
                if let navi = viewController?.navigationController {
                    if let presentationController = navi.presentationController {
                        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
                    }
                } else {
                    if let presentationController = viewController?.presentationController {
                        presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
                    }
                }
            }

            if currentDirection != sender.direction {
                if sender.direction == .up, percent <= 0 {
                    fallthrough
                }
                if sender.direction == .down, percent >= 0 {
                    fallthrough
                }
            }
            viewController?.view.endEditing(true)
            interactionController.update(percent)
            return
        case .ended:
            scrollView?.bounces = true
            currentDirection = nil
            if interactionController.shouldFinish {
                if sender.direction == .down, sender.velocity(in: nil).y < dismissVelocity {
                    fallthrough
                }
                if sender.direction == .up, sender.velocity(in: nil).y > -dismissVelocity {
                    fallthrough
                }
                interactionController.finish()
                animationController = nil
                dismiss()
                break
            }
            fallthrough
        default:
            currentDirection = nil
            interactionController.cancel()
            animationController = nil
        }
    }

    private func addDismissGesture(navigationBar: UINavigationBar?) {
        let popGestureRecognizer = PopGestureRecognizer(target: self, action: #selector(handlePopGestureRecognizer(_:)))
        viewController?.view.addGestureRecognizer(popGestureRecognizer)

        let dismissGestureRecognizer = DragDismissGestureRecognizer(target: self, action: #selector(handleDismissGestureRecognizer(_:)))
        if let scrollView = scrollView {
            scrollView.addGestureRecognizer(dismissGestureRecognizer)
        } else {
            viewController?.view.addGestureRecognizer(dismissGestureRecognizer)
        }

        let barDismissGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleDismissGestureRecognizer(_:)))
        navigationBar?.addGestureRecognizer(barDismissGestureRecognizer)
    }

    private func dismiss() {
        if shouldRelease {
            scrollView?.gestureRecognizers?.forEach({ (gesture) in
                scrollView?.removeGestureRecognizer(gesture)
            })
            scrollView = nil
            viewController?.view.gestureRecognizers?.forEach({ (gesture) in
                viewController?.view.removeGestureRecognizer(gesture)
            })
            viewController = nil
            animationController = nil
            currentDirection = nil
        }
    }

    private static func viewControllerFromScrollView(_ scrollView: UIScrollView) -> UIViewController? {
        var responder: UIResponder? = scrollView
        while let r = responder {
            if let viewController = r as? UIViewController {
                return viewController
            }
            responder = r.next
        }
        return nil
    }
}

extension AllDirectionsDismiss: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension AllDirectionsDismiss: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return animationController
    }

    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
    }
}

extension AllDirectionsDismiss: UIViewControllerTransitioningDelegate {
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return animationController
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactionController
    }
}
