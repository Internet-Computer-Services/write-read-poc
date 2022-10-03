import List "mo:base/List";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

actor {
  var otherCanisterId : Text = "";
  var maxValue : Nat = 1000;
  var lastValueWrite: Nat = 1;
  var timings : Trie.Trie<Nat, Int> = Trie.empty();
  var readTimings : Trie.Trie<Nat, Int> = Trie.empty();

  type Timing = (Nat, Int);

  // canister B type defination
  public type CAN_B = actor {
    trigger: { value: Nat } -> async ();
    getCurrentValue: query () -> async Nat;
    triggerReadQuery: () -> async ();
  };

  public func setOtherCanisterId(canister_id: Text) : async () {
    otherCanisterId := canister_id;
  };

  public func getOtherCanisterId() : async Text {
    return otherCanisterId;
  };

  private func printTimeNow() : async () {
    let timeNow=Time.now();
    Debug.print(debug_show(timeNow));
  };

  public func trigger({ value: Nat }) : async () {
    if(otherCanisterId == "") {
      Debug.print("otherCanisterId is null");
      return;
    };
    let (newTimings, existing) = Trie.put(
        timings,
        { key = value; hash = Text.hash(Nat.toText(value))},
        Nat.equal,
        Time.now()
    );
    timings := newTimings;

    if(value >= maxValue) {
      Debug.print("Job Completed At: ");
      await printTimeNow();
      lastValueWrite := value;
      return;
    };

    // create canister B instance
    let canB : CAN_B = actor(otherCanisterId);
    await canB.trigger({ value = value + 1 });
  };

  public shared query func getWriteOpTimings() : async [(Nat, Int)] {
    let result : [Timing] = Trie.toArray<Nat, Int, Timing>(timings, func(k, v) { (k, v); });
    return result;
  };

  public shared query func getReadOpTimings() : async [(Nat, Int)] {
    let result : [Timing] = Trie.toArray<Nat, Int, Timing>(readTimings, func(k, v) { (k, v); });
    return result;
  };

  // for read operation
  public func triggerReadQuery() : async () {
    // create canister B instance
    let canB : CAN_B = actor(otherCanisterId);
    readTimings := Trie.empty();

    for(i in Iter.range(0, 100)) {
      let currentValue = await canB.getCurrentValue();
      let (newTimings, existing) = Trie.put(
          readTimings,
          { key = i; hash = Text.hash(Nat.toText(i))},
          Nat.equal,
          Time.now()
      );
      readTimings := newTimings;
    };
  };

  public query func getReadOpResult() : async Text {
    if(Trie.isEmpty(readTimings)) {
      return "Read operation not completed yet";
    };

    // get first and last element
    let first = Trie.get(readTimings, { key = 0; hash = Text.hash(Nat.toText(0))}, Nat.equal);
    let last = Trie.get(readTimings, { key = 99; hash = Text.hash(Nat.toText(99))}, Nat.equal);

    switch (first, last) {
      case (?first, ?last) {
        let diff = last - first;
        return "Read operation completed in " # Int.toText(diff/1000000000) # " s";
      };
      case _ {
        return "Read operation not completed yet";
      };
    };
  };

  public query func getWriteOpResult(): async Text {
    if(Trie.isEmpty(timings)) {
      return "Write operation not completed yet";
    };

    // get first and last element
    let first = Trie.get(timings, { key = 1; hash = Text.hash(Nat.toText(1))}, Nat.equal);
    let last = Trie.get(timings, { key = lastValueWrite; hash = Text.hash(Nat.toText(lastValueWrite))}, Nat.equal);

    switch (first, last) {
      case (?first, ?last) {
        let diff = last - first;
        return "Write operation completed in " # Int.toText(diff/1000000000) # " s";
      };
      case _ {
        return "Write operation not completed yet";
      };
    };
  };

  public func reset() : async () {
    timings := Trie.empty();
    readTimings := Trie.empty();
    lastValueWrite := 1;
  };
};
