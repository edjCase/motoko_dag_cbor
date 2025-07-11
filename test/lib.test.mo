import DagCbor "../src";
import Cbor "mo:cbor";
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import { test } "mo:test";
import FloatX "mo:xtended-numbers/FloatX";

// Test helper to verify that encoded DAG-CBOR can be decoded as CBOR AND optionally round-trip back to DAG-CBOR
func testDagToCborMap(value : DagCbor.Value, expectedCborValue : Cbor.Value, description : Text, testRoundTrip : Bool) {

  let actualCborValue = switch (DagCbor.toCbor(value)) {
    case (#ok(cborValue)) cborValue;
    case (#err(e)) Debug.trap("Encoding failed for " # description # ": " # debug_show (e));
  };

  if (actualCborValue != expectedCborValue) {
    Debug.trap(
      "Invalid CBOR structure for " # description #
      "\nExpected: " # debug_show (expectedCborValue) #
      "\nActual:   " # debug_show (actualCborValue)
    );
  };

  // Test round-trip: CBOR -> DAG-CBOR should give us back the original value (if requested)
  if (testRoundTrip) {
    let roundTripValue = switch (DagCbor.fromCbor(actualCborValue)) {
      case (#ok(dagValue)) dagValue;
      case (#err(e)) Debug.trap("Round-trip fromCbor failed for " # description # ": " # debug_show (e));
    };

    if (roundTripValue != value) {
      Debug.trap(
        "Round-trip failed for " # description #
        "\nOriginal: " # debug_show (value) #
        "\nRound-trip: " # debug_show (roundTripValue)
      );
    };
  };
};

test(
  "DAG-CBOR Integer Encoding",
  func() {
    // Positive integers -> majorType0
    testDagToCborMap(
      #int(0),
      #majorType0(0),
      "zero",
      true,
    );

    testDagToCborMap(
      #int(1),
      #majorType0(1),
      "positive small",
      true,
    );

    testDagToCborMap(
      #int(23),
      #majorType0(23),
      "positive boundary",
      true,
    );

    testDagToCborMap(
      #int(100),
      #majorType0(100),
      "positive medium",
      true,
    );

    // Negative integers -> majorType1
    testDagToCborMap(
      #int(-1),
      #majorType1(-1),
      "negative one",
      true,
    );

    testDagToCborMap(
      #int(-10),
      #majorType1(-10),
      "negative small",
      true,
    );

    testDagToCborMap(
      #int(-100),
      #majorType1(-100),
      "negative medium",
      true,
    );
  },
);

test(
  "DAG-CBOR Bytes Encoding",
  func() {
    // Empty bytes
    testDagToCborMap(
      #bytes([]),
      #majorType2([]),
      "empty bytes",
      true,
    );

    // Small byte array
    testDagToCborMap(
      #bytes([0x01, 0x02, 0x03, 0x04]),
      #majorType2([0x01, 0x02, 0x03, 0x04]),
      "small bytes",
      true,
    );

    // Single byte
    testDagToCborMap(
      #bytes([0xFF]),
      #majorType2([0xFF]),
      "single byte",
      true,
    );
  },
);

test(
  "DAG-CBOR Text Encoding",
  func() {
    // Empty string
    testDagToCborMap(
      #text(""),
      #majorType3(""),
      "empty text",
      true,
    );

    // Simple string
    testDagToCborMap(
      #text("hello"),
      #majorType3("hello"),
      "simple text",
      true,
    );

    // UTF-8 string
    testDagToCborMap(
      #text("IETF"),
      #majorType3("IETF"),
      "ASCII text",
      true,
    );

    // Unicode string
    testDagToCborMap(
      #text("\u{00fc}"),
      #majorType3("\u{00fc}"),
      "unicode text",
      true,
    );
  },
);

test(
  "DAG-CBOR Array Encoding",
  func() {
    // Empty array
    testDagToCborMap(
      #array([]),
      #majorType4([]),
      "empty array",
      true,
    );

    // Simple array
    testDagToCborMap(
      #array([#int(1), #int(2), #int(3)]),
      #majorType4([#majorType0(1), #majorType0(2), #majorType0(3)]),
      "simple integer array",
      true,
    );

    // Mixed type array
    testDagToCborMap(
      #array([#int(1), #text("hello"), #bool(true)]),
      #majorType4([#majorType0(1), #majorType3("hello"), #majorType7(#bool(true))]),
      "mixed type array",
      true,
    );

    // Nested array
    testDagToCborMap(
      #array([#int(1), #array([#int(2), #int(3)])]),
      #majorType4([#majorType0(1), #majorType4([#majorType0(2), #majorType0(3)])]),
      "nested array",
      true,
    );
  },
);

test(
  "DAG-CBOR Map Encoding",
  func() {
    // Empty map
    testDagToCborMap(
      #map([]),
      #majorType5([]),
      "empty map",
      true,
    );

    // Simple map
    testDagToCborMap(
      #map([("a", #int(1)), ("b", #int(2))]),
      #majorType5([(#majorType3("a"), #majorType0(1)), (#majorType3("b"), #majorType0(2))]),
      "simple map",
      true,
    );

    // Map with mixed values
    testDagToCborMap(
      #map([("name", #text("Alice")), ("age", #int(30)), ("active", #bool(true))]),
      #majorType5([
        (#majorType3("age"), #majorType0(30)),
        (#majorType3("name"), #majorType3("Alice")),
        (#majorType3("active"), #majorType7(#bool(true))),
      ]),
      "mixed value map (should be sorted)",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Map Key Sorting",
  func() {
    // Test length-first sorting
    testDagToCborMap(
      #map([("bb", #int(2)), ("a", #int(1)), ("ccc", #int(3))]),
      #majorType5([
        (#majorType3("a"), #majorType0(1)), // length 1
        (#majorType3("bb"), #majorType0(2)), // length 2
        (#majorType3("ccc"), #majorType0(3)) // length 3
      ]),
      "length-first sorting",
      false, // Skip round-trip because keys are sorted
    );

    // Test lexicographic sorting for same length
    testDagToCborMap(
      #map([("ac", #int(1)), ("ab", #int(2)), ("aa", #int(3))]),
      #majorType5([
        (#majorType3("aa"), #majorType0(3)), // lexicographically first
        (#majorType3("ab"), #majorType0(2)), // lexicographically second
        (#majorType3("ac"), #majorType0(1)) // lexicographically third
      ]),
      "lexicographic sorting same length",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR CID Encoding",
  func() {
    // Test CID encoding with tag 42

    testDagToCborMap(
      #cid(
        #v1({
          codec = #dag_cbor;
          hashAlgorithm = #sha2_256;
          hash = "\7a\2f\d4\8e\9c\b1\35\67\f2\a8\1d\4c\e6\90\23\b7\5e\71\89\a3\0f\c4\d2\56\8b\e9\17\42\68\af\93\1c";
        })
      ),
      #majorType6({
        tag = 42;
        value = #majorType2([1, 113, 18, 32, 122, 47, 212, 142, 156, 177, 53, 103, 242, 168, 29, 76, 230, 144, 35, 183, 94, 113, 137, 163, 15, 196, 210, 86, 139, 233, 23, 66, 104, 175, 147, 28]);
      }),
      "CID with tag 42",
      true,
    );
  },
);

test(
  "DAG-CBOR Boolean Encoding",
  func() {
    // Test true
    testDagToCborMap(
      #bool(true),
      #majorType7(#bool(true)),
      "boolean true",
      true,
    );

    // Test false
    testDagToCborMap(
      #bool(false),
      #majorType7(#bool(false)),
      "boolean false",
      true,
    );
  },
);

test(
  "DAG-CBOR Null Encoding",
  func() {
    testDagToCborMap(
      #null_,
      #majorType7(#_null),
      "null value",
      true,
    );
  },
);

test(
  "DAG-CBOR Float Encoding",
  func() {
    // Test simple float
    testDagToCborMap(
      #float(1.5),
      #majorType7(#float(FloatX.fromFloat(1.5, #f64))),
      "simple float",
      true,
    );

    // Test zero float
    testDagToCborMap(
      #float(0.0),
      #majorType7(#float(FloatX.fromFloat(0.0, #f64))),
      "zero float",
      true,
    );

    // Test negative float
    testDagToCborMap(
      #float(-3.14),
      #majorType7(#float(FloatX.fromFloat(-3.14, #f64))),
      "negative float",
      true,
    );
  },
);

test(
  "DAG-CBOR Complex Structure",
  func() {
    // Test a complex nested structure
    let complexValue : DagCbor.Value = #map([
      ("metadata", #map([("version", #int(1)), ("created", #text("2024-01-01"))])),
      ("data", #array([#int(1), #int(2), #map([("nested", #bool(true))])])),
      (
        "cid",
        #cid(
          #v1({
            codec = #dag_cbor;
            hashAlgorithm = #sha2_256;
            hash = "\7a\2f\d4\8e\9c\b1\35\67\f2\a8\1d\4c\e6\90\23\b7\5e\71\89\a3\0f\c4\d2\56\8b\e9\17\42\68\af\93\1c";
          })
        ),
      ),
    ]);

    // This should encode properly and be decodable as CBOR
    let buffer = Buffer.Buffer<Nat8>(100);
    let result = DagCbor.toBytesBuffer(buffer, complexValue);

    switch (result) {
      case (#ok(_)) {
        let bytes = Buffer.toArray(buffer);
        // Verify it can be decoded as valid CBOR
        switch (Cbor.fromBytes(bytes.vals())) {
          case (#ok(_)) {
            // Success - the complex structure encoded correctly
          };
          case (#err(e)) {
            Debug.trap("Complex structure failed CBOR decode: " # debug_show (e));
          };
        };
      };
      case (#err(e)) {
        Debug.trap("Complex structure encoding failed: " # debug_show (e));
      };
    };
  },
);

// Helper function for testing expected encoding failures
func testDagEncodingFailure(value : DagCbor.Value, expectedError : DagCbor.DagEncodingError, description : Text) {
  let buffer = Buffer.Buffer<Nat8>(10);
  let result = DagCbor.toBytesBuffer(buffer, value);

  switch (result) {
    case (#ok(_)) {
      Debug.trap("Expected encoding failure for " # description # " but encoding succeeded");
    };
    case (#err(actualError)) {
      // Check if we got the expected type of error
      let errorMatches = switch (expectedError, actualError) {
        case (#invalidMapKey(_), #invalidMapKey(_)) true;
        case (#invalidValue(_), #invalidValue(_)) true;
        case (#unsortedMapKeys, #unsortedMapKeys) true;
        case (#cborEncodingError(_), #cborEncodingError(_)) true;
        case (_, _) false;
      };

      if (not errorMatches) {
        Debug.trap(
          "Expected error " # debug_show (expectedError) # " for " # description #
          " but got " # debug_show (actualError)
        );
      };
    };
  };
};

test(
  "DAG-CBOR Duplicate Key Errors",
  func() {
    // Test duplicate keys should fail
    testDagEncodingFailure(
      #map([("key", #int(1)), ("key", #int(2))]),
      #invalidMapKey("dummy"),
      "duplicate keys",
    );
  },
);

test(
  "DAG-CBOR Multiple Duplicate Keys",
  func() {
    // Test multiple duplicate keys
    testDagEncodingFailure(
      #map([
        ("a", #int(1)),
        ("b", #int(2)),
        ("a", #int(3)),
        ("c", #int(4)),
      ]),
      #invalidMapKey("dummy"),
      "multiple duplicate keys",
    );
  },
);

test(
  "DAG-CBOR Nested Structure with Duplicate Keys",
  func() {
    // Test that duplicate keys fail even in nested structures
    testDagEncodingFailure(
      #map([
        ("outer", #map([("inner", #int(1)), ("inner", #int(2))])),
        ("valid", #int(3)),
      ]),
      #invalidMapKey("dummy"),
      "duplicate keys in nested map",
    );
  },
);

test(
  "DAG-CBOR Empty String Key Edge Case",
  func() {
    // Test empty string as key (should be valid)
    testDagToCborMap(
      #map([("", #int(1)), ("a", #int(2))]),
      #majorType5([
        (#majorType3(""), #majorType0(1)), // empty string length 0
        (#majorType3("a"), #majorType0(2)) // "a" length 1
      ]),
      "empty string key should be valid and sort first",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Unicode Key Sorting",
  func() {
    // Test unicode keys are sorted by byte representation, not logical characters
    testDagToCborMap(
      #map([("é", #int(1)), ("e", #int(2)), ("f", #int(3))]),
      #majorType5([
        (#majorType3("e"), #majorType0(2)), // "e" = [0x65] (1 byte)
        (#majorType3("f"), #majorType0(3)), // "f" = [0x66] (1 byte)
        (#majorType3("é"), #majorType0(1)) // "é" = [0xC3, 0xA9] (2 bytes)
      ]),
      "unicode keys sorted by byte length then lexicographic",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Large Map Key Ordering",
  func() {
    // Test with many keys to ensure sorting is stable and correct
    testDagToCborMap(
      #map([
        ("zebra", #int(1)),
        ("a", #int(2)),
        ("apple", #int(3)),
        ("bb", #int(4)),
        ("aardvark", #int(5)),
        ("z", #int(6)),
      ]),
      #majorType5([
        (#majorType3("a"), #majorType0(2)), // length 1
        (#majorType3("z"), #majorType0(6)), // length 1
        (#majorType3("bb"), #majorType0(4)), // length 2
        (#majorType3("apple"), #majorType0(3)), // length 5
        (#majorType3("zebra"), #majorType0(1)), // length 5 (lexicographically after "apple")
        (#majorType3("aardvark"), #majorType0(5)) // length 8
      ]),
      "large map with mixed key lengths",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Very Long Key",
  func() {
    // Test with a very long key to ensure no buffer issues
    let longKey = "this_is_a_very_long_key_name_that_should_still_work_correctly_in_dag_cbor_encoding";
    testDagToCborMap(
      #map([(longKey, #int(42)), ("short", #int(1))]),
      #majorType5([
        (#majorType3("short"), #majorType0(1)), // length 5
        (#majorType3(longKey), #majorType0(42)) // much longer
      ]),
      "very long key should sort after shorter keys",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Mixed Array with All Types",
  func() {
    // Test array containing all possible DAG-CBOR types

    testDagToCborMap(
      #array([
        #int(42),
        #int(-17),
        #bytes([0xDE, 0xAD, 0xBE, 0xEF]),
        #text("hello world"),
        #array([#int(1), #int(2)]),
        #map([("nested", #bool(true))]),
        #cid(
          #v1({
            codec = #dag_cbor;
            hashAlgorithm = #sha2_256;
            hash = "\7a\2f\d4\8e\9c\b1\35\67\f2\a8\1d\4c\e6\90\23\b7\5e\71\89\a3\0f\c4\d2\56\8b\e9\17\42\68\af\93\1c";
          })
        ),
        #bool(false),
        #null_,
        #float(3.14159),
      ]),
      #majorType4([
        #majorType0(42),
        #majorType1(-17),
        #majorType2([0xDE, 0xAD, 0xBE, 0xEF]),
        #majorType3("hello world"),
        #majorType4([#majorType0(1), #majorType0(2)]),
        #majorType5([(#majorType3("nested"), #majorType7(#bool(true)))]),
        #majorType6({
          tag = 42;
          value = #majorType2([1, 113, 18, 32, 122, 47, 212, 142, 156, 177, 53, 103, 242, 168, 29, 76, 230, 144, 35, 183, 94, 113, 137, 163, 15, 196, 210, 86, 139, 233, 23, 66, 104, 175, 147, 28]);
        }),
        #majorType7(#bool(false)),
        #majorType7(#_null),
        #majorType7(#float(FloatX.fromFloat(3.14159, #f64))),
      ]),
      "mixed array with all DAG-CBOR types",
      true,
    );
  },
);

test(
  "DAG-CBOR Case Sensitive Key Sorting",
  func() {
    // Test that uppercase/lowercase affects byte sorting
    testDagToCborMap(
      #map([("Z", #int(1)), ("a", #int(2)), ("A", #int(3))]),
      #majorType5([
        (#majorType3("A"), #majorType0(3)), // "A" = [0x41]
        (#majorType3("Z"), #majorType0(1)), // "Z" = [0x5A]
        (#majorType3("a"), #majorType0(2)) // "a" = [0x61]
      ]),
      "case sensitive sorting (uppercase first)",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Numbers vs Strings Sorting",
  func() {
    // Test edge case with numeric-looking strings
    testDagToCborMap(
      #map([("10", #int(1)), ("2", #int(2)), ("1", #int(3))]),
      #majorType5([
        (#majorType3("1"), #majorType0(3)), // "1" length 1
        (#majorType3("2"), #majorType0(2)), // "2" length 1
        (#majorType3("10"), #majorType0(1)) // "10" length 2
      ]),
      "numeric strings sorted by length then lexicographic",
      false, // Skip round-trip because keys are sorted
    );
  },
);

test(
  "DAG-CBOR Special Characters in Keys",
  func() {
    // Test special characters and symbols
    testDagToCborMap(
      #map([("@", #int(1)), ("!", #int(2)), ("~", #int(3)), ("0", #int(4))]),
      #majorType5([
        (#majorType3("!"), #majorType0(2)), // "!" = [0x21]
        (#majorType3("0"), #majorType0(4)), // "0" = [0x30]
        (#majorType3("@"), #majorType0(1)), // "@" = [0x40]
        (#majorType3("~"), #majorType0(3)) // "~" = [0x7E]
      ]),
      "special characters sorted by byte value",
      false, // Skip round-trip because keys are sorted
    );
  },
);

// Helper function for testing expected fromCbor failures
func testFromCborFailure(cborValue : Cbor.Value, expectedErrorType : Text, description : Text) {
  let result = DagCbor.fromCbor(cborValue);

  switch (result) {
    case (#ok(_)) {
      Debug.trap("Expected fromCbor failure for " # description # " but conversion succeeded");
    };
    case (#err(actualError)) {
      let errorMatches = switch (expectedErrorType, actualError) {
        case ("invalidTag", #invalidTag(_)) true;
        case ("invalidMapKey", #invalidMapKey(_)) true;
        case ("invalidCIDFormat", #invalidCIDFormat(_)) true;
        case ("unsupportedPrimitive", #unsupportedPrimitive(_)) true;
        case ("floatConversionError", #floatConversionError(_)) true;
        case ("integerOutOfRange", #integerOutOfRange(_)) true;
        case (_, _) false;
      };

      if (not errorMatches) {
        Debug.trap(
          "Expected error type " # expectedErrorType # " for " # description #
          " but got " # debug_show (actualError)
        );
      };
    };
  };
};

// Helper function for testing expected decode failures
func testDecodeFailure(bytes : [Nat8], expectedErrorType : Text, description : Text) {
  let result = DagCbor.fromBytes(bytes.vals());

  switch (result) {
    case (#ok(_)) {
      Debug.trap("Expected decode failure for " # description # " but decoding succeeded");
    };
    case (#err(actualError)) {
      let errorMatches = switch (expectedErrorType, actualError) {
        case ("cborDecodingError", #cborDecodingError(_)) true;
        case ("invalidTag", #invalidTag(_)) true;
        case ("invalidMapKey", #invalidMapKey(_)) true;
        case ("invalidCIDFormat", #invalidCIDFormat(_)) true;
        case ("unsupportedPrimitive", #unsupportedPrimitive(_)) true;
        case ("floatConversionError", #floatConversionError(_)) true;
        case (_, _) false;
      };

      if (not errorMatches) {
        Debug.trap(
          "Expected error type " # expectedErrorType # " for " # description #
          " but got " # debug_show (actualError)
        );
      };
    };
  };
};

test(
  "DAG-CBOR fromCbor Invalid Tag Errors",
  func() {
    // Test invalid tag (not 42)
    testFromCborFailure(
      #majorType6({
        tag = 41;
        value = #majorType2([0x00, 0x01, 0x02]);
      }),
      "invalidTag",
      "tag 41 should be rejected",
    );

    testFromCborFailure(
      #majorType6({
        tag = 43;
        value = #majorType2([0x00, 0x01, 0x02]);
      }),
      "invalidTag",
      "tag 43 should be rejected",
    );

    testFromCborFailure(
      #majorType6({
        tag = 0;
        value = #majorType2([0x00, 0x01, 0x02]);
      }),
      "invalidTag",
      "tag 0 should be rejected",
    );
  },
);

test(
  "DAG-CBOR fromCbor Invalid Map Key Errors",
  func() {
    // Test non-string map keys
    testFromCborFailure(
      #majorType5([
        (#majorType0(123), #majorType0(456)) // integer key
      ]),
      "invalidMapKey",
      "integer map key should be rejected",
    );

    testFromCborFailure(
      #majorType5([
        (#majorType3("valid"), #majorType0(1)),
        (#majorType2([0x01, 0x02]), #majorType0(2)) // bytes key
      ]),
      "invalidMapKey",
      "bytes map key should be rejected",
    );

    testFromCborFailure(
      #majorType5([
        (#majorType7(#bool(true)), #majorType0(1)) // boolean key
      ]),
      "invalidMapKey",
      "boolean map key should be rejected",
    );
  },
);

// TODO
// test(
//   "DAG-CBOR fromCbor Invalid CID Format Errors",
//   func() {

//     // Test empty CID
//     testFromCborFailure(
//       #majorType6({
//         tag = 42;
//         value = #majorType2([]); // empty bytes
//       }),
//       "invalidCIDFormat",
//       "empty CID should be rejected",
//     );

//     // Test CID with only multibase prefix
//     testFromCborFailure(
//       #majorType6({
//         tag = 42;
//         value = #majorType2([0x00]); // only prefix, no CID data
//       }),
//       "invalidCIDFormat",
//       "CID with only multibase prefix should be rejected",
//     );

//     // Test tag 42 with non-bytes value
//     testFromCborFailure(
//       #majorType6({
//         tag = 42;
//         value = #majorType3("not bytes"); // text instead of bytes
//       }),
//       "invalidCIDFormat",
//       "tag 42 with text value should be rejected",
//     );

//     testFromCborFailure(
//       #majorType6({
//         tag = 42;
//         value = #majorType0(123); // integer instead of bytes
//       }),
//       "invalidCIDFormat",
//       "tag 42 with integer value should be rejected",
//     );
//   },
// );

test(
  "DAG-CBOR fromCbor Unsupported Primitive Errors",
  func() {
    // Note: We need to test unsupported primitives, but the CBOR library may not expose all of them
    // This test may need to be adjusted based on what primitives are available in the CBOR library

    // Test would go here if we had access to unsupported primitives like undefined
    // For now, we'll test what we can with available primitives
  },
);

test(
  "DAG-CBOR decode Round-trip Tests",
  func() {
    // Test round-trip: DAG-CBOR -> bytes -> DAG-CBOR
    let testValues : [DagCbor.Value] = [
      #int(42),
      #int(-17),
      #bytes([0xDE, 0xAD, 0xBE, 0xEF]),
      #text("hello world"),
      #array([#int(1), #text("test"), #bool(true)]),
      #map([("key1", #int(1)), ("key2", #text("value"))]),
      #cid(
        #v1({
          codec = #dag_cbor;
          hashAlgorithm = #sha2_256;
          hash = "\7a\2f\d4\8e\9c\b1\35\67\f2\a8\1d\4c\e6\90\23\b7\5e\71\89\a3\0f\c4\d2\56\8b\e9\17\42\68\af\93\1c";
        })
      ),
      #bool(true),
      #bool(false),
      #null_,
      #float(3.14159),
    ];

    for (originalValue in testValues.vals()) {
      // Encode to bytes
      let encodedBytes = switch (DagCbor.toBytes(originalValue)) {
        case (#ok(bytes)) bytes;
        case (#err(e)) Debug.trap("Encoding failed: " # debug_show (e));
      };

      // Decode back to DAG-CBOR
      let decodedValue = switch (DagCbor.fromBytes(encodedBytes.vals())) {
        case (#ok(value)) value;
        case (#err(e)) Debug.trap("Decoding failed: " # debug_show (e));
      };

      // Check if round-trip preserved the value
      if (decodedValue != originalValue) {
        Debug.trap(
          "Round-trip failed" #
          "\nOriginal: " # debug_show (originalValue) #
          "\nDecoded:  " # debug_show (decodedValue)
        );
      };
    };
  },
);

test(
  "DAG-CBOR decode Invalid Bytes",
  func() {
    // Test with invalid CBOR bytes
    testDecodeFailure(
      [0xFF, 0xFF, 0xFF], // Invalid CBOR
      "cborDecodingError",
      "invalid CBOR bytes should fail",
    );

    testDecodeFailure(
      [], // Empty bytes
      "cborDecodingError",
      "empty bytes should fail",
    );

    testDecodeFailure(
      [0x1F], // Incomplete CBOR
      "cborDecodingError",
      "incomplete CBOR should fail",
    );
  },
);

test(
  "DAG-CBOR decode Complex Structure Round-trip",
  func() {
    // Test complex nested structure round-trip
    let complexValue : DagCbor.Value = #map([
      (
        "cid",
        #cid(
          #v1({
            codec = #dag_cbor;
            hashAlgorithm = #sha2_256;
            hash = "\7a\2f\d4\8e\9c\b1\35\67\f2\a8\1d\4c\e6\90\23\b7\5e\71\89\a3\0f\c4\d2\56\8b\e9\17\42\68\af\93\1c";
          })
        ),
      ),
      ("data", #array([#int(1), #int(2), #map([("count", #int(42)), ("nested", #bool(true))])])),
      ("empty", #null_),
      ("score", #float(98.6)),
      ("active", #bool(true)),
      ("metadata", #map([("tags", #array([#text("test"), #text("dag-cbor")])), ("created", #text("2024-01-01")), ("version", #int(1))])),
    ]);

    // Encode to bytes
    let encodedBytes = switch (DagCbor.toBytes(complexValue)) {
      case (#ok(bytes)) bytes;
      case (#err(e)) Debug.trap("Complex encoding failed: " # debug_show (e));
    };

    // Decode back
    let decodedValue = switch (DagCbor.fromBytes(encodedBytes.vals())) {
      case (#ok(value)) value;
      case (#err(e)) Debug.trap("Complex decoding failed: " # debug_show (e));
    };

    // Verify round-trip
    if (decodedValue != complexValue) {
      Debug.trap(
        "Complex round-trip failed" #
        "\nOriginal: " # debug_show (complexValue) #
        "\nDecoded:  " # debug_show (decodedValue)
      );
    };
  },
);

test(
  "DAG-CBOR fromCbor Nested Structure with Errors",
  func() {
    // Test that errors in nested structures are properly caught
    let invalidNestedCbor : Cbor.Value = #majorType5([
      (#majorType3("valid"), #majorType0(1)),
      (#majorType3("invalid"), #majorType5([(#majorType0(123), #majorType0(456)) /* invalid integer key in nested map */])),
    ]);

    testFromCborFailure(
      invalidNestedCbor,
      "invalidMapKey",
      "nested map with invalid key should be rejected",
    );
  },
);

test(
  "DAG-CBOR decode Edge Cases",
  func() {
    // Test decoding of edge case values

    // Very large positive integer (within bounds)
    let largeInt : DagCbor.Value = #int(9223372036854775807); // Max Int64
    let largeIntBytes = switch (DagCbor.toBytes(largeInt)) {
      case (#ok(bytes)) bytes;
      case (#err(e)) Debug.trap("Large int encoding failed: " # debug_show (e));
    };

    let decodedLargeInt = switch (DagCbor.fromBytes(largeIntBytes.vals())) {
      case (#ok(value)) value;
      case (#err(e)) Debug.trap("Large int decoding failed: " # debug_show (e));
    };

    if (decodedLargeInt != largeInt) {
      Debug.trap("Large int round-trip failed");
    };

    // Very large negative integer (within bounds)
    let largeNegInt : DagCbor.Value = #int(-9223372036854775808); // Min Int64
    let largeNegIntBytes = switch (DagCbor.toBytes(largeNegInt)) {
      case (#ok(bytes)) bytes;
      case (#err(e)) Debug.trap("Large negative int encoding failed: " # debug_show (e));
    };

    let decodedLargeNegInt = switch (DagCbor.fromBytes(largeNegIntBytes.vals())) {
      case (#ok(value)) value;
      case (#err(e)) Debug.trap("Large negative int decoding failed: " # debug_show (e));
    };

    if (decodedLargeNegInt != largeNegInt) {
      Debug.trap("Large negative int round-trip failed");
    };
  },
);
