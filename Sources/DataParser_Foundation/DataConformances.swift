//
//  DataConformances.swift
//  
//
//  Created by Charles Srstka on 6/3/22.
//

import Foundation
@_spi(DataParserInternal) import DataParser

@_spi(DataParserInternal) extension Data: _ContiguousRegion {
    public func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    public func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

@_spi(DataParserInternal) extension Data: _HasContiguousRegions {
    public var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

@_spi(DataParserInternal) extension NSData: _HasContiguousRegions {
    public var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}

@_spi(DataParserInternal) extension DispatchData.Region: _ContiguousRegion {
    public func startIndex<C>(for collection: C) -> C.Index where C : Collection { self.startIndex as! C.Index }
    public func endIndex<C>(for collection: C) -> C.Index where C : Collection { self.endIndex as! C.Index }
}

@_spi(DataParserInternal) extension DispatchData: _HasContiguousRegions {
    public var contiguousRegions: [_ContiguousRegion] { self.regions.map { $0 } }
}
