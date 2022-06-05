//
//  DataConformances.swift
//  
//
//  Created by Charles Srstka on 6/3/22.
//

import Foundation
import Internal

extension Data: _ContiguousRegion {
    public func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    public func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

extension Data: _HasContiguousRegions {
    public var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

extension NSData: _HasContiguousRegions {
    public var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

extension DispatchData.Region: _ContiguousRegion {
    public func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    public func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

extension DispatchData: _HasContiguousRegions {
    public var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}
