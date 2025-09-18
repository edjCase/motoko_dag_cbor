import ValueExtractor "../src/ValueExtractor";
import Types "../src/Types";
import { test } "mo:test";
import Runtime "mo:core@1/Runtime";
import CID "mo:cid@1";
import Nat8 "mo:core@1/Nat8";
import Blob "mo:core@1/Blob";

// Test helper to create a CID for testing
func createTestCid() : CID.CID {
  // Create a simple V0 CID with a 32-byte hash
  let hashBytes : [Nat8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20];
  let hash = Blob.fromArray(hashBytes);
  #v0({ hash = hash });
};

// Test data for complex nested structures
let testData : Types.Value = #map([
  ("user", #map([("id", #int(123)), ("name", #text("Alice")), ("active", #bool(true)), ("score", #float(95.5)), ("tags", #array([#text("admin"), #text("user")])), ("metadata", #null_), ("avatar", #bytes([0x01, 0x02, 0x03, 0x04])), ("cid", #cid(createTestCid()))])),
  ("numbers", #array([#int(1), #int(2), #int(3)])),
  ("config", #map([("enabled", #bool(false)), ("timeout", #int(-30))])),
]);

test(
  "ValueExtractor.get - simple path",
  func() {
    let result = ValueExtractor.get(testData, "user.name");
    let expected = ?#text("Alice");
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.get - nested path",
  func() {
    let result = ValueExtractor.get(testData, "user.id");
    let expected = ?#int(123);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.get - array index",
  func() {
    let result = ValueExtractor.get(testData, "numbers[1]");
    let expected = ?#int(2);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.get - nested array path",
  func() {
    let result = ValueExtractor.get(testData, "user.tags[0]");
    let expected = ?#text("admin");
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.get - nonexistent path",
  func() {
    let result = ValueExtractor.get(testData, "user.nonexistent");
    let expected = null;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.get - array out of bounds",
  func() {
    let result = ValueExtractor.get(testData, "numbers[10]");
    let expected = null;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNat - valid positive integer",
  func() {
    let result = ValueExtractor.getAsNat(testData, "user.id");
    let expected = #ok(123);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNat - negative integer should fail",
  func() {
    let result = ValueExtractor.getAsNat(testData, "config.timeout");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNat - path not found",
  func() {
    let result = ValueExtractor.getAsNat(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNat - type mismatch",
  func() {
    let result = ValueExtractor.getAsNat(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableNat - valid positive integer",
  func() {
    let result = ValueExtractor.getAsNullableNat(testData, "user.id", false);
    let expected = #ok(?123);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableNat - null value",
  func() {
    let result = ValueExtractor.getAsNullableNat(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableNat - negative integer should fail",
  func() {
    let result = ValueExtractor.getAsNullableNat(testData, "config.timeout", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableNat - path not found",
  func() {
    let result = ValueExtractor.getAsNullableNat(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableNat - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableNat(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsInt - positive integer",
  func() {
    let result = ValueExtractor.getAsInt(testData, "user.id");
    let expected = #ok(123);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsInt - negative integer",
  func() {
    let result = ValueExtractor.getAsInt(testData, "config.timeout");
    let expected = #ok(-30);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsInt - path not found",
  func() {
    let result = ValueExtractor.getAsInt(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsInt - type mismatch",
  func() {
    let result = ValueExtractor.getAsInt(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableInt - positive integer",
  func() {
    let result = ValueExtractor.getAsNullableInt(testData, "user.id", false);
    let expected = #ok(?123);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableInt - negative integer",
  func() {
    let result = ValueExtractor.getAsNullableInt(testData, "config.timeout", false);
    let expected = #ok(?(-30));
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableInt - null value",
  func() {
    let result = ValueExtractor.getAsNullableInt(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableInt - path not found",
  func() {
    let result = ValueExtractor.getAsNullableInt(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableInt - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableInt(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsFloat - from float value",
  func() {
    let result = ValueExtractor.getAsFloat(testData, "user.score");
    let expected = #ok(95.5);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsFloat - from integer value",
  func() {
    let result = ValueExtractor.getAsFloat(testData, "user.id");
    let expected = #ok(123.0);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsFloat - path not found",
  func() {
    let result = ValueExtractor.getAsFloat(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsFloat - type mismatch",
  func() {
    let result = ValueExtractor.getAsFloat(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableFloat - from float value",
  func() {
    let result = ValueExtractor.getAsNullableFloat(testData, "user.score", false);
    let expected = #ok(?95.5);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableFloat - from integer value",
  func() {
    let result = ValueExtractor.getAsNullableFloat(testData, "user.id", false);
    let expected = #ok(?123.0);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableFloat - null value",
  func() {
    let result = ValueExtractor.getAsNullableFloat(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableFloat - path not found",
  func() {
    let result = ValueExtractor.getAsNullableFloat(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableFloat - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableFloat(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBool - true value",
  func() {
    let result = ValueExtractor.getAsBool(testData, "user.active");
    let expected = #ok(true);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBool - false value",
  func() {
    let result = ValueExtractor.getAsBool(testData, "config.enabled");
    let expected = #ok(false);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBool - path not found",
  func() {
    let result = ValueExtractor.getAsBool(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBool - type mismatch",
  func() {
    let result = ValueExtractor.getAsBool(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBool - true value",
  func() {
    let result = ValueExtractor.getAsNullableBool(testData, "user.active", false);
    let expected = #ok(?true);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBool - false value",
  func() {
    let result = ValueExtractor.getAsNullableBool(testData, "config.enabled", false);
    let expected = #ok(?false);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBool - null value",
  func() {
    let result = ValueExtractor.getAsNullableBool(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBool - path not found",
  func() {
    let result = ValueExtractor.getAsNullableBool(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBool - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableBool(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsText - valid text",
  func() {
    let result = ValueExtractor.getAsText(testData, "user.name");
    let expected = #ok("Alice");
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsText - path not found",
  func() {
    let result = ValueExtractor.getAsText(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsText - type mismatch",
  func() {
    let result = ValueExtractor.getAsText(testData, "user.id");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableText - valid text",
  func() {
    let result = ValueExtractor.getAsNullableText(testData, "user.name", false);
    let expected = #ok(?"Alice");
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableText - null value",
  func() {
    let result = ValueExtractor.getAsNullableText(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableText - path not found",
  func() {
    let result = ValueExtractor.getAsNullableText(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableText - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableText(testData, "user.id", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsArray - valid array",
  func() {
    let result = ValueExtractor.getAsArray(testData, "user.tags");
    let expected = #ok([#text("admin"), #text("user")]);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsArray - path not found",
  func() {
    let result = ValueExtractor.getAsArray(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsArray - type mismatch",
  func() {
    let result = ValueExtractor.getAsArray(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableArray - valid array",
  func() {
    let result = ValueExtractor.getAsNullableArray(testData, "user.tags", false);
    let expected = #ok(?[#text("admin"), #text("user")]);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableArray - null value",
  func() {
    let result = ValueExtractor.getAsNullableArray(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableArray - path not found",
  func() {
    let result = ValueExtractor.getAsNullableArray(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableArray - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableArray(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsMap - valid map",
  func() {
    let result = ValueExtractor.getAsMap(testData, "config");
    let expected = #ok([("enabled", #bool(false)), ("timeout", #int(-30))]);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsMap - path not found",
  func() {
    let result = ValueExtractor.getAsMap(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsMap - type mismatch",
  func() {
    let result = ValueExtractor.getAsMap(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableMap - valid map",
  func() {
    let result = ValueExtractor.getAsNullableMap(testData, "config", false);
    let expected = #ok(?[("enabled", #bool(false)), ("timeout", #int(-30))]);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableMap - null value",
  func() {
    let result = ValueExtractor.getAsNullableMap(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableMap - path not found",
  func() {
    let result = ValueExtractor.getAsNullableMap(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableMap - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableMap(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBytes - valid bytes",
  func() {
    let result = ValueExtractor.getAsBytes(testData, "user.avatar");
    let expected = #ok([0x01, 0x02, 0x03, 0x04] : [Nat8]);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBytes - path not found",
  func() {
    let result = ValueExtractor.getAsBytes(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsBytes - type mismatch",
  func() {
    let result = ValueExtractor.getAsBytes(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBytes - valid bytes",
  func() {
    let result = ValueExtractor.getAsNullableBytes(testData, "user.avatar", false);
    let expected = #ok(?([0x01, 0x02, 0x03, 0x04] : [Nat8]));
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBytes - null value",
  func() {
    let result = ValueExtractor.getAsNullableBytes(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBytes - path not found",
  func() {
    let result = ValueExtractor.getAsNullableBytes(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBytes - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableBytes(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsCid - valid CID",
  func() {
    let result = ValueExtractor.getAsCid(testData, "user.cid");
    let expectedCid = createTestCid();
    let expected = #ok(expectedCid);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsCid - path not found",
  func() {
    let result = ValueExtractor.getAsCid(testData, "nonexistent");
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsCid - type mismatch",
  func() {
    let result = ValueExtractor.getAsCid(testData, "user.name");
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableCid - valid CID",
  func() {
    let result = ValueExtractor.getAsNullableCid(testData, "user.cid", false);
    let expectedCid = createTestCid();
    let expected = #ok(?expectedCid);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableCid - null value",
  func() {
    let result = ValueExtractor.getAsNullableCid(testData, "user.metadata", false);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableCid - path not found",
  func() {
    let result = ValueExtractor.getAsNullableCid(testData, "nonexistent", false);
    let expected = #err(#pathNotFound);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableCid - type mismatch",
  func() {
    let result = ValueExtractor.getAsNullableCid(testData, "user.name", false);
    let expected = #err(#typeMismatch);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.isNull - null value",
  func() {
    let result = ValueExtractor.isNull(testData, "user.metadata", false);
    let expected = true;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.isNull - non-null value",
  func() {
    let result = ValueExtractor.isNull(testData, "user.name", false);
    let expected = false;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.isNull - path not found",
  func() {
    let result = ValueExtractor.isNull(testData, "nonexistent", false);
    let expected = false;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);
test(
  "ValueExtractor.isNull - path not found, but allowMissing true",
  func() {
    let result = ValueExtractor.isNull(testData, "nonexistent", true);
    let expected = true;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

// Test wildcard functionality with getWithParts (indirectly through get)
test(
  "ValueExtractor.get - wildcard on map",
  func() {
    // Create test data with multiple items to test wildcards
    let wildcardTestData : Types.Value = #map([("items", #map([("item1", #map([("value", #int(1))])), ("item2", #map([("value", #int(2))])), ("item3", #map([("value", #int(3))]))]))]);

    // This would test wildcard functionality if the path parser supports it
    // For now, just test that we can get the items map
    let result = ValueExtractor.get(wildcardTestData, "items");
    switch (result) {
      case (null) { Runtime.trap("Expected to find items map but got null") };
      case (?#map(_)) { /* Success */ };
      case (?other) {
        Runtime.trap("Expected map but got " # debug_show (other));
      };
    };
  },
);

test(
  "ValueExtractor.get - empty path returns original value",
  func() {
    let result = ValueExtractor.get(testData, "");
    let expected = ?testData;
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

// Test edge cases for array access
test(
  "ValueExtractor.get - array with nested maps",
  func() {
    let nestedData : Types.Value = #array([
      #map([("name", #text("first"))]),
      #map([("name", #text("second"))]),
    ]);

    let result = ValueExtractor.get(nestedData, "[1].name");
    let expected = ?#text("second");
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

// Tests for allowMissing: true behavior
test(
  "ValueExtractor.getAsNullableNat - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableNat(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableInt - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableInt(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableFloat - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableFloat(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBool - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableBool(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableText - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableText(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableArray - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableArray(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableMap - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableMap(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableBytes - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableBytes(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);

test(
  "ValueExtractor.getAsNullableCid - allowMissing: true returns null for missing path",
  func() {
    let result = ValueExtractor.getAsNullableCid(testData, "nonexistent", true);
    let expected = #ok(null);
    if (result != expected) {
      Runtime.trap("Expected " # debug_show (expected) # " but got " # debug_show (result));
    };
  },
);
