import Types "Types";
import Encoder "Encoder";
import ValueExtractor "ValueExtractor";
import PathParser "PathParser";

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
/// import Result "mo:core@1/Result";
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
  public type Value = Types.Value;

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
  public type DagToCborError = Types.DagToCborError;

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
  public type CborToDagError = Types.CborToDagError;

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
  public type DagEncodingError = Types.DagEncodingError;

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
  public type DagDecodingError = Types.DagDecodingError;

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
  public let toBytes = Encoder.toBytes;

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
  public let toBytesBuffer = Encoder.toBytesBuffer;

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
  public let fromBytes = Encoder.fromBytes;

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
  public let toCbor = Encoder.toCbor;

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
  public let fromCbor = Encoder.fromCbor;

  // =============================================================================
  // VALUE EXTRACTION AND PATH PARSING
  // =============================================================================

  /// Error type for value extraction operations.
  /// These errors can occur when accessing values at specific paths within DAG-CBOR structures.
  ///
  /// Error types:
  /// * `#pathNotFound`: The specified path does not exist in the value structure
  /// * `#typeMismatch`: The value at the path is not of the expected type
  ///
  /// Example scenarios:
  /// ```motoko
  /// // #pathNotFound - accessing non-existent key
  /// let result = getAsText(value, "missing.key");
  ///
  /// // #typeMismatch - expecting text but found integer
  /// let result = getAsText(value, "user.age"); // age is an integer
  /// ```
  public type GetAsError = ValueExtractor.GetAsError;

  /// Parses a dot-notation path string into structured path components.
  /// This function converts string paths like "user.name" or "items[0].title"
  /// into an array of path parts for traversing nested DAG-CBOR structures.
  ///
  /// Supported path syntax:
  /// * Dot notation for object keys: `"user.profile.name"`
  /// * Array indexing with brackets: `"items[0]"` or `"data[5].value"`
  /// * Wildcard matching: `"users.*.name"` (matches all user names)
  /// * Mixed notation: `"config.servers[1].host"`
  ///
  /// Parameters:
  /// * `path`: The dot-notation path string to parse
  ///
  /// Returns:
  /// * Array of PathPart components representing the parsed path
  ///
  /// Example:
  /// ```motoko
  /// let parts = parsePath("user.tags[0]");
  /// // Returns: [#key("user"), #key("tags"), #index(0)]
  ///
  /// let wildcardParts = parsePath("users.*.name");
  /// // Returns: [#key("users"), #wildcard, #key("name")]
  /// ```
  public let parsePath = PathParser.parsePath;

  /// Retrieves a value at the specified path within a DAG-CBOR structure.
  /// This function navigates through nested maps and arrays using dot notation
  /// to extract values from complex DAG-CBOR data structures.
  ///
  /// Path syntax:
  /// * Use dots to separate nested keys: `"user.profile.name"`
  /// * Use brackets for array indices: `"items[0]"` or `"data[5].value"`
  /// * Use wildcards to match multiple items: `"users.*.email"`
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `?Value`: The value at the specified path, or null if not found
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([
  ///   ("user", #map([("name", #text("Alice")), ("age", #int(30))]))
  /// ]);
  ///
  /// let name = get(data, "user.name");
  /// // Returns: ?#text("Alice")
  ///
  /// let missing = get(data, "user.email");
  /// // Returns: null
  /// ```
  public let get = ValueExtractor.get;

  /// Extracts a natural number value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a non-negative integer that can be represented as a Nat.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok(Nat)`: Successfully extracted natural number
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a non-negative integer
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("count", #int(42))]);
  /// let result = getAsNat(data, "count");
  /// // Returns: #ok(42)
  ///
  /// let negative = #map([("value", #int(-5))]);
  /// let error = getAsNat(negative, "value");
  /// // Returns: #err(#typeMismatch)
  /// ```
  public let getAsNat = ValueExtractor.getAsNat;

  /// Extracts a natural number value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or a non-negative integer that can be represented as a Nat.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?Nat)`: Successfully extracted optional natural number
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a non-negative integer
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("count", #int(42)), ("optional", #null_)]);
  ///
  /// let result = getAsNullableNat(data, "count", false);
  /// // Returns: #ok(?42)
  ///
  /// let nullValue = getAsNullableNat(data, "optional", false);
  /// // Returns: #ok(null)
  ///
  /// let missing = getAsNullableNat(data, "missing", true);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableNat = ValueExtractor.getAsNullableNat;

  /// Extracts an integer value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is an integer within the valid Int range.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok(Int)`: Successfully extracted integer
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not an integer
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("temperature", #int(-5)), ("count", #int(100))]);
  ///
  /// let temp = getAsInt(data, "temperature");
  /// // Returns: #ok(-5)
  ///
  /// let count = getAsInt(data, "count");
  /// // Returns: #ok(100)
  /// ```
  public let getAsInt = ValueExtractor.getAsInt;

  /// Extracts an integer value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or an integer within the valid Int range.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?Int)`: Successfully extracted optional integer
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or an integer
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("value", #int(-42)), ("nullable", #null_)]);
  ///
  /// let result = getAsNullableInt(data, "value", false);
  /// // Returns: #ok(?(-42))
  ///
  /// let nullValue = getAsNullableInt(data, "nullable", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableInt = ValueExtractor.getAsNullableInt;

  /// Extracts a floating-point number value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a floating-point number or integer that can be converted to Float.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok(Float)`: Successfully extracted floating-point number
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a number
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("pi", #float(3.14159)), ("count", #int(42))]);
  ///
  /// let pi = getAsFloat(data, "pi");
  /// // Returns: #ok(3.14159)
  ///
  /// let converted = getAsFloat(data, "count");
  /// // Returns: #ok(42.0)
  /// ```
  public let getAsFloat = ValueExtractor.getAsFloat;

  /// Extracts a floating-point number value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null, a floating-point number, or integer that can be converted to Float.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?Float)`: Successfully extracted optional floating-point number
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a number
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("value", #float(2.718)), ("nullable", #null_)]);
  ///
  /// let result = getAsNullableFloat(data, "value", false);
  /// // Returns: #ok(?2.718)
  ///
  /// let nullValue = getAsNullableFloat(data, "nullable", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableFloat = ValueExtractor.getAsNullableFloat;

  /// Extracts a boolean value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a boolean (true or false).
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok(Bool)`: Successfully extracted boolean
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a boolean
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("active", #bool(true)), ("disabled", #bool(false))]);
  ///
  /// let active = getAsBool(data, "active");
  /// // Returns: #ok(true)
  ///
  /// let disabled = getAsBool(data, "disabled");
  /// // Returns: #ok(false)
  /// ```
  public let getAsBool = ValueExtractor.getAsBool;

  /// Extracts a boolean value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or a boolean (true or false).
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?Bool)`: Successfully extracted optional boolean
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a boolean
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("enabled", #bool(true)), ("optional", #null_)]);
  ///
  /// let result = getAsNullableBool(data, "enabled", false);
  /// // Returns: #ok(?true)
  ///
  /// let nullValue = getAsNullableBool(data, "optional", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableBool = ValueExtractor.getAsNullableBool;

  /// Extracts a text string value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a UTF-8 encoded text string.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok(Text)`: Successfully extracted text string
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a text string
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("name", #text("Alice")), ("title", #text("Engineer"))]);
  ///
  /// let name = getAsText(data, "name");
  /// // Returns: #ok("Alice")
  ///
  /// let title = getAsText(data, "title");
  /// // Returns: #ok("Engineer")
  /// ```
  public let getAsText = ValueExtractor.getAsText;

  /// Extracts a text string value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or a UTF-8 encoded text string.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?Text)`: Successfully extracted optional text string
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a text string
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("name", #text("Bob")), ("nickname", #null_)]);
  ///
  /// let result = getAsNullableText(data, "name", false);
  /// // Returns: #ok(?"Bob")
  ///
  /// let nullValue = getAsNullableText(data, "nickname", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableText = ValueExtractor.getAsNullableText;

  /// Extracts an array value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is an array of DAG-CBOR values.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok([Value])`: Successfully extracted array of values
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not an array
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("tags", #array([#text("admin"), #text("user")]))]);
  ///
  /// let tags = getAsArray(data, "tags");
  /// // Returns: #ok([#text("admin"), #text("user")])
  /// ```
  public let getAsArray = ValueExtractor.getAsArray;

  /// Extracts an array value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or an array of DAG-CBOR values.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?[Value])`: Successfully extracted optional array of values
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or an array
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("items", #array([#int(1), #int(2)])), ("empty", #null_)]);
  ///
  /// let result = getAsNullableArray(data, "items", false);
  /// // Returns: #ok(?[#int(1), #int(2)])
  ///
  /// let nullValue = getAsNullableArray(data, "empty", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableArray = ValueExtractor.getAsNullableArray;

  /// Extracts a map value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a map (key-value pairs) with text keys.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok([(Text, Value)])`: Successfully extracted map as key-value pairs
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a map
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("config", #map([("debug", #bool(true)), ("port", #int(8080))]))]);
  ///
  /// let config = getAsMap(data, "config");
  /// // Returns: #ok([("debug", #bool(true)), ("port", #int(8080))])
  /// ```
  public let getAsMap = ValueExtractor.getAsMap;

  /// Extracts a map value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or a map (key-value pairs) with text keys.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?([(Text, Value)]))`: Successfully extracted optional map as key-value pairs
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a map
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("settings", #map([("theme", #text("dark"))])), ("optional", #null_)]);
  ///
  /// let result = getAsNullableMap(data, "settings", false);
  /// // Returns: #ok(?[("theme", #text("dark"))])
  ///
  /// let nullValue = getAsNullableMap(data, "optional", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableMap = ValueExtractor.getAsNullableMap;

  /// Extracts a byte array value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a byte array (binary data).
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok([Nat8])`: Successfully extracted byte array
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a byte array
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("data", #bytes([0x01, 0x02, 0x03, 0x04]))]);
  ///
  /// let bytes = getAsBytes(data, "data");
  /// // Returns: #ok([0x01, 0x02, 0x03, 0x04])
  /// ```
  public let getAsBytes = ValueExtractor.getAsBytes;

  /// Extracts a byte array value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or a byte array (binary data).
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?[Nat8])`: Successfully extracted optional byte array
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a byte array
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("binary", #bytes([0xFF, 0xFE])), ("empty", #null_)]);
  ///
  /// let result = getAsNullableBytes(data, "binary", false);
  /// // Returns: #ok(?[0xFF, 0xFE])
  ///
  /// let nullValue = getAsNullableBytes(data, "empty", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableBytes = ValueExtractor.getAsNullableBytes;

  /// Extracts a CID (Content Identifier) value at the specified path.
  /// This function retrieves and validates that the value at the given path
  /// is a valid CID used for content addressing.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  ///
  /// Returns:
  /// * `#ok(CID.CID)`: Successfully extracted CID
  /// * `#err(#pathNotFound)`: Path does not exist
  /// * `#err(#typeMismatch)`: Value is not a CID
  ///
  /// Example:
  /// ```motoko
  /// let cid = #v0({ hash = someHash });
  /// let data = #map([("link", #cid(cid))]);
  ///
  /// let result = getAsCid(data, "link");
  /// // Returns: #ok(cid)
  /// ```
  public let getAsCid = ValueExtractor.getAsCid;

  /// Extracts a CID (Content Identifier) value at the specified path, allowing null values.
  /// This function retrieves and validates that the value at the given path
  /// is either null or a valid CID used for content addressing.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, returns `#ok(null)` for missing paths instead of `#err(#pathNotFound)`
  ///
  /// Returns:
  /// * `#ok(?CID.CID)`: Successfully extracted optional CID
  /// * `#err(#pathNotFound)`: Path does not exist (when allowMissing is false)
  /// * `#err(#typeMismatch)`: Value is not null or a CID
  ///
  /// Example:
  /// ```motoko
  /// let cid = #v0({ hash = someHash });
  /// let data = #map([("reference", #cid(cid)), ("optional", #null_)]);
  ///
  /// let result = getAsNullableCid(data, "reference", false);
  /// // Returns: #ok(?cid)
  ///
  /// let nullValue = getAsNullableCid(data, "optional", false);
  /// // Returns: #ok(null)
  /// ```
  public let getAsNullableCid = ValueExtractor.getAsNullableCid;

  /// Checks if the value at the specified path is null.
  /// This function provides a convenient way to test for null values
  /// without extracting the actual value.
  ///
  /// Parameters:
  /// * `value`: The DAG-CBOR value to search within
  /// * `path`: Dot-notation path string specifying the location
  /// * `allowMissing`: If true, treats missing paths as null; if false, treats them as non-null
  ///
  /// Returns:
  /// * `true`: Value at path exists and is null, OR path is missing and allowMissing is true
  /// * `false`: Value at path exists and is not null, OR path is missing and allowMissing is false
  ///
  /// Example:
  /// ```motoko
  /// let data = #map([("value", #null_), ("name", #text("Alice"))]);
  ///
  /// let isValueNull = isNull(data, "value", false);
  /// // Returns: true (value exists and is null)
  ///
  /// let isNameNull = isNull(data, "name", false);
  /// // Returns: false (value exists but is not null)
  ///
  /// let isMissingNull = isNull(data, "missing", false);
  /// // Returns: false (path missing, allowMissing is false)
  ///
  /// let isMissingTreatedAsNull = isNull(data, "missing", true);
  /// // Returns: true (path missing, allowMissing is true)
  /// ```
  public let isNull = ValueExtractor.isNull;
};
