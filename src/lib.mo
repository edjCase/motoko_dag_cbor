import Cbor "mo:cbor";
import Result "mo:core/Result";
import Int "mo:core/Int";
import Nat64 "mo:core/Nat64";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Blob "mo:core/Blob";
import Order "mo:core/Order";
import Iter "mo:core/Iter";
import Float "mo:core/Float";
import Buffer "mo:buffer";
import FloatX "mo:xtended-numbers/FloatX";
import CID "mo:cid";
import MultiBase "mo:multiformats/MultiBase";
import Nat8 "mo:core/Nat8";
import List "mo:core/List";

/// DAG-CBOR (Content-Addressed Data Encoding) library for Motoko.
///
/// This module provides functionality for encoding and decoding DAG-CBOR data,
/// which is a subset of CBOR (Concise Binary Object Representation) designed
/// for content-addressed storage systems like IPFS.
///
/// Key features:
/// * Encode Motoko values to DAG-CBOR binary format
/// * Decode DAG-CBOR binary data to Motoko values
/// * Support for all DAG-CBOR data types (integers, bytes, text, arrays, maps, CIDs, booleans, null, floats)
/// * Strict adherence to DAG-CBOR specification requirements
/// * Proper handling of CID (Content Identifier) values
/// * Map key ordering and validation according to DAG-CBOR rules
///
/// DAG-CBOR is a restricted subset of CBOR that:
/// * Requires deterministic encoding
/// * Enforces lexicographic ordering of map keys
/// * Only allows specific data types
/// * Prohibits certain CBOR features (indefinite length, some tags, etc.)
/// * Supports Content Identifiers (CIDs) as first-class values
///
/// Example usage:
/// ```motoko
/// import DagCbor "mo:dag-cbor";
/// import Result "mo:core/Result";
///
/// // Encode a value to DAG-CBOR bytes
/// let value = #map([("name", #text("Alice")), ("age", #int(30))]);
/// let bytes = DagCbor.toBytes(value);
///
/// // Decode DAG-CBOR bytes back to a value
/// let decoded = DagCbor.fromBytes(bytes.vals());
/// ```
///
/// Security considerations:
/// * Always validate decoded data before use
/// * Be aware of potential memory usage with large nested structures
/// * CID validation is performed during encoding/decoding
module {

  /// Represents a DAG-CBOR value that can be encoded or decoded.
  /// This type encompasses all valid DAG-CBOR data types according to the specification.
  ///
  /// DAG-CBOR supports the following data types:
  /// * `#int`: Signed integers (within 64-bit range)
  /// * `#bytes`: Binary data as byte arrays
  /// * `#text`: UTF-8 encoded text strings
  /// * `#array`: Homogeneous arrays of DAG-CBOR values
  /// * `#map`: Key-value mappings with text keys only
  /// * `#cid`: Content Identifiers for linking to other content
  /// * `#bool`: Boolean values (true/false)
  /// * `#null_`: Null/nil value
  /// * `#float`: IEEE 754 64-bit floating point numbers
  ///
  /// Example usage:
  /// ```motoko
  /// let value : Value = #map([
  ///     ("name", #text("Alice")),
  ///     ("age", #int(30)),
  ///     ("active", #bool(true)),
  ///     ("data", #bytes([1, 2, 3, 4]))
  /// ]);
  /// ```
  ///
  /// Note: Maps must have text keys only and will be sorted lexicographically
  /// during encoding to ensure deterministic output.
  public type Value = {
    #int : Int;
    #bytes : [Nat8];
    #text : Text;
    #array : [Value];
    #map : [(Text, Value)];
    #cid : CID.CID;
    #bool : Bool;
    #null_;
    #float : Float;
  };

  /// Errors that can occur when converting DAG-CBOR values to CBOR format.
  /// These errors indicate violations of DAG-CBOR constraints or invalid data.
  ///
  /// Error types:
  /// * `#invalidValue`: The value cannot be represented in DAG-CBOR format
  /// * `#invalidMapKey`: Map contains non-text keys or invalid key format
  /// * `#unsortedMapKeys`: Map keys are not in the required lexicographic order
  ///
  /// Example scenarios:
  /// ```motoko
  /// // This would cause #invalidValue if integer is too large
  /// let tooLarge = #int(2^65);
  ///
  /// // This would cause #invalidMapKey (non-text key)
  /// let invalidMap = [(123, #text("value"))]; // Should be text key
  /// ```
  public type DagToCborError = {
    #invalidValue : Text;
    #invalidMapKey : Text;
    #unsortedMapKeys;
  };

  /// Errors that can occur when converting CBOR format to DAG-CBOR values.
  /// These errors indicate CBOR data that violates DAG-CBOR constraints.
  ///
  /// Error types:
  /// * `#invalidTag`: CBOR tag is not allowed in DAG-CBOR (only tag 42 for CIDs is permitted)
  /// * `#invalidMapKey`: Map contains non-string keys (DAG-CBOR requires text keys only)
  /// * `#invalidCIDFormat`: CID data is malformed or invalid
  /// * `#unsupportedPrimitive`: CBOR primitive type is not supported in DAG-CBOR
  /// * `#floatConversionError`: Float value cannot be represented (e.g., NaN, Infinity)
  /// * `#integerOutOfRange`: Integer value exceeds DAG-CBOR limits
  ///
  /// Example scenarios:
  /// ```motoko
  /// // CBOR with tag 123 would cause #invalidTag
  /// // CBOR with NaN float would cause #floatConversionError
  /// // CBOR with integer key would cause #invalidMapKey
  /// ```
  public type CborToDagError = {
    #invalidTag : Nat64;
    #invalidMapKey : Text;
    #invalidCIDFormat : Text;
    #unsupportedPrimitive : Text;
    #floatConversionError : Text;
    #integerOutOfRange : Text;
  };

  /// Comprehensive error type for DAG-CBOR encoding operations.
  /// This includes both DAG-CBOR specific errors and underlying CBOR encoding errors.
  ///
  /// This type combines:
  /// * `DagToCborError`: Errors specific to DAG-CBOR validation and conversion
  /// * `#cborEncodingError`: Errors from the underlying CBOR encoding library
  ///
  /// Example usage:
  /// ```motoko
  /// switch (DagCbor.toBytes(value)) {
  ///     case (#ok(bytes)) { /* success */ };
  ///     case (#err(#invalidValue(msg))) { /* handle DAG-CBOR error */ };
  ///     case (#err(#cborEncodingError(err))) { /* handle CBOR error */ };
  /// };
  /// ```
  public type DagEncodingError = DagToCborError or {
    #cborEncodingError : Cbor.EncodingError;
  };

  /// Comprehensive error type for DAG-CBOR decoding operations.
  /// This includes both DAG-CBOR specific errors and underlying CBOR decoding errors.
  ///
  /// This type combines:
  /// * `CborToDagError`: Errors specific to DAG-CBOR validation and conversion
  /// * `#cborDecodingError`: Errors from the underlying CBOR decoding library
  ///
  /// Example usage:
  /// ```motoko
  /// switch (DagCbor.fromBytes(bytes.vals())) {
  ///     case (#ok(value)) { /* success */ };
  ///     case (#err(#invalidTag(tag))) { /* handle DAG-CBOR error */ };
  ///     case (#err(#cborDecodingError(err))) { /* handle CBOR error */ };
  /// };
  /// ```
  public type DagDecodingError = CborToDagError or {
    #cborDecodingError : Cbor.DecodingError;
  };

  /// Encodes a DAG-CBOR value to its binary representation.
  /// This function converts a DAG-CBOR value to its canonical binary format
  /// according to the DAG-CBOR specification.
  ///
  /// The encoding process:
  /// 1. Validates the value conforms to DAG-CBOR constraints
  /// 2. Converts to intermediate CBOR representation
  /// 3. Encodes to binary format using CBOR encoding
  /// 4. Ensures deterministic output (map keys are sorted)
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to encode
  ///
  /// Returns:
  /// * `#ok([Nat8])`: Successfully encoded binary data
  /// * `#err(DagEncodingError)`: Encoding failed with error details
  ///
  /// Example:
  /// ```motoko
  /// let value = #map([("name", #text("Alice")), ("age", #int(30))]);
  /// let result = toBytes(value);
  /// switch (result) {
  ///     case (#ok(bytes)) { /* use bytes */ };
  ///     case (#err(error)) { /* handle error */ };
  /// };
  /// ```
  public func toBytes(value : Value) : Result.Result<[Nat8], DagEncodingError> {
    let buffer = List.empty<Nat8>();
    switch (toBytesBuffer(Buffer.fromList(buffer), value)) {
      case (#ok(_)) #ok(List.toArray(buffer));
      case (#err(e)) #err(e);
    };
  };

  /// Encodes a DAG-CBOR value directly into a provided buffer.
  /// This function is useful for streaming or when you want to manage buffer allocation yourself.
  ///
  /// The encoding process:
  /// 1. Validates the value conforms to DAG-CBOR constraints
  /// 2. Converts to intermediate CBOR representation
  /// 3. Encodes directly into the provided buffer
  /// 4. Returns the count of bytes written
  ///
  /// Parameters:
  /// * `buffer`: The buffer to write encoded data into
  /// * `value`: The DAG-CBOR value to encode
  ///
  /// Returns:
  /// * `#ok`: Successfully encoded
  /// * `#err(DagEncodingError)`: Encoding failed with error details
  ///
  /// Example:
  /// ```motoko
  /// let list = List.empty<Nat8>();
  /// let buffer = Buffer.fromList<Nat8>(list);
  /// let value = #text("Hello, World!");
  /// let result = toBytesBuffer(buffer, value);
  /// switch (result) {
  ///     case (#ok) { /* successfully written to 'list' */ };
  ///     case (#err(error)) { /* handle error */ };
  /// };
  /// ```
  public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, value : Value) : Result.Result<(), DagEncodingError> {
    switch (toCbor(value)) {
      case (#ok(cborValue)) switch (Cbor.toBytesBuffer(buffer, cborValue)) {
        case (#ok) #ok;
        case (#err(e)) #err(#cborEncodingError(e));
      };
      case (#err(e)) #err(e);
    };
  };

  /// Decodes DAG-CBOR binary data into a structured value.
  /// This function takes binary data in DAG-CBOR format and converts it back
  /// to a structured Value that can be used in Motoko.
  ///
  /// The decoding process:
  /// 1. Decodes the binary data using CBOR decoding
  /// 2. Validates the CBOR data conforms to DAG-CBOR constraints
  /// 3. Converts CBOR value to DAG-CBOR Value type
  /// 4. Validates all constraints (map keys, CID format, etc.)
  ///
  /// Parameters:
  /// * `bytes`: Iterator over the binary data to decode
  ///
  /// Returns:
  /// * `#ok(Value)`: Successfully decoded DAG-CBOR value
  /// * `#err(DagDecodingError)`: Decoding failed with error details
  ///
  /// Example:
  /// ```motoko
  /// let bytes = [0x82, 0x01, 0x02]; // CBOR for array [1, 2]
  /// let result = fromBytes(bytes.vals());
  /// switch (result) {
  ///     case (#ok(value)) { /* use decoded value */ };
  ///     case (#err(error)) { /* handle error */ };
  /// };
  /// ```
  public func fromBytes(bytes : Iter.Iter<Nat8>) : Result.Result<Value, DagDecodingError> {
    // First decode using the CBOR library
    switch (Cbor.fromBytes(bytes)) {
      case (#ok(cborValue)) {
        // Then convert CBOR Value to DAG-CBOR Value
        switch (fromCbor(cborValue)) {
          case (#ok(dagValue)) #ok(dagValue);
          case (#err(e)) #err(e);
        };
      };
      case (#err(cborError)) #err(#cborDecodingError(cborError));
    };
  };

  /// Converts a DAG-CBOR value to its intermediate CBOR representation.
  /// This function transforms a DAG-CBOR value into a standard CBOR value
  /// while enforcing all DAG-CBOR constraints and rules.
  ///
  /// The conversion process:
  /// 1. Validates integer ranges (64-bit signed integers)
  /// 2. Ensures map keys are text and properly sorted
  /// 3. Converts CIDs to CBOR tag 42 format
  /// 4. Validates float values (no NaN, Infinity, etc.)
  /// 5. Recursively processes nested structures
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to convert
  ///
  /// Returns:
  /// * `#ok(Cbor.Value)`: Successfully converted CBOR value
  /// * `#err(DagToCborError)`: Conversion failed due to constraint violations
  ///
  /// Example:
  /// ```motoko
  /// let dagValue = #map([("key", #text("value"))]);
  /// let cborResult = toCbor(dagValue);
  /// // Returns CBOR map with properly ordered keys
  /// ```
  public func toCbor(value : Value) : Result.Result<Cbor.Value, DagToCborError> {
    switch (value) {
      case (#int(i)) mapInt(i);
      case (#bytes(b)) mapBytes(b);
      case (#text(t)) mapText(t);
      case (#array(a)) mapArray(a);
      case (#map(m)) mapMap(m);
      case (#cid(c)) mapCID(c);
      case (#bool(b)) mapBool(b);
      case (#null_) mapNull();
      case (#float(f)) mapFloat(f);
    };
  };

  /// Converts a CBOR value to a DAG-CBOR value with validation.
  /// This function takes a standard CBOR value and converts it to a DAG-CBOR value
  /// while enforcing all DAG-CBOR constraints and rejecting invalid constructs.
  ///
  /// The conversion process:
  /// 1. Validates that only allowed CBOR major types are used
  /// 2. Ensures map keys are text strings only
  /// 3. Validates that only tag 42 (CID) is used
  /// 4. Converts CID byte strings to proper CID objects
  /// 5. Validates float values (rejects NaN, Infinity, etc.)
  /// 6. Recursively processes nested structures
  ///
  /// Parameters:
  /// * `cborValue`: The CBOR value to convert and validate
  ///
  /// Returns:
  /// * `#ok(Value)`: Successfully converted and validated DAG-CBOR value
  /// * `#err(CborToDagError)`: Conversion failed due to invalid CBOR or constraint violations
  ///
  /// Example:
  /// ```motoko
  /// let cborValue = #majorType5([(#majorType3("key"), #majorType3("value"))]);
  /// let dagResult = fromCbor(cborValue);
  /// // Returns DAG-CBOR map with validated structure
  /// ```
  public func fromCbor(cborValue : Cbor.Value) : Result.Result<Value, CborToDagError> {
    switch (cborValue) {
      case (#majorType0(n)) #ok(#int(Int.fromNat(Nat64.toNat(n))));
      case (#majorType1(i)) #ok(#int(i));
      case (#majorType2(bytes)) #ok(#bytes(bytes));
      case (#majorType3(text)) #ok(#text(text));
      case (#majorType4(array)) {
        // Array - recursively convert elements
        let dagArray = List.empty<Value>();
        for (item in array.vals()) {
          switch (fromCbor(item)) {
            case (#ok(dagValue)) List.add(dagArray, dagValue);
            case (#err(e)) return #err(e);
          };
        };
        #ok(#array(List.toArray(dagArray)));
      };
      case (#majorType5(map)) {
        // Map - validate string keys and convert values
        let dagMap = List.empty<(Text, Value)>();
        for ((key, value) in map.vals()) {
          // DAG-CBOR requires map keys to be strings only
          let textKey = switch (key) {
            case (#majorType3(text)) text;
            case (_) return #err(#invalidMapKey("Map keys must be strings in DAG-CBOR"));
          };

          // Recursively convert the value
          switch (fromCbor(value)) {
            case (#ok(dagValue)) List.add(dagMap, (textKey, dagValue));
            case (#err(e)) return #err(e);
          };
        };
        #ok(#map(List.toArray(dagMap)));
      };
      case (#majorType6({ tag; value })) {
        // Tagged value - DAG-CBOR only allows tag 42 for CIDs
        if (tag != 42) {
          return #err(#invalidTag(tag));
        };

        // Tag 42 must contain a byte string with multibase identity prefix (0x00)
        switch (value) {
          case (#majorType2(cidEncodedBytes)) {
            let (cidBytes, _) = switch (MultiBase.fromEncodedBytes(cidEncodedBytes.vals())) {
              case (#ok(bytes)) bytes; // Identity multibase is allowed
              case (#err(e)) return #err(#invalidCIDFormat(e));
            };
            switch (CID.fromBytes(cidBytes.vals())) {
              case (#ok(cidValue)) #ok(#cid(cidValue));
              case (#err(e)) return #err(#invalidCIDFormat("Invalid CID format: " # e));
            };
          };
          case (_) return #err(#invalidCIDFormat("CID tag 42 must contain a byte string"));
        };
      };
      case (#majorType7(primitive)) {
        // Primitive values
        switch (primitive) {
          case (#bool(b)) #ok(#bool(b));
          case (#_null) #ok(#null_);
          case (#float(floatX)) {
            // Convert FloatX back to Float
            // DAG-CBOR requires 64-bit floats, so this should be safe
            let f = FloatX.toFloat(floatX);
            // Check for IEEE 754 special values that are not allowed in DAG-CBOR
            if (Float.isNaN(f) or f == (1.0 / 0.0) or f == (-1.0 / 0.0)) {
              return #err(#floatConversionError("IEEE 754 special values (NaN, Infinity, -Infinity) are not allowed in DAG-CBOR"));
            };
            #ok(#float(f));
          };
          case (_) return #err(#unsupportedPrimitive("Unsupported primitive type in DAG-CBOR"));
        };
      };
    };
  };

  func mapInt(value : Int) : Result.Result<Cbor.Value, DagToCborError> {
    if (value >= 0) {
      // Positive integers use majorType0
      let natValue = Int.abs(value);
      if (natValue > 18446744073709551615) {
        return #err(#invalidValue("Integer value out of range for DAG-CBOR, must be <= 2^64 - 1"));
      };
      #ok(#majorType0(Nat64.fromNat(natValue)));
    } else {
      if (value < -18446744073709551616) {
        return #err(#invalidValue("Integer value out of range for DAG-CBOR, must be >= -2^64"));
      };
      #ok(#majorType1(value));
    };
  };

  func mapBytes(value : [Nat8]) : Result.Result<Cbor.Value, DagToCborError> {
    #ok(#majorType2(value));
  };

  func mapText(value : Text) : Result.Result<Cbor.Value, DagToCborError> {
    #ok(#majorType3(value));
  };

  func mapArray(value : [Value]) : Result.Result<Cbor.Value, DagToCborError> {
    let cborArray = List.empty<Cbor.Value>();

    for (item in value.vals()) {
      switch (toCbor(item)) {
        case (#ok(cborValue)) {
          List.add(cborArray, cborValue);
        };
        case (#err(e)) return #err(e);
      };
    };

    #ok(#majorType4(List.toArray(cborArray)));
  };

  func mapMap(value : [(Text, Value)]) : Result.Result<Cbor.Value, DagToCborError> {
    // Validate and sort map keys according to DAG-CBOR rules
    let sortedEntries = sortMapEntries(value);

    // Check for duplicate keys
    switch (checkDuplicateKeys(sortedEntries)) {
      case (#err(e)) return #err(e);
      case (#ok()) {};
    };

    // Convert to CBOR map entries
    let cborEntries = List.empty<(Cbor.Value, Cbor.Value)>();

    for ((key, val) in sortedEntries.vals()) {
      switch (toCbor(val)) {
        case (#ok(cborValue)) {
          let cborKey = #majorType3(key); // Text keys
          List.add(cborEntries, (cborKey, cborValue));
        };
        case (#err(e)) return #err(e);
      };
    };

    #ok(#majorType5(List.toArray(cborEntries)));
  };

  func mapCID(value : CID.CID) : Result.Result<Cbor.Value, DagToCborError> {
    let cidBuffer = List.empty<Nat8>();
    List.add<Nat8>(cidBuffer, 0); // Multibase identity prefix (0x00)
    let _ = CID.toBytesBuffer(Buffer.fromList(cidBuffer), value);
    #ok(
      #majorType6({
        tag = 42; // Only tag 42 is allowed in DAG-CBOR
        value = #majorType2(List.toArray(cidBuffer));
      })
    );
  };

  func mapBool(value : Bool) : Result.Result<Cbor.Value, DagToCborError> {
    #ok(#majorType7(#bool(value)));
  };

  func mapNull() : Result.Result<Cbor.Value, DagToCborError> {
    #ok(#majorType7(#_null));
  };

  func mapFloat(value : Float) : Result.Result<Cbor.Value, DagToCborError> {
    // DAG-CBOR requires 64-bit floats only
    #ok(#majorType7(#float(FloatX.fromFloat(value, #f64))));
  };

  // Helper function to sort map entries according to DAG-CBOR rules
  func sortMapEntries(entries : [(Text, Value)]) : [(Text, Value)] {
    Array.sort(
      entries,
      func((keyA, _) : (Text, Value), (keyB, _) : (Text, Value)) : Order.Order {
        let bytesA = Text.encodeUtf8(keyA);
        let bytesB = Text.encodeUtf8(keyB);

        // First compare by length
        if (bytesA.size() < bytesB.size()) {
          #less;
        } else if (bytesA.size() > bytesB.size()) {
          #greater;
        } else {
          compareEqualSizedBlobs(bytesA, bytesB);
        };
      },
    );
  };

  // Helper function to compare byte arrays lexicographically
  func compareEqualSizedBlobs(a : Blob, b : Blob) : Order.Order {
    assert (a.size() == b.size());
    for (i in Nat.range(0, a.size())) {
      if (a[i] < b[i]) return #less;
      if (a[i] > b[i]) return #greater;
    };
    #equal;
  };

  // Helper function to check for duplicate keys
  func checkDuplicateKeys(entries : [(Text, Value)]) : Result.Result<(), DagToCborError> {
    if (entries.size() <= 1) return #ok();

    for (i in Nat.range(0, entries.size() - 1)) {
      let (keyA, _) = entries[i];
      let (keyB, _) = entries[i + 1];
      if (Text.equal(keyA, keyB)) {
        return #err(#invalidMapKey("Duplicate key: " # keyA));
      };
    };

    #ok();
  };
};
