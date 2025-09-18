import PathParser "../src/PathParser";
import { test } "mo:test";
import Runtime "mo:core@1/Runtime";

// Test helper to compare PathPart arrays
func assertPathPartsEqual(actual : [PathParser.PathPart], expected : [PathParser.PathPart], description : Text) {
  if (actual.size() != expected.size()) {
    Runtime.trap(
      "Array size mismatch for " # description #
      "\nExpected size: " # debug_show (expected.size()) #
      "\nActual size: " # debug_show (actual.size()) #
      "\nExpected: " # debug_show (expected) #
      "\nActual: " # debug_show (actual)
    );
  };

  for (i in actual.keys()) {
    if (actual[i] != expected[i]) {
      Runtime.trap(
        "PathPart mismatch at index " # debug_show (i) # " for " # description #
        "\nExpected: " # debug_show (expected[i]) #
        "\nActual: " # debug_show (actual[i]) #
        "\nFull expected: " # debug_show (expected) #
        "\nFull actual: " # debug_show (actual)
      );
    };
  };
};

test(
  "PathParser.parsePath - empty path",
  func() {
    let result = PathParser.parsePath("");
    let expected : [PathParser.PathPart] = [];
    assertPathPartsEqual(result, expected, "empty path");
  },
);

test(
  "PathParser.parsePath - single key",
  func() {
    let result = PathParser.parsePath("key");
    let expected : [PathParser.PathPart] = [#key("key")];
    assertPathPartsEqual(result, expected, "single key");
  },
);

test(
  "PathParser.parsePath - single key with dot",
  func() {
    let result = PathParser.parsePath("user.name");
    let expected : [PathParser.PathPart] = [#key("user"), #key("name")];
    assertPathPartsEqual(result, expected, "dot-separated keys");
  },
);

test(
  "PathParser.parsePath - multiple keys with dots",
  func() {
    let result = PathParser.parsePath("user.profile.settings.theme");
    let expected : [PathParser.PathPart] = [
      #key("user"),
      #key("profile"),
      #key("settings"),
      #key("theme"),
    ];
    assertPathPartsEqual(result, expected, "multiple dot-separated keys");
  },
);

test(
  "PathParser.parsePath - single array index",
  func() {
    let result = PathParser.parsePath("[0]");
    let expected : [PathParser.PathPart] = [#index(0)];
    assertPathPartsEqual(result, expected, "single array index");
  },
);

test(
  "PathParser.parsePath - multiple array indices",
  func() {
    let result = PathParser.parsePath("[0][1][2]");
    let expected : [PathParser.PathPart] = [#index(0), #index(1), #index(2)];
    assertPathPartsEqual(result, expected, "multiple array indices");
  },
);

test(
  "PathParser.parsePath - key followed by array index",
  func() {
    let result = PathParser.parsePath("items[0]");
    let expected : [PathParser.PathPart] = [#key("items"), #index(0)];
    assertPathPartsEqual(result, expected, "key followed by array index");
  },
);

test(
  "PathParser.parsePath - complex mixed path",
  func() {
    let result = PathParser.parsePath("users[0].profile.tags[1]");
    let expected : [PathParser.PathPart] = [
      #key("users"),
      #index(0),
      #key("profile"),
      #key("tags"),
      #index(1),
    ];
    assertPathPartsEqual(result, expected, "complex mixed path");
  },
);

test(
  "PathParser.parsePath - array index with large number",
  func() {
    let result = PathParser.parsePath("items[123456]");
    let expected : [PathParser.PathPart] = [#key("items"), #index(123456)];
    assertPathPartsEqual(result, expected, "large array index");
  },
);

test(
  "PathParser.parsePath - wildcard as key",
  func() {
    let result = PathParser.parsePath("*");
    let expected : [PathParser.PathPart] = [#wildcard];
    assertPathPartsEqual(result, expected, "wildcard as key");
  },
);

test(
  "PathParser.parsePath - wildcard in brackets",
  func() {
    let result = PathParser.parsePath("[*]");
    let expected : [PathParser.PathPart] = [#wildcard];
    assertPathPartsEqual(result, expected, "wildcard in brackets");
  },
);

test(
  "PathParser.parsePath - wildcard in mixed path",
  func() {
    let result = PathParser.parsePath("users.*.name");
    let expected : [PathParser.PathPart] = [#key("users"), #wildcard, #key("name")];
    assertPathPartsEqual(result, expected, "wildcard in mixed path");
  },
);

test(
  "PathParser.parsePath - wildcard array access",
  func() {
    let result = PathParser.parsePath("items[*].value");
    let expected : [PathParser.PathPart] = [#key("items"), #wildcard, #key("value")];
    assertPathPartsEqual(result, expected, "wildcard array access");
  },
);

test(
  "PathParser.parsePath - multiple wildcards",
  func() {
    let result = PathParser.parsePath("*.*.value");
    let expected : [PathParser.PathPart] = [#wildcard, #wildcard, #key("value")];
    assertPathPartsEqual(result, expected, "multiple wildcards");
  },
);

test(
  "PathParser.parsePath - key with underscore",
  func() {
    let result = PathParser.parsePath("user_data.profile_info");
    let expected : [PathParser.PathPart] = [#key("user_data"), #key("profile_info")];
    assertPathPartsEqual(result, expected, "key with underscore");
  },
);

test(
  "PathParser.parsePath - key with numbers",
  func() {
    let result = PathParser.parsePath("item1.data2.value3");
    let expected : [PathParser.PathPart] = [#key("item1"), #key("data2"), #key("value3")];
    assertPathPartsEqual(result, expected, "key with numbers");
  },
);

test(
  "PathParser.parsePath - zero index",
  func() {
    let result = PathParser.parsePath("array[0]");
    let expected : [PathParser.PathPart] = [#key("array"), #index(0)];
    assertPathPartsEqual(result, expected, "zero index");
  },
);

test(
  "PathParser.parsePath - complex nested structure",
  func() {
    let result = PathParser.parsePath("root.items[0].nested.data[5].value");
    let expected : [PathParser.PathPart] = [
      #key("root"),
      #key("items"),
      #index(0),
      #key("nested"),
      #key("data"),
      #index(5),
      #key("value"),
    ];
    assertPathPartsEqual(result, expected, "complex nested structure");
  },
);

test(
  "PathParser.parsePath - leading dot",
  func() {
    let result = PathParser.parsePath(".key");
    let expected : [PathParser.PathPart] = [#key("key")];
    assertPathPartsEqual(result, expected, "leading dot");
  },
);

test(
  "PathParser.parsePath - trailing dot",
  func() {
    let result = PathParser.parsePath("key.");
    let expected : [PathParser.PathPart] = [#key("key")];
    assertPathPartsEqual(result, expected, "trailing dot");
  },
);

test(
  "PathParser.parsePath - multiple consecutive dots",
  func() {
    let result = PathParser.parsePath("key1..key2");
    let expected : [PathParser.PathPart] = [#key("key1"), #key("key2")];
    assertPathPartsEqual(result, expected, "multiple consecutive dots");
  },
);

test(
  "PathParser.parsePath - empty brackets are ignored",
  func() {
    let result = PathParser.parsePath("key[]");
    let expected : [PathParser.PathPart] = [#key("key")];
    assertPathPartsEqual(result, expected, "empty brackets");
  },
);

test(
  "PathParser.parsePath - invalid array index ignored",
  func() {
    // Non-numeric content in brackets should be ignored (except *)
    let result = PathParser.parsePath("key[abc]");
    let expected : [PathParser.PathPart] = [#key("key")];
    assertPathPartsEqual(result, expected, "invalid array index");
  },
);

test(
  "PathParser.parsePath - mixed invalid and valid indices",
  func() {
    let result = PathParser.parsePath("key[abc][123][def]");
    let expected : [PathParser.PathPart] = [#key("key"), #index(123)];
    assertPathPartsEqual(result, expected, "mixed invalid and valid indices");
  },
);

test(
  "PathParser.parsePath - single character keys",
  func() {
    let result = PathParser.parsePath("a.b.c");
    let expected : [PathParser.PathPart] = [#key("a"), #key("b"), #key("c")];
    assertPathPartsEqual(result, expected, "single character keys");
  },
);

test(
  "PathParser.parsePath - very long key",
  func() {
    let longKey = "verylongkeynamethatcontainsmanycharacters";
    let result = PathParser.parsePath(longKey);
    let expected : [PathParser.PathPart] = [#key(longKey)];
    assertPathPartsEqual(result, expected, "very long key");
  },
);

test(
  "PathParser.parsePath - key with special characters",
  func() {
    // Keys can contain various characters except dots and brackets
    let result = PathParser.parsePath("key-with_special@chars#here");
    let expected : [PathParser.PathPart] = [#key("key-with_special@chars#here")];
    assertPathPartsEqual(result, expected, "key with special characters");
  },
);

test(
  "PathParser.parsePath - alternating keys and indices",
  func() {
    let result = PathParser.parsePath("a[0].b[1].c[2].d");
    let expected : [PathParser.PathPart] = [
      #key("a"),
      #index(0),
      #key("b"),
      #index(1),
      #key("c"),
      #index(2),
      #key("d"),
    ];
    assertPathPartsEqual(result, expected, "alternating keys and indices");
  },
);

test(
  "PathParser.parsePath - wildcard combinations",
  func() {
    let result = PathParser.parsePath("*.items[*].data.*");
    let expected : [PathParser.PathPart] = [
      #wildcard,
      #key("items"),
      #wildcard,
      #key("data"),
      #wildcard,
    ];
    assertPathPartsEqual(result, expected, "wildcard combinations");
  },
);
