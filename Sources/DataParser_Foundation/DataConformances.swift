//
//  DataConformances.swift
//  
//
//  Created by Charles Srstka on 6/3/22.
//

import Foundation
import DataParser

extension Data: _ContiguousRegion {
    package func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    package func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

extension Data: _HasContiguousRegions {
    package var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

extension NSData: _HasContiguousRegions {
    package var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

extension DispatchData.Region: _ContiguousRegion {
    package func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    package func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

extension DispatchData: _HasContiguousRegions {
    package var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}
