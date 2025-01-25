import Prim "mo:⛔";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
module {


    public func is_admin(caller: Principal, admins: [Principal]) : Bool {
        return (Array.find<Principal>(admins, func(p) { Principal.equal(p, caller) }) != null or is_controller(caller));
    };

    public func is_controller(caller: Principal) : Bool {
        return Prim.isController(caller);
    };
};