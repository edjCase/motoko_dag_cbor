import Cbor "mo:cbor";
import Result "mo:new-base/Result";
import Int "mo:new-base/Int";
import Nat64 "mo:new-base/Nat64";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import Blob "mo:new-base/Blob";
import Order "mo:new-base/Order";
import Iter "mo:new-base/Iter";
import Float "mo:new-base/Float";
import Buffer "mo:base/Buffer";
import FloatX "mo:xtended-numbers/FloatX";

module {
    public type CID = [Nat8]; // TODO Placeholder for CID type

    public type Value = {
        #int : Int;
        #bytes : [Nat8];
        #text : Text;
        #array : [Value];
        #map : [(Text, Value)];
        #cid : CID;
        #bool : Bool;
        #null_;
        #float : Float;
    };

    public type DagToCborError = {
        #invalidValue : Text;
        #invalidMapKey : Text;
        #unsortedMapKeys;
    };

    public type CborToDagError = {
        #invalidTag : Nat64;
        #invalidMapKey : Text;
        #invalidCIDFormat : Text;
        #unsupportedPrimitive : Text;
        #floatConversionError : Text;
        #integerOutOfRange : Text;
    };

    public type DagEncodingError = DagToCborError or {
        #cborEncodingError : Cbor.EncodingError;
    };

    public type DagDecodingError = CborToDagError or {
        #cborDecodingError : Cbor.DecodingError;
    };

    public func encode(value : Value) : Result.Result<[Nat8], DagEncodingError> {
        let buffer = Buffer.Buffer<Nat8>(10);
        switch (encodeToBuffer(buffer, value)) {
            case (#ok) #ok(Buffer.toArray(buffer));
            case (#err(e)) #err(e);
        };
    };

    public func encodeToBuffer(buffer : Buffer.Buffer<Nat8>, value : Value) : Result.Result<(), DagEncodingError> {
        switch (toCbor(value)) {
            case (#ok(cborValue)) switch (Cbor.encodeToBuffer(buffer, cborValue)) {
                case (#ok()) #ok();
                case (#err(e)) #err(#cborEncodingError(e));
            };
            case (#err(e)) #err(e);
        };
    };

    public func decode(bytes : Iter.Iter<Nat8>) : Result.Result<Value, DagDecodingError> {
        // First decode using the CBOR library
        switch (Cbor.decode(bytes)) {
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

    public func fromCbor(cborValue : Cbor.Value) : Result.Result<Value, CborToDagError> {
        switch (cborValue) {
            case (#majorType0(n)) #ok(#int(Int.fromNat(Nat64.toNat(n))));
            case (#majorType1(i)) #ok(#int(i));
            case (#majorType2(bytes)) #ok(#bytes(bytes));
            case (#majorType3(text)) #ok(#text(text));
            case (#majorType4(array)) {
                // Array - recursively convert elements
                let dagArray = Buffer.Buffer<Value>(array.size());
                for (item in array.vals()) {
                    switch (fromCbor(item)) {
                        case (#ok(dagValue)) dagArray.add(dagValue);
                        case (#err(e)) return #err(e);
                    };
                };
                #ok(#array(Buffer.toArray(dagArray)));
            };
            case (#majorType5(map)) {
                // Map - validate string keys and convert values
                let dagMap = Buffer.Buffer<(Text, Value)>(map.size());
                for ((key, value) in map.vals()) {
                    // DAG-CBOR requires map keys to be strings only
                    let textKey = switch (key) {
                        case (#majorType3(text)) text;
                        case (_) return #err(#invalidMapKey("Map keys must be strings in DAG-CBOR"));
                    };

                    // Recursively convert the value
                    switch (fromCbor(value)) {
                        case (#ok(dagValue)) dagMap.add((textKey, dagValue));
                        case (#err(e)) return #err(e);
                    };
                };
                #ok(#map(Buffer.toArray(dagMap)));
            };
            case (#majorType6({ tag; value })) {
                // Tagged value - DAG-CBOR only allows tag 42 for CIDs
                if (tag != 42) {
                    return #err(#invalidTag(tag));
                };

                // Tag 42 must contain a byte string with multibase identity prefix (0x00)
                switch (value) {
                    case (#majorType2(cid)) {
                        // TODO CID parse
                        #ok(#cid(cid));
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
        let cborArray = Buffer.Buffer<Cbor.Value>(value.size());

        for (item in value.vals()) {
            switch (toCbor(item)) {
                case (#ok(cborValue)) {
                    cborArray.add(cborValue);
                };
                case (#err(e)) return #err(e);
            };
        };

        #ok(#majorType4(Buffer.toArray(cborArray)));
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
        let cborEntries = Buffer.Buffer<(Cbor.Value, Cbor.Value)>(sortedEntries.size());

        for ((key, val) in sortedEntries.vals()) {
            switch (toCbor(val)) {
                case (#ok(cborValue)) {
                    let cborKey = #majorType3(key); // Text keys
                    cborEntries.add((cborKey, cborValue));
                };
                case (#err(e)) return #err(e);
            };
        };

        #ok(#majorType5(Buffer.toArray(cborEntries)));
    };

    func mapCID(value : CID) : Result.Result<Cbor.Value, DagToCborError> {
        // CID must be prefixed with multibase identity prefix (0x00)
        let cidWithPrefix : [Nat8] = Array.concat<Nat8>([0x00], value);

        #ok(
            #majorType6({
                tag = 42; // Only tag 42 is allowed in DAG-CBOR
                value = #majorType2(cidWithPrefix);
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
