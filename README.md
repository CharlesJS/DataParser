# DataParser

Provides a quick and easy way to parse byte buffers of raw data.

Can parse integers of arbitrary size and endianness, floating-point values, LEB128-encoded integers, data blobs, and UTF8-encoded strings.

Can parse arrays and tuples of integer types.

Bounds-checks reads to the input data, for safety.
