import Types "Types";
import Result "mo:core@1/Result";
import Array "mo:core@1/Array";
import PathParser "PathParser";
import Int "mo:core@1/Int";
import Float "mo:core@1/Float";
import CID "mo:cid@1";

/// Heavily inspired by Demali's JSON work
/// https://github.com/Demali-876/json/blob/4f3a0ded64751c06a1a7007685902645ac488f96/src/lib.mo
module {

  public type GetAsError = {
    #pathNotFound;
    #typeMismatch;
  };

  public func get(
    value : Types.Value,
    path : Text,
  ) : ?Types.Value {
    let parts = PathParser.parsePath(path);
    getWithParts(value, parts);
  };

  public func getAsNat(value : Types.Value, path : Text) : Result.Result<Nat, GetAsError> {
    switch (getAsNullableNat(value, path, false)) {
      case (#ok(?n)) { #ok(n) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableNat(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?Nat, GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#int(intValue)) {
        if (intValue < 0) {
          // Must be a positive integer
          return #err(#typeMismatch);
        };
        #ok(?Int.abs(intValue));
      };
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsNullableInt(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?Int, GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#int(intValue)) #ok(?intValue);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsInt(value : Types.Value, path : Text) : Result.Result<Int, GetAsError> {
    switch (getAsNullableInt(value, path, false)) {
      case (#ok(?i)) { #ok(i) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableFloat(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?Float, GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#int(intValue)) #ok(?Float.fromInt(intValue));
      case (#float(floatValue)) #ok(?floatValue);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsFloat(value : Types.Value, path : Text) : Result.Result<Float, GetAsError> {
    switch (getAsNullableFloat(value, path, false)) {
      case (#ok(?f)) { #ok(f) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableBool(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?Bool, GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#bool(boolValue)) #ok(?boolValue);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsBool(value : Types.Value, path : Text) : Result.Result<Bool, GetAsError> {
    switch (getAsNullableBool(value, path, false)) {
      case (#ok(?b)) { #ok(b) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableText(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?Text, GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#text(text)) #ok(?text);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsText(value : Types.Value, path : Text) : Result.Result<Text, GetAsError> {
    switch (getAsNullableText(value, path, false)) {
      case (#ok(?t)) { #ok(t) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableArray(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?[Types.Value], GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#array(items)) #ok(?items);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsArray(value : Types.Value, path : Text) : Result.Result<[Types.Value], GetAsError> {
    switch (getAsNullableArray(value, path, false)) {
      case (#ok(?a)) { #ok(a) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableMap(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?[(Text, Types.Value)], GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#map(entries)) #ok(?entries);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsMap(value : Types.Value, path : Text) : Result.Result<[(Text, Types.Value)], GetAsError> {
    switch (getAsNullableMap(value, path, false)) {
      case (#ok(?m)) { #ok(m) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableBytes(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?[Nat8], GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#bytes(bytes)) #ok(?bytes);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsBytes(value : Types.Value, path : Text) : Result.Result<[Nat8], GetAsError> {
    switch (getAsNullableBytes(value, path, false)) {
      case (#ok(?b)) { #ok(b) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func getAsNullableCid(value : Types.Value, path : Text, allowMissing : Bool) : Result.Result<?CID.CID, GetAsError> {
    let ?v = get(value, path) else return if (allowMissing) #ok(null) else #err(#pathNotFound);
    switch (v) {
      case (#null_) #ok(null);
      case (#cid(cid)) #ok(?cid);
      case (_) #err(#typeMismatch);
    };
  };

  public func getAsCid(value : Types.Value, path : Text) : Result.Result<CID.CID, GetAsError> {
    switch (getAsNullableCid(value, path, false)) {
      case (#ok(?c)) { #ok(c) };
      case (#ok(null)) { #err(#typeMismatch) };
      case (#err(e)) { #err(e) };
    };
  };

  public func isNull(value : Types.Value, path : Text, allowMissing : Bool) : Bool {
    let ?v = get(value, path) else return allowMissing;
    v == #null_;
  };

  public func getWithParts(value : Types.Value, parts : [PathParser.PathPart]) : ?Types.Value {
    if (parts.size() == 0) { return ?value };

    switch (parts[0], value) {
      case (#key(key), #map(entries)) {
        for ((k, v) in entries.vals()) {
          if (k == key) {
            return getWithParts(
              v,
              Array.tabulate<PathParser.PathPart>(
                parts.size() - 1,
                func(i) = parts[i + 1],
              ),
            );
          };
        };
        null;
      };
      case (#index(i), #array(items)) {
        if (i < items.size()) {
          getWithParts(
            items[i],
            Array.tabulate<PathParser.PathPart>(
              parts.size() - 1,
              func(i) = parts[i + 1],
            ),
          );
        } else {
          null;
        };
      };
      case (#wildcard, #map(entries)) {
        ?#array(
          Array.filterMap<(Text, Types.Value), Types.Value>(
            entries,
            func((_, v)) = getWithParts(
              v,
              Array.tabulate<PathParser.PathPart>(
                parts.size() - 1,
                func(i) = parts[i + 1],
              ),
            ),
          )
        );
      };
      case (#wildcard, #array(items)) {
        ?#array(
          Array.filterMap<Types.Value, Types.Value>(
            items,
            func(item) = getWithParts(
              item,
              Array.tabulate<PathParser.PathPart>(
                parts.size() - 1,
                func(i) = parts[i + 1],
              ),
            ),
          )
        );
      };
      case _ { null };
    };
  };

};
