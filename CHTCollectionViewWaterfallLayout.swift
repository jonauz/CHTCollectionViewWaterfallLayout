//
//  CHTCollectionViewWaterfallLayout.swift
//  PinterestSwift
//
//  Created by Nicholas Tau on 6/30/14.
//  Copyright (c) 2014 Nicholas Tau. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol CHTCollectionViewDelegateWaterfallLayout: UICollectionViewDelegate{
    
    func collectionView (collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    
    @objc optional func collectionView (collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        heightForHeaderInSection section: NSInteger) -> CGFloat
    
    @objc optional func collectionView (collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        heightForFooterInSection section: NSInteger) -> CGFloat
    
    @objc optional func collectionView (collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAtIndex section: NSInteger) -> UIEdgeInsets
    
    @objc optional func collectionView (collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAtIndex section: NSInteger) -> CGFloat
  
    @objc optional func collectionView (collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        columnCountForSection section: NSInteger) -> NSInteger
}

public enum CHTCollectionViewWaterfallLayoutItemRenderDirection : NSInteger{
    case CHTCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst
    case CHTCollectionViewWaterfallLayoutItemRenderDirectionLeftToRight
    case CHTCollectionViewWaterfallLayoutItemRenderDirectionRightToLeft
}

public let CHTCollectionElementKindSectionHeader = "CHTCollectionElementKindSectionHeader"
public let CHTCollectionElementKindSectionFooter = "CHTCollectionElementKindSectionFooter"

public class CHTCollectionViewWaterfallLayout : UICollectionViewLayout{
    public var columnCount : NSInteger{
    didSet{
        invalidateLayout()
    }}
    
    public var minimumColumnSpacing : CGFloat{
    didSet{
        invalidateLayout()
    }}
    
    public var minimumInteritemSpacing : CGFloat{
    didSet{
        invalidateLayout()
    }}
    
    public var headerHeight : CGFloat{
    didSet{
        invalidateLayout()
    }}

    public var footerHeight : CGFloat{
    didSet{
        invalidateLayout()
    }}

    public var sectionInset : UIEdgeInsets{
    didSet{
        invalidateLayout()
    }}
    
    
    public var itemRenderDirection : CHTCollectionViewWaterfallLayoutItemRenderDirection{
    didSet{
        invalidateLayout()
    }}
    
    public weak var delegate : CHTCollectionViewDelegateWaterfallLayout?{
    get{
        return self.collectionView!.delegate as? CHTCollectionViewDelegateWaterfallLayout
    }
    }
    
    private var columnHeights : NSMutableArray
    private var sectionItemAttributes : NSMutableArray
    private var allItemAttributes : NSMutableArray
    private var headersAttributes : NSMutableDictionary
    private var footersAttributes : NSMutableDictionary
    private  var unionRects : NSMutableArray
    private let unionSize = 20
    
    override public init(){
        self.headerHeight = 0.0
        self.footerHeight = 0.0
        self.columnCount = 2
        self.minimumInteritemSpacing = 10
        self.minimumColumnSpacing = 10
        self.sectionInset = UIEdgeInsets.zero
        self.itemRenderDirection =
        CHTCollectionViewWaterfallLayoutItemRenderDirection.CHTCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst

        headersAttributes = NSMutableDictionary()
        footersAttributes = NSMutableDictionary()
        unionRects = NSMutableArray()
        columnHeights = NSMutableArray()
        allItemAttributes = NSMutableArray()
        sectionItemAttributes = NSMutableArray()
        
        super.init()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  
    func columnCountForSection (section : NSInteger) -> NSInteger {
        if let columnCount = self.delegate?.collectionView?(collectionView: self.collectionView!, layout: self, columnCountForSection: section){
            return columnCount
        }else{
            return self.columnCount
        }
    }
    
    func itemWidthInSectionAtIndex (section : NSInteger) -> CGFloat {
        var insets : UIEdgeInsets
        if let sectionInsets = self.delegate?.collectionView?(collectionView: self.collectionView!, layout: self, insetForSectionAtIndex: section){
            insets = sectionInsets
        }else{
            insets = self.sectionInset
        }
        let width:CGFloat = self.collectionView!.bounds.size.width - insets.left-insets.right
        let columnCount = self.columnCountForSection(section: section)
        let spaceColumCount:CGFloat = CGFloat(columnCount-1)
        return floor((width - (spaceColumCount*self.minimumColumnSpacing)) / CGFloat(columnCount))
    }
    
    override public func prepare(){
        super.prepare()
        
        let numberOfSections = self.collectionView!.numberOfSections
        if numberOfSections == 0 {
            return
        }
        
        self.headersAttributes.removeAllObjects()
        self.footersAttributes.removeAllObjects()
        self.unionRects.removeAllObjects()
        self.columnHeights.removeAllObjects()
        self.allItemAttributes.removeAllObjects()
        self.sectionItemAttributes.removeAllObjects()
        
        for section in 0 ..< numberOfSections {
            let columnCount = self.columnCountForSection(section: section)
            let sectionColumnHeights = NSMutableArray(capacity: columnCount)
            for idx in 0 ..< columnCount {
                sectionColumnHeights.add(idx)
            }
            self.columnHeights.add(sectionColumnHeights)
        }
      
        var top : CGFloat = 0.0
        var attributes = UICollectionViewLayoutAttributes()
        
        for section in 0 ..< numberOfSections {
            /*
            * 1. Get section-specific metrics (minimumInteritemSpacing, sectionInset)
            */
            var minimumInteritemSpacing : CGFloat
            if let miniumSpaceing = self.delegate?.collectionView?(collectionView: self.collectionView!, layout: self, minimumInteritemSpacingForSectionAtIndex: section){
                minimumInteritemSpacing = miniumSpaceing
            }else{
                minimumInteritemSpacing = self.minimumColumnSpacing
            }
            
            var sectionInsets :  UIEdgeInsets
            if let insets = self.delegate?.collectionView?(collectionView: self.collectionView!, layout: self, insetForSectionAtIndex: section){
                sectionInsets = insets
            }else{
                sectionInsets = self.sectionInset
            }
            
            let width = self.collectionView!.bounds.size.width - sectionInsets.left - sectionInsets.right
            let columnCount = self.columnCountForSection(section: section)
            let spaceColumCount = CGFloat(columnCount-1)
            let itemWidth = floor((width - (spaceColumCount*self.minimumColumnSpacing)) / CGFloat(columnCount))
            
            /*
            * 2. Section header
            */
            var heightHeader : CGFloat
            if let height = self.delegate?.collectionView?(collectionView: self.collectionView!, layout: self, heightForHeaderInSection: section){
                heightHeader = height
            }else{
                heightHeader = self.headerHeight
            }
            
            if heightHeader > 0 {
                attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: CHTCollectionElementKindSectionHeader, with: IndexPath(row: 0, section: section))
                attributes.frame = CGRect(x: 0, y: top, width: self.collectionView!.bounds.size.width, height: heightHeader)
                self.headersAttributes.setObject(attributes, forKey: (section as NSCopying))
                self.allItemAttributes.add(attributes)
            
                top = attributes.frame.maxY
            }
            top += sectionInsets.top
            for idx in 0 ..< columnCount {
                if let sectionColumnHeights = self.columnHeights[section] as? NSMutableArray {
                    sectionColumnHeights[idx]=top
                }
            }
            
            /*
            * 3. Section items
            */
            let itemCount = self.collectionView!.numberOfItems(inSection: section)
            let itemAttributes = NSMutableArray(capacity: itemCount)

            // Item will be put into shortest column.
            for idx in 0 ..< itemCount {
                let indexPath = IndexPath(item: idx, section: section)
                
                let columnIndex = self.nextColumnIndexForItem(item: idx, section: section)
                let xOffset = sectionInsets.left + (itemWidth + self.minimumColumnSpacing) * CGFloat(columnIndex)
                let yOffset = ((self.columnHeights[section] as AnyObject).object(at: columnIndex) as AnyObject).doubleValue
                let itemSize = self.delegate?.collectionView(collectionView: self.collectionView!, layout: self, sizeForItemAtIndexPath: indexPath as NSIndexPath)
                var itemHeight : CGFloat = 0.0
                if let itemSize = itemSize, itemSize.height > CGFloat(0) && itemSize.width > 0 {
                    itemHeight = floor(itemSize.height*itemWidth/itemSize.width)
                }

                attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.frame = CGRect(x: xOffset, y: CGFloat(yOffset!), width: itemWidth, height: itemHeight)
                itemAttributes.add(attributes)
                self.allItemAttributes.add(attributes)
              
                if let sectionColumnHeights = self.columnHeights[section] as? NSMutableArray {
                    sectionColumnHeights[columnIndex]=attributes.frame.maxY + minimumInteritemSpacing
                }
            }
            self.sectionItemAttributes.add(itemAttributes)
            
            /*
            * 4. Section footer
            */
            var footerHeight : CGFloat = 0.0
            let columnIndex  = self.longestColumnIndexInSection(section: section)
            top = CGFloat(((self.columnHeights[section] as AnyObject).object(at: columnIndex) as AnyObject).floatValue) - minimumInteritemSpacing + sectionInsets.bottom
    
            if let height = self.delegate?.collectionView?(collectionView: self.collectionView!, layout: self, heightForFooterInSection: section){
                footerHeight = height
            }else{
                footerHeight = self.footerHeight
            }
            
            if footerHeight > 0 {
                attributes = UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: CHTCollectionElementKindSectionFooter, with: IndexPath(item: 0, section: section))
                attributes.frame = CGRect(x: 0, y: top, width: self.collectionView!.bounds.size.width, height: footerHeight)
                self.footersAttributes.setObject(attributes, forKey: section as NSCopying)
                self.allItemAttributes.add(attributes)
                top = attributes.frame.maxY
            }
            
            for idx in 0 ..< columnCount {
                if let sectionColumnHeights = self.columnHeights[section] as? NSMutableArray {
                    sectionColumnHeights[idx]=top
                }
            }
        }
        
        var idx = 0
        let itemCounts = self.allItemAttributes.count
        while(idx < itemCounts){
            let rect1 = (self.allItemAttributes.object(at: idx) as AnyObject).frame as CGRect
            idx = min(idx + unionSize, itemCounts) - 1
            let rect2 = (self.allItemAttributes.object(at: idx) as AnyObject).frame as CGRect
            self.unionRects.add(NSValue(cgRect:rect1.union(rect2)))
            idx += 1
        }
    }
    
    public override var collectionViewContentSize: CGSize {
        get {
            let numberOfSections = self.collectionView!.numberOfSections
            if numberOfSections == 0{
                return CGSize.zero
            }
            
            var contentSize = self.collectionView!.bounds.size as CGSize
            let height = (self.columnHeights.lastObject! as AnyObject).firstObject as! NSNumber
            contentSize.height = CGFloat(height.doubleValue)
            return contentSize
        }
    }
    
    public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if indexPath.section >= self.sectionItemAttributes.count {
            return nil
        }
        let list = self.sectionItemAttributes.object(at: indexPath.section) as! NSArray

        if indexPath.item >= list.count {
            return nil;
        }
        return list.object(at: indexPath.item) as? UICollectionViewLayoutAttributes
    }
    
    public override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        var attribute = UICollectionViewLayoutAttributes()
        if elementKind == CHTCollectionElementKindSectionHeader{
            attribute = self.headersAttributes.object(forKey: indexPath.section) as! UICollectionViewLayoutAttributes
        }else if elementKind == CHTCollectionElementKindSectionFooter{
            attribute = self.footersAttributes.object(forKey: indexPath.section) as! UICollectionViewLayoutAttributes
        }
        return attribute
    }
    
    public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var begin = 0, end = self.unionRects.count
        let attrs = NSMutableArray()
        
        for i in 0 ..< end {
            if let unionRect = self.unionRects.object(at: i) as? NSValue {
                if rect.intersects(unionRect.cgRectValue) {
                    begin = i * unionSize;
                    break
                }
            }
        }
        for i in (0 ..< self.unionRects.count).reversed() {
            if let unionRect = self.unionRects.object(at: i) as? NSValue {
                if rect.intersects(unionRect.cgRectValue){
                    end = min((i+1)*unionSize,self.allItemAttributes.count)
                    break
                }
            }
        }
        for i in begin ..< end {
            let attr = self.allItemAttributes.object(at: i) as! UICollectionViewLayoutAttributes
            if rect.intersects(attr.frame) {
                attrs.add(attr)
            }
        }
            
        return NSArray(array: attrs) as? [UICollectionViewLayoutAttributes]
    }
    
    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let oldBounds = self.collectionView!.bounds
        if newBounds.width != oldBounds.width{
            return true
        }
        return false
    }


    /**
    *  Find the shortest column.
    *
    *  @return index for the shortest column
    */
    func shortestColumnIndexInSection (section: NSInteger) -> NSInteger {
        var index = 0
        var shorestHeight = MAXFLOAT
        
        (self.columnHeights[section] as AnyObject).enumerateObjects { (object: Any!, idx: NSInteger, pointer: UnsafeMutablePointer<ObjCBool>) in
            if let height = (object as AnyObject).floatValue {
                if height < shorestHeight {
                    shorestHeight = height
                    index = idx
                }
            }
        }
        return index
    }
    
    /**
    *  Find the longest column.
    *
    *  @return index for the longest column
    */

    func longestColumnIndexInSection (section: NSInteger) -> NSInteger {
        var index = 0
        var longestHeight: CGFloat = 0.0
        
        (self.columnHeights[section] as AnyObject).enumerateObjects { (object: Any!, idx: NSInteger,pointer: UnsafeMutablePointer<ObjCBool>) in
            if let heightValue = (object as AnyObject).floatValue {
                let height = CGFloat(heightValue)
                if height > longestHeight {
                    longestHeight = height
                    index = idx
                }
            }
        }
        return index
    }

    /**
    *  Find the index for the next column.
    *
    *  @return index for the next column
    */
    func nextColumnIndexForItem (item : NSInteger, section: NSInteger) -> Int {
        var index = 0
        let columnCount = self.columnCountForSection(section: section)
        switch (self.itemRenderDirection){
        case .CHTCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst :
            index = self.shortestColumnIndexInSection(section: section)
        case .CHTCollectionViewWaterfallLayoutItemRenderDirectionLeftToRight :
            index = (item%columnCount)
        case .CHTCollectionViewWaterfallLayoutItemRenderDirectionRightToLeft:
            index = (columnCount - 1) - (item % columnCount);
        }
        return index
    }
}
