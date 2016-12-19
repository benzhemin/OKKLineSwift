//
//  OKKLineDrawView.swift
//  OKKLineSwift
//
//  Created by SHB on 2016/12/5.
//
//

#if os(macOS)
    import Cocoa
#else
    import UIKit
#endif

class OKKLineDrawView: OKView {
    
    // MARK: - Property
    public var doubleTapHandle: (() -> Void)?
    
    private var configuration: OKConfiguration!
    
    private var contentView: UIView!
    private let contentViewLeading: CGFloat = 50.0
    
    private var mainView: OKKLineMainView!
    private var mainValueView: OKValueView!
    
    private var volumeView: OKKLineVolumeView!
    private var volumeValueView: OKValueView!
    
    private var accessoryView: OKKLineAccessoryView!
    private var accessoryValueView: OKValueView!
    
    private var indicatorVerticalView: OKView!
    private var indicatorHorizontalView: OKView!
    
    private var lastScale: CGFloat = 1.0
    private var lastPanPoint: CGPoint?
    private var lastOffsetIndex: Int?
    
    /// 开始draw的数组下标
    private var drawStartIndex: Int?
    /// draw的个数
    private var drawCount: Int {
        get {
            let count = Int((contentView.frame.width) / (configuration.klineSpace + configuration.klineWidth))
            return count > configuration.dataSource.klineModels.count ? configuration.dataSource.klineModels.count : count
        }
    }
    
    // MARK: - LifeCycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    convenience init(configuration: OKConfiguration) {
        self.init()
        self.configuration = configuration
        backgroundColor = configuration.mainViewBgColor
        /// Parent View
        contentView = UIView()
        // 捏合手势
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(pinchAction(_:)))
        contentView.addGestureRecognizer(pinchGesture)
        // 长按手势
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction(_:)))
        contentView.addGestureRecognizer(longPressGesture)
        // 双击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapGestureAction(_:)))
        tapGesture.numberOfTapsRequired = 2
        contentView.addGestureRecognizer(tapGesture)
        // 移动手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        contentView.addGestureRecognizer(panGesture)
        addSubview(contentView)
        
        contentView.snp.makeConstraints { (make) in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalTo(contentViewLeading)
        }
        
        /// Main View
        mainView = OKKLineMainView(configuration: configuration)
        mainView.limitValueChanged = { [weak self] (_ limitValue: (minValue: Double, maxValue: Double)?) -> Void in
            if let limitValue = limitValue {
                self?.mainValueView.limitValue = limitValue
            }
        }
        contentView.addSubview(mainView)
        mainView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(self.contentView.snp.height).multipliedBy(configuration.mainScale)
        }
        
        mainValueView = OKValueView(configuration: configuration)
        addSubview(mainValueView)
        mainValueView.snp.makeConstraints { (make) in
            make.trailing.equalTo(contentView.snp.leading)
            make.leading.equalToSuperview()
            make.top.equalTo(configuration.mainTopAssistViewHeight)
            make.bottom.equalTo(mainView.snp.bottom).offset(-configuration.mainBottomAssistViewHeight)
        }
        
        
        /// Volume View
        volumeView = OKKLineVolumeView(configuration: configuration)
        volumeView.limitValueChanged = { [weak self] (_ limitValue: (minValue: Double, maxValue: Double)?) -> Void in
            if let limitValue = limitValue {
                self?.volumeValueView.limitValue = limitValue
            }
        }
        contentView.addSubview(volumeView)
        volumeView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(self.mainView)
            make.top.equalTo(self.mainView.snp.bottom)
            make.height.equalTo(self.contentView.snp.height).multipliedBy(configuration.volumeScale)
        }
        
        volumeValueView = OKValueView(configuration: configuration)
        addSubview(volumeValueView)
        volumeValueView.snp.makeConstraints { (make) in
            make.trailing.equalTo(contentView.snp.leading)
            make.leading.equalToSuperview()
            make.top.equalTo(self.mainView.snp.bottom).offset(configuration.volumeTopViewHeight)
            make.bottom.equalTo(volumeView.snp.bottom)
        }
        
        /// Accessory View
        accessoryView = OKKLineAccessoryView(configuration: configuration)
        accessoryView.limitValueChanged = { [weak self] (_ limitValue: (minValue: Double, maxValue: Double)?) -> Void in
            if let limitValue = limitValue {
                self?.accessoryValueView.limitValue = limitValue
            }
        }
        contentView.addSubview(accessoryView)
        accessoryView.snp.makeConstraints { (make) in
            make.leading.trailing.equalTo(self.mainView)
            make.top.equalTo(self.volumeView.snp.bottom)
            make.height.equalTo(self.contentView.snp.height).multipliedBy(configuration.accessoryScale)
        }
        
        accessoryValueView = OKValueView(configuration: configuration)
        addSubview(accessoryValueView)
        accessoryValueView.snp.makeConstraints { (make) in
            make.trailing.equalTo(contentView.snp.leading)
            make.leading.equalToSuperview()
            make.top.equalTo(self.volumeView.snp.bottom).offset(configuration.accessoryTopViewHeight)
            make.bottom.equalTo(accessoryView.snp.bottom)
        }
        
        /// 指示器
        indicatorVerticalView = OKView()
        indicatorVerticalView.isHidden = true
        indicatorVerticalView.backgroundColor = configuration.longPressLineColor
        addSubview(indicatorVerticalView)
        indicatorVerticalView.snp.makeConstraints { (make) in
            make.bottom.equalToSuperview()
            make.top.equalTo(configuration.mainTopAssistViewHeight)
            make.width.equalTo(configuration.longPressLineWidth)
            make.leading.equalTo(0)
        }
        
        indicatorHorizontalView = OKView()
        indicatorHorizontalView.isHidden = true
        indicatorHorizontalView.backgroundColor = configuration.longPressLineColor
        addSubview(indicatorHorizontalView)
        indicatorHorizontalView.snp.makeConstraints { (make) in
            make.leading.equalTo(contentViewLeading)
            make.trailing.equalTo(0)
            make.height.equalTo(configuration.longPressLineWidth)
            make.top.equalTo(0)
        }
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func drawKLineView(_ initialize: Bool = true) {
        
        fetchDrawModels()
        
        //        if lastest {
        //            //设置contentOffset
        //            let klineViewWidth = CGFloat(configuration.dataSource.klineModels.count) * (configuration.klineWidth + configuration.klineSpace) + 10
        //            let offset = klineViewWidth - contentView.bounds.width
        //            contentView.contentOffset = CGPoint(x: (offset > 0 ? offset : 0), y: 0)
        //        }
        
        mainView.drawMainView()
        volumeView.drawVolumeView()
        accessoryView.drawAccessoryView()
    }
    
    /// 获取需要绘制的模型
    private func fetchDrawModels() {
        // 展示的个数
        
        if drawStartIndex == nil {
            drawStartIndex = configuration.dataSource.klineModels.count - drawCount - 1
        }
        
        if lastOffsetIndex != nil {
            drawStartIndex! -= lastOffsetIndex!
        }
        
        drawStartIndex! = drawStartIndex! > 0 ? drawStartIndex! : 0
        if drawStartIndex! > configuration.dataSource.klineModels.count - drawCount - 1 {
            drawStartIndex! = configuration.dataSource.klineModels.count - drawCount - 1
        }
        
        configuration.dataSource.drawKLineModels.removeAll()
        
        //        let range = NSMakeRange(drawStartIndex! > 0 ? drawStartIndex! : 0, drawCount)
        
        let loc = drawStartIndex! > 0 ? drawStartIndex! : 0
        
        configuration.dataSource.drawKLineModels = Array(configuration.dataSource.klineModels[loc...loc+drawCount])
        //            as NSArray).subarray(with: range) as! [OKKLineModel]
        configuration.dataSource.drawRange = NSMakeRange(loc, drawCount)
        
    }
    
    // MARK: - 手势事件
    // MARK: 移动手势
    
    /// 移动手势
    /// 左 -> 右 : x递增, x > 0
    /// 右 -> 左 : x递减, x < 0
    /// - Parameter recognizer: UIPanGestureRecognizer
    @objc
    private func panGestureAction(_ recognizer: UIPanGestureRecognizer) {
        
        switch recognizer.state {
        case .began:
            lastPanPoint = recognizer.location(in: recognizer.view)
        case .changed:
            
            let location = recognizer.location(in: recognizer.view)
            let klineUnit = configuration.klineWidth + configuration.klineSpace
            
            if abs(location.x - lastPanPoint!.x) < klineUnit {
                return
            }
            
            lastOffsetIndex = Int((location.x - lastPanPoint!.x) / klineUnit)
            
            drawKLineView(false)
            // 记录上次点
            lastPanPoint = location
            
        case .ended:
            
            lastOffsetIndex = nil
            lastPanPoint = nil
            
        default: break
        }
    }
    
    // MARK: 捏合手势
    
    /// 捏合手势
    /// 内 -> 外: recognizer.scale 递增, 且recognizer.scale > 1.0
    /// 外 -> 内: recognizer.scale 递减, 且recognizer.scale < 1.0
    /// - Parameter recognizer: UIPinchGestureRecognizer
    @objc
    private func pinchAction(_ recognizer: UIPinchGestureRecognizer) {
        
        let difValue = recognizer.scale - lastScale
        
        if abs(difValue) > configuration.klineScale {
            
            let lastKLineWidth: CGFloat = configuration.klineWidth
            let newKLineWidth: CGFloat = configuration.klineWidth * (difValue > 0 ?
                (1 + configuration.klineScaleFactor) : (1 - configuration.klineScaleFactor))
            
            // 超过限制 不在绘制
            if newKLineWidth > configuration.klineMaxWidth || newKLineWidth < configuration.klineMinWidth {
                return
            }
            
            configuration.klineWidth = newKLineWidth
            lastScale = recognizer.scale
            
            if recognizer.numberOfTouches == 2 {
                
                let pinchPoint1 = recognizer.location(ofTouch: 0, in: recognizer.view)
                let pinchPoint2 = recognizer.location(ofTouch: 1, in: recognizer.view)
                
                let centerPoint = CGPoint(x: (pinchPoint1.x + pinchPoint2.x) * 0.5,
                                          y: (pinchPoint1.y + pinchPoint2.y) * 0.5)
                
                let lastOffsetCount = Int(centerPoint.x / (configuration.klineSpace + lastKLineWidth))
                let newOffsetCount = Int(centerPoint.x / (configuration.klineSpace + configuration.klineWidth))
                
                lastOffsetIndex = newOffsetCount - lastOffsetCount
                
            }
            drawKLineView(false)
            lastOffsetIndex = nil
        }
    }
    
    // MARK: 长按手势
    @objc
    private func longPressAction(_ recognizer: UILongPressGestureRecognizer) {
        
        OKPrint(recognizer.view)
        
        if recognizer.state == .began || recognizer.state == .changed {
            
            let location = recognizer.location(in: recognizer.view)
            
            if location.x <= 0 { return }
            
            let unit = configuration.klineWidth + configuration.klineSpace
            
            let offsetCount: Int = Int(location.x / unit)
            let previousOffset: CGFloat = (CGFloat(offsetCount) + 0.5) * unit + contentViewLeading
            let nextOffset: CGFloat = (CGFloat(offsetCount + 1) + 0.5) * unit + contentViewLeading
            
            /// 显示竖线
            indicatorVerticalView.isHidden = false
            indicatorHorizontalView.isHidden = false
            
            var drawModel: OKKLineModel?
            
            indicatorHorizontalView.snp.updateConstraints({ (make) in
                make.top.equalTo(location.y)
            })
            
            if abs(previousOffset - location.x) < abs(nextOffset - location.x) {
                
                indicatorVerticalView.snp.updateConstraints({ (make) in
                    make.leading.equalTo(previousOffset)
                })

                if configuration.dataSource.drawKLineModels.count > offsetCount {
                    drawModel = configuration.dataSource.drawKLineModels[offsetCount]
                }
                
            } else {
                indicatorVerticalView.snp.updateConstraints({ (make) in
                    make.leading.equalTo(nextOffset)
                })
                if configuration.dataSource.drawKLineModels.count > offsetCount {
                    drawModel = configuration.dataSource.drawKLineModels[offsetCount + 1]
                }
                
            }
            
            mainView.drawAssistView(model: drawModel)
            volumeView.drawVolumeAssistView(model: drawModel)
            accessoryView.drawAssistView(model: drawModel)
            
        } else if recognizer.state == .ended {
            // 隐藏竖线
            indicatorVerticalView.isHidden = true
            indicatorHorizontalView.isHidden = true
            
            mainView.drawAssistView(model: nil)
            volumeView.drawVolumeAssistView(model: nil)
            accessoryView.drawAssistView(model: nil)
        }
    }
    
    // MARK: 双击手势
    @objc
    private func tapGestureAction(_ recognizer: UITapGestureRecognizer) {
        doubleTapHandle?()
    }
    
    // An empty implementation adversely affects performance during animation.
    //    override func draw(_ rect: CGRect) {
    //        super.draw(rect)
    //        let context = UIGraphicsGetCurrentContext()
    //        context?.setStrokeColor(UIColor.white.cgColor)
    //        context?.setLineWidth(1.0)
    //        
    //        context?.strokeLineSegments(between: [CGPoint(x: rect.mindex, y: rect.minY), CGPoint(x: rect.mindex, y: rect.maxY)])
    //        context?.strokePath()
    //    }
    
}
