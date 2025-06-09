# Motoko DAG-CBOR

[![MOPS](https://img.shields.io/badge/MOPS-dag--cbor-blue)](https://mops.one/dag-cbor)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/yourusername/motoko_dag_cbor/blob/main/LICENSE)

A Motoko implementation of DAG-CBOR (Deterministic CBOR) for encoding and decoding structured data with content addressing support.

## Package

### MOPS

```bash
mops add dag-cbor
```

To set up MOPS package manager, follow the instructions from the [MOPS Site](https://mops.one)

## What is DAG-CBOR?

DAG-CBOR is a strict subset of CBOR (Concise Binary Object Representation) designed for content addressing. It ensures deterministic encoding by enforcing specific rules like sorted map keys, restricted floating-point values, and limited tag usage.

## Supported Features

- **Deterministic encoding/decoding** of structured data
- **Content addressing support** with CID (Content Identifier) integration
- **Type-safe value representation** with comprehensive error handling
- **CBOR compliance** with DAG-CBOR restrictions:
  - Map keys must be strings and sorted lexicographically
  - Only tag 42 allowed (for CIDs)
  - No IEEE 754 special values (NaN, Infinity)
  - 64-bit integers and floats only
- **Streaming support** with buffer-based encoding
- **Full round-trip fidelity** between Motoko types and binary format

## Quick Start

### Example 1: Basic Encoding and Decoding

```motoko
import DagCbor "mo:dag-cbor";
import Debug "mo:base/Debug";

// Create a simple value
let value : DagCbor.Value = #map([
    ("name", #text("Alice")),
    ("age", #int(30)),
    ("active", #bool(true))
]);

// Encode to bytes
let bytes: [Nat8] = switch (DagCbor.encode(value)) {
    case (#err(error)) Debug.trap("Encoding failed: " # debug_show(error));
    case (#ok(bytes)) bytes;
};

// Decode to value
let dagValue : DagCbor.Value = switch (DagCbor.decode(value.vals())) {
    case (#err(error)) Debug.trap("Decoding failed: " # debug_show(error));
    case (#ok(v)) v;
};
```

### Example 2: To/From Cbor Value

````motoko
import DagCbor "mo:dag-cbor";
import Cbor "mo:cbor";

let value : DagCbor.Value = ...;

// Encode to bytes
let cborValue: Cbor.Value = switch (DagCbor.toCbor(value)) {
    case (#err(error)) Debug.trap("toCbor failed: " # debug_show(error));
    case (#ok(v)) v;
};

// Decode to value
let dagValue : DagCbor.Value = switch (DagCbor.fromCbor(cborValue)) {
    case (#err(error)) Debug.trap("fromCbor failed: " # debug_show(error));
    case (#ok(v)) v;
};

## API Reference

### Types

```motoko
// Main value type supporting all DAG-CBOR data types
public type Value = {
    #int : Int;           // Signed integers (64-bit range)
    #bytes : [Nat8];      // Binary data
    #text : Text;         // UTF-8 strings
    #array : [Value];     // Ordered arrays
    #map : [(Text, Value)]; // Key-value maps (keys must be strings, sorted)
    #cid : CID;           // Content Identifiers
    #bool : Bool;         // Boolean values
    #null_;               // Null value
    #float : Float;       // 64-bit floating point (no NaN/Infinity)
};

// Content Identifier type (placeholder)
public type CID = [Nat8];

// DAG-CBOR specific encoding errors
public type DagToCborError = {
    #invalidValue : Text;       // Value violates DAG-CBOR rules
    #invalidMapKey : Text;      // Map key is invalid
    #unsortedMapKeys;           // Map keys are not sorted
};

// DAG-CBOR specific decoding errors
public type CborToDagError = {
    #invalidTag : Nat64;        // Unsupported CBOR tag
    #invalidMapKey : Text;      // Non-string map key
    #invalidCIDFormat : Text;   // Malformed CID
    #unsupportedPrimitive : Text; // Unsupported CBOR primitive
    #floatConversionError : Text; // Invalid float value
    #integerOutOfRange : Text;  // Integer outside 64-bit range
};

// Combined encoding error type
public type DagEncodingError = DagToCborError or {
    #cborEncodingError : Cbor.EncodingError;
};

// Combined decoding error type
public type DagDecodingError = CborToDagError or {
    #cborDecodingError : Cbor.DecodingError;
};
````

### Functions

```motoko
// Encode a DAG-CBOR value to bytes
public func encode(value : Value) : Result.Result<[Nat8], DagEncodingError>;

// Encode a DAG-CBOR value to an existing buffer (for streaming)
public func encodeToBuffer(buffer : Buffer.Buffer<Nat8>, value : Value) : Result.Result<(), DagEncodingError>;

// Decode bytes to a DAG-CBOR value
public func decode(bytes : Iter.Iter<Nat8>) : Result.Result<Value, DagDecodingError>;

// Convert DAG-CBOR value to underlying CBOR value
public func toCbor(value : Value) : Result.Result<Cbor.Value, DagToCborError>;

// Convert underlying CBOR value to DAG-CBOR value
public func fromCbor(cborValue : Cbor.Value) : Result.Result<Value, CborToDagError>;
```

## DAG-CBOR Rules and Restrictions

This implementation enforces the following DAG-CBOR rules:

1. **Map Keys**: Must be strings and sorted lexicographically by UTF-8 byte representation
2. **Tags**: Only tag 42 is allowed (used for CIDs)
3. **Integers**: Must fit in 64-bit signed range (-2^63 to 2^63-1)
4. **Floats**: Must be 64-bit IEEE 754, no NaN, Infinity, or -Infinity
5. **Deterministic Encoding**: Same logical value always produces identical bytes
6. **No Duplicate Keys**: Map keys must be unique

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
