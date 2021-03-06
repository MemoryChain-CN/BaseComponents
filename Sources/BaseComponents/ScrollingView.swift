//
//  ScrollingView.swift
//  BaseComponents
//
//  Created by mmackh on 31.01.20.
//  Copyright © 2019 Maximilian Mackh. All rights reserved.

/*
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import UIKit

public enum ScrollingViewDirection: Int {
    case horizontal
    case vertical
}

public enum ScrollingViewLayoutType: Int {
    case automatic
    case fixed
}

private class ScrollingViewHandler {
    var layoutType: ScrollingViewLayoutType = .fixed
    var valueHandler: ((CGRect) -> ScrollingViewLayoutInstruction)?
    var staticValue: CGFloat = 0.0
    var staticEdgeInsets: UIEdgeInsets = UIEdgeInsets.zero

    func getLayoutInstruction(_ superviewBounds: CGRect) -> ScrollingViewLayoutInstruction {
        return (valueHandler == nil) ? ScrollingViewLayoutInstruction(layoutType: layoutType, value: staticValue, edgeInsets: staticEdgeInsets) : valueHandler!(superviewBounds)
    }
}

public class ScrollingViewLayoutInstruction {
    var value: CGFloat = 0
    var layoutType: ScrollingViewLayoutType = .fixed
    var edgeInsets: UIEdgeInsets = UIEdgeInsets.zero
    weak var determineSizeBasedOnView: UIView?

    public convenience init(layoutType: ScrollingViewLayoutType) {
        self.init()
        
        self.layoutType = layoutType
    }

    public convenience init(layoutType: ScrollingViewLayoutType, value: CGFloat) {
        self.init()

        self.value = value
        self.layoutType = layoutType
    }

    public convenience init(layoutType: ScrollingViewLayoutType, value: CGFloat, edgeInsets: UIEdgeInsets) {
        self.init()

        self.value = value
        self.edgeInsets = edgeInsets
        self.layoutType = layoutType
    }
}

public class ScrollingSplitView: SplitView {
    public override func addSubview(_ view: UIView, layoutType: SplitViewLayoutType, value: CGFloat, edgeInsets: UIEdgeInsets) {
        super.addSubview(view, layoutType: layoutType, value: value, edgeInsets: edgeInsets)
    }
    
    public override func addSubview(_ view: UIView, valueHandler: @escaping (CGRect) -> SplitViewLayoutInstruction) {
        super.addSubview(view, valueHandler: valueHandler)
    }
}

public class ScrollingSplitViewLayoutInstruction: ScrollingViewLayoutInstruction {
    @available(*, unavailable)
    public convenience init(layoutType: ScrollingViewLayoutType) {
        self.init()
    }
    
    @available(*, unavailable)
    public convenience init(layoutType: ScrollingViewLayoutType, value: CGFloat) {
        self.init()
    }
    
    @available(*, unavailable)
    public convenience init(layoutType: ScrollingViewLayoutType, value: CGFloat, edgeInsets: UIEdgeInsets) {
        self.init()
    }
    
    public convenience init(fixedLayoutTypeValue: CGFloat, edgeInsets: UIEdgeInsets = .zero) {
        self.init()
        
        self.layoutType = .fixed
        self.value = fixedLayoutTypeValue
        self.edgeInsets = edgeInsets
    }
    
    public convenience init(automaticLayoutTypeDetermineSizeBasedOn view: UIView?, edgeInsets: UIEdgeInsets = .zero) {
        self.init()
        
        self.layoutType = .automatic
        self.determineSizeBasedOnView = view
        self.edgeInsets = edgeInsets
    }
}

public class ScrollingView: UIScrollView, UIGestureRecognizerDelegate {
    public var direction: ScrollingViewDirection = .vertical
    
    private var frameCache = CGRect.zero
    private var layoutHandlers: Dictionary<UIView,ScrollingViewHandler> = Dictionary()
    
    public var enclosedInRender = false
    
    public var layoutPass = false
    
    @discardableResult
    public convenience init(superview: UIView, configurationHandler: (_ scrollingView: ScrollingView) -> Void) {
        self.init()
        
        unowned let weakSelf = self
        configurationHandler(weakSelf)
        
        if (superview.isKind(of: SplitView.self)) {
            let superSplitView = superview as! SplitView
            superSplitView.addSubview(self, layoutType: .percentage, value: 100)
        } else {
            frame = superview.bounds
            autoresizingMask = [.flexibleWidth,.flexibleHeight]
            superview.addSubview(self)
        }
    }
    
    @available(*, unavailable)
    public override func addSubview(_ view: UIView) {
        super.addSubview(view)
    }
    
    public func addSubview(_ view: UIView, layoutType: ScrollingViewLayoutType = .automatic, value: CGFloat = 0, edgeInsets: UIEdgeInsets = .zero) {
        let handler = ScrollingViewHandler()
        handler.layoutType = layoutType
        handler.staticValue = value
        handler.staticEdgeInsets = edgeInsets
        
        view.translatesAutoresizingMaskIntoConstraints = false

        layoutHandlers[view] = handler

        (self as UIView).addSubview(view)
    }
    
    public func addSubview(_ view: UIView, valueHandler: @escaping (_ superviewBounds: CGRect) -> ScrollingViewLayoutInstruction) {
        let handler = ScrollingViewHandler()
        handler.valueHandler = valueHandler
        
        view.translatesAutoresizingMaskIntoConstraints = false

        layoutHandlers[view] = handler

        (self as UIView).addSubview(view)
    }
    
    @discardableResult
    public func addScrollingSplitView(configurationHandler: (_ splitView: ScrollingSplitView) -> Void, valueHandler: @escaping (_ superviewBounds: CGRect) -> ScrollingSplitViewLayoutInstruction) -> ScrollingSplitView {
        
        let splitView = ScrollingSplitView()
        unowned let weakSplitView = splitView
        configurationHandler(weakSplitView)
        
        let handler = ScrollingViewHandler()
        handler.valueHandler = valueHandler

        layoutHandlers[splitView] = handler

        (self as UIView).addSubview(splitView)
        
        return splitView
    }
    
    public override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        layoutHandlers.removeValue(forKey: subview)
    }
    
    public func invalidateLayout() {
        frameCache = CGRect.zero
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    public override func layoutSubviews() {
        if (frameCache.equalTo(frame)) {
            return
        }
        frameCache = frame
        
        let vertical = direction == .vertical
        
        let clampValue = vertical ? bounds.size.width : bounds.size.height
        
        var offsetTrackerX: CGFloat = 0.0
        var offsetTrackerY: CGFloat = 0.0
        
        for view in subviews {
            if view.isHidden {
                continue
            }
            
            if let layout = layoutHandlers[view]?.getLayoutInstruction(bounds) {
                var layoutValue = layout.value
                if (layout.layoutType == .automatic) {
                    let mockFrame = CGRect(x: offsetTrackerX, y: offsetTrackerY, width: (vertical ? clampValue : 10), height: (vertical ? clampValue : 10))
                    
                    var size: CGSize = .zero
                    if view.isKind(of: ScrollingSplitView.self) {
                        let scrollingSplitView = view as! ScrollingSplitView
                        if !layoutPass {
                            scrollingSplitView.frame = mockFrame.inset(by: layout.edgeInsets)
                            scrollingSplitView.invalidateLayout()
                        }
                        if let sizeView = layout.determineSizeBasedOnView {
                            size = sizeView.sizeThatFits(.init(width: vertical ? sizeView.bounds.size.width : .infinity, height: vertical ? .infinity : sizeView.bounds.size.height))
                            let instruction = scrollingSplitView.layoutInstruction(for: sizeView)
                            if vertical {
                                size.height += instruction.edgeInsets.top + instruction.edgeInsets.bottom;
                            } else {
                                size.width += instruction.edgeInsets.left + instruction.edgeInsets.right;
                            }
                        }
                        
                        layoutValue = vertical ? size.height : size.width
                        
                    } else {
                        if !layoutPass {
                            view.frame = mockFrame
                        }
                        size = view.sizeThatFits(.init(width: vertical ? clampValue - (layout.edgeInsets.left + layout.edgeInsets.right) : .infinity, height: vertical ? .infinity : clampValue - (layout.edgeInsets.top + layout.edgeInsets.bottom)))
                        layoutValue = vertical ? (size.height + layout.edgeInsets.top + layout.edgeInsets.bottom) : (size.width + layout.edgeInsets.left + layout.edgeInsets.right)
                    }
                    
                }
                
                var targetRect = CGRect(x: offsetTrackerX, y: offsetTrackerY, width: (vertical ? clampValue : layoutValue) , height: (vertical ? layoutValue : clampValue))
                targetRect = targetRect.inset(by: layout.edgeInsets)
                if vertical {
                    offsetTrackerY += layoutValue
                } else {
                    offsetTrackerX += layoutValue
                }
                
                if (!view.frame.equalTo(targetRect) && !layoutPass) {
                    view.frame = targetRect
                }
            }
        }
        
        let suggestedContentSize = CGSize(width: vertical ? clampValue : offsetTrackerX, height: vertical ? offsetTrackerY : clampValue)
        if (!contentSize.equalTo(suggestedContentSize) || layoutPass) {
            contentSize = suggestedContentSize
        }
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let target = super.hitTest(point, with: event)
        if (enclosedInRender) {
            if let target = target {
                if (target == self || target.isKind(of: SplitView.self)) {
                    return superview
                }
            }
        }
        return target
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return contentSize
    }
}

/*
 Dynamic Type Support
 */
extension ScrollingView {
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 10.0, *) {
            if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
                DispatchQueue.main.async {
                    self.invalidateLayout()
                }
            }
        }
    }
}
