import Cbor "mo:cbor@4";
import Int "mo:core@1/Int";
import Nat64 "mo:core@1/Nat64";
import Text "mo:core@1/Text";
import Float "mo:core@1/Float";
import CID "mo:cid@1";
import Nat8 "mo:core@1/Nat8";

module {

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

  public type Type = {
    #int;
    #bytes;
    #text;
    #array;
    #map;
    #cid;
    #bool;
    #null_;
    #float;
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

  public func valueToType(value : Value) : Type {
    switch (value) {
      case (#int(_)) #int;
      case (#bytes(_)) #bytes;
      case (#text(_)) #text;
      case (#array(_)) #array;
      case (#map(_)) #map;
      case (#cid(_)) #cid;
      case (#bool(_)) #bool;
      case (#null_) #null_;
      case (#float(_)) #float;
    };
  };
};
