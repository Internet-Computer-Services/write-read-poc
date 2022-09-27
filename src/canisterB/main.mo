import List "mo:base/List";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

actor {
  var otherCanisterId : Text = "";
  var maxValue : Nat = 1000;
  var timings : Trie.Trie<Nat, Int> = Trie.empty();
  var readTimings : Trie.Trie<Nat, Int> = Trie.empty();

  type Timing = (Nat, Int);

  // canister A type defination
  public type CAN_A = actor {
    trigger: { value: Nat } -> async ();
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
      return;
    };

    // create canister A instance
    let canB : CAN_A = actor(otherCanisterId);
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

  public func triggerReadQuery() : async () {
    // create canister A instance
    let canA : CAN_A = actor(otherCanisterId);
    readTimings := Trie.empty();

    for(i in Iter.range(0, 100)) {
      await canA.triggerReadQuery();
      let (newTimings, existing) = Trie.put(
          readTimings,
          { key = i; hash = Text.hash(Nat.toText(i))},
          Nat.equal,
          Time.now()
      );
      readTimings := newTimings;
    };
  };

  public func reset() : async () {
    timings := Trie.empty();
    readTimings := Trie.empty();
  };
};
