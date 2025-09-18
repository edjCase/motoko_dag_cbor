import Cbor "mo:cbor@4";
import Result "mo:core@1/Result";
import Int "mo:core@1/Int";
import Nat64 "mo:core@1/Nat64";
import Array "mo:core@1/Array";
import Text "mo:core@1/Text";
import Nat "mo:core@1/Nat";
import Blob "mo:core@1/Blob";
import Order "mo:core@1/Order";
import Iter "mo:core@1/Iter";
import Float "mo:core@1/Float";
import Buffer "mo:buffer@0";
import FloatX "mo:xtended-numbers@2/FloatX";
import CID "mo:cid@1";
import MultiBase "mo:multiformats@2/MultiBase";
import Nat8 "mo:core@1/Nat8";
import List "mo:core@1/List";
import Types "Types";

module {

  public func toBytes(value : Types.Value) : Result.Result<[Nat8], Types.DagEncodingError> {
    let buffer = List.empty<Nat8>();
    switch (toBytesBuffer(Buffer.fromList(buffer), value)) {
      case (#ok(_)) #ok(List.toArray(buffer));
      case (#err(e)) #err(e);
    };
  };

  public func toBytesBuffer(
    buffer : Buffer.Buffer<Nat8>,
    value : Types.Value,
  ) : Result.Result<(), Types.DagEncodingError> {
    switch (toCbor(value)) {
      case (#ok(cborValue)) switch (Cbor.toBytesBuffer(buffer, cborValue)) {
        case (#ok) #ok;
        case (#err(e)) #err(#cborEncodingError(e));
      };
      case (#err(e)) #err(e);
    };
  };

  public func fromBytes(bytes : Iter.Iter<Nat8>) : Result.Result<Types.Value, Types.DagDecodingError> {
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

  public func toCbor(value : Types.Value) : Result.Result<Cbor.Value, Types.DagToCborError> {
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

  public func fromCbor(cborValue : Cbor.Value) : Result.Result<Types.Value, Types.CborToDagError> {
    switch (cborValue) {
      case (#majorType0(n)) #ok(#int(Int.fromNat(Nat64.toNat(n))));
      case (#majorType1(i)) #ok(#int(i));
      case (#majorType2(bytes)) #ok(#bytes(bytes));
      case (#majorType3(text)) #ok(#text(text));
      case (#majorType4(array)) {
        // Array - recursively convert elements
        let dagArray = List.empty<Types.Value>();
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
        let dagMap = List.empty<(Text, Types.Value)>();
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

  func mapInt(value : Int) : Result.Result<Cbor.Value, Types.DagToCborError> {
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

  func mapBytes(value : [Nat8]) : Result.Result<Cbor.Value, Types.DagToCborError> {
    #ok(#majorType2(value));
  };

  func mapText(value : Text) : Result.Result<Cbor.Value, Types.DagToCborError> {
    #ok(#majorType3(value));
  };

  func mapArray(value : [Types.Value]) : Result.Result<Cbor.Value, Types.DagToCborError> {
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

  func mapMap(value : [(Text, Types.Value)]) : Result.Result<Cbor.Value, Types.DagToCborError> {
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

  func mapCID(value : CID.CID) : Result.Result<Cbor.Value, Types.DagToCborError> {
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

  func mapBool(value : Bool) : Result.Result<Cbor.Value, Types.DagToCborError> {
    #ok(#majorType7(#bool(value)));
  };

  func mapNull() : Result.Result<Cbor.Value, Types.DagToCborError> {
    #ok(#majorType7(#_null));
  };

  func mapFloat(value : Float) : Result.Result<Cbor.Value, Types.DagToCborError> {
    // DAG-CBOR requires 64-bit floats only
    #ok(#majorType7(#float(FloatX.fromFloat(value, #f64))));
  };

  // Helper function to sort map entries according to DAG-CBOR rules
  func sortMapEntries(entries : [(Text, Types.Value)]) : [(Text, Types.Value)] {
    Array.sort(
      entries,
      func((keyA, _) : (Text, Types.Value), (keyB, _) : (Text, Types.Value)) : Order.Order {
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
  func checkDuplicateKeys(entries : [(Text, Types.Value)]) : Result.Result<(), Types.DagToCborError> {
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
