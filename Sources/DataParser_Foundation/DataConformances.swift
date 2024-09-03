//
//  DataConformances.swift
//  
//
//  Created by Charles Srstka on 6/3/22.
//

import Foundation
import DataParser

extension Data: @retroactive _ContiguousRegion {
    package func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    package func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

extension Data: @retroactive _HasContiguousRegions {
    package var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

extension NSData: @retroactive _HasContiguousRegions {
    package var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

extension DispatchData.Region: @retroactive _ContiguousRegion {
    package func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    package func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

extension DispatchData: @retroactive _HasContiguousRegions {
    package var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}
