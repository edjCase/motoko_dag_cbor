import DynamicArray "mo:xtended-collections@0/DynamicArray";
import Text "mo:core@1/Text";
import Nat "mo:core@1/Nat";

/// Heavily inspired by Demali's JSON parser work
/// https://github.com/Demali-876/json/blob/4f3a0ded64751c06a1a7007685902645ac488f96/src/Types.mo

module {

  public type PathPart = {
    #key : Text;
    #index : Nat;
    #wildcard;
  };

  public func parsePath(path : Text) : [PathPart] {
    let chars = path.chars();
    let parts = DynamicArray.DynamicArray<PathPart>(8);
    var current = DynamicArray.DynamicArray<Char>(16);
    var inBracket = false;

    for (c in chars) {
      switch (c) {
        case ('[') {
          if (current.size() > 0) {
            parts.add(#key(Text.fromIter(current.vals())));
            current.clear();
          };
          inBracket := true;
        };
        case (']') {
          if (current.size() > 0) {
            let indexText = Text.fromIter(current.vals());
            if (indexText == "*") {
              parts.add(#wildcard);
            } else {
              switch (Nat.fromText(indexText)) {
                case (?idx) { parts.add(#index(idx)) };
                case (null) {};
              };
            };
            current.clear();
          };
          inBracket := false;
        };
        case ('.') {
          if (current.size() > 0) {
            let key = Text.fromIter(current.vals());
            if (key == "*") {
              parts.add(#wildcard);
            } else {
              parts.add(#key(key));
            };
            current.clear();
          };
        };
        case c { current.add(c) };
      };
    };
    if (current.size() > 0) {
      let final = Text.fromIter(current.vals());
      if (final == "*") {
        parts.add(#wildcard);
      } else {
        parts.add(#key(final));
      };
    };

    DynamicArray.toArray(parts);
  };

};
