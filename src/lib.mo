import Cbor "mo:cbor";
import Result "mo:new-base/Result";
import Int "mo:new-base/Int";
import Nat64 "mo:new-base/Nat64";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Nat "mo:new-base/Nat";
import Blob "mo:new-base/Blob";
import Order "mo:new-base/Order";
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

    // public type DagValue = {
    //     #majorType0 : Nat64; // 0 -> 2^64 - 1
    //     #majorType1 : Int; // -2^64 -> -1 ((-1 * Value) - 1)
    //     #majorType2 : [Nat8];
    //     #majorType3 : Text;
    //     #majorType4 : [DagValue];
    //     #majorType5 : [(Text, DagValue)];
    //     #majorType6 : {
    //         tag : Nat64; // Only 42 Allowed
    //         value : {
    //             #majorType2 : [Nat8]; // CID
    //         };
    //     };
    //     #majorType7 : {
    //         #bool : Bool;
    //         #_null;
    //         #float : Float; // Only 64 bit
    //     };
    // };

    // public type DagDecodingError = {
    //     #unexpectedEndOfBytes;
    //     #invalid : Text;
    //     #unsortedMapKeys;
    //     #duplicateMapKey : Text;
    //     #invalidMapKey : Text;
    //     #invalidFloatEncoding;
    // };

    public type DagMappingError = {
        #invalidValue : Text;
        #invalidMapKey : Text;
        #unsortedMapKeys;
    };

    public type DagEncodingError = DagMappingError or {
        #cborEncodingError : Cbor.EncodingError;
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

    public func toCbor(value : Value) : Result.Result<Cbor.Value, DagMappingError> {
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

    func mapInt(value : Int) : Result.Result<Cbor.Value, DagMappingError> {
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

    func mapBytes(value : [Nat8]) : Result.Result<Cbor.Value, DagMappingError> {
        #ok(#majorType2(value));
    };

    func mapText(value : Text) : Result.Result<Cbor.Value, DagMappingError> {
        #ok(#majorType3(value));
    };

    func mapArray(value : [Value]) : Result.Result<Cbor.Value, DagMappingError> {
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

    func mapMap(value : [(Text, Value)]) : Result.Result<Cbor.Value, DagMappingError> {
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

    func mapCID(value : CID) : Result.Result<Cbor.Value, DagMappingError> {
        // CID must be prefixed with multibase identity prefix (0x00)
        let cidWithPrefix : [Nat8] = Array.concat<Nat8>([0x00], value);

        #ok(
            #majorType6({
                tag = 42; // Only tag 42 is allowed in DAG-CBOR
                value = #majorType2(cidWithPrefix);
            })
        );
    };

    func mapBool(value : Bool) : Result.Result<Cbor.Value, DagMappingError> {
        #ok(#majorType7(#bool(value)));
    };

    func mapNull() : Result.Result<Cbor.Value, DagMappingError> {
        #ok(#majorType7(#_null));
    };

    func mapFloat(value : Float) : Result.Result<Cbor.Value, DagMappingError> {
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
    func checkDuplicateKeys(entries : [(Text, Value)]) : Result.Result<(), DagMappingError> {
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
