import Types "../DataTypes";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import AccessUtils "../common/AccessUtils";
import IC0Utils "../common/IC0Utils";

shared (initMsg) actor class DataIndex(({root_canister_id: Principal})) {
    private let _INIT_CYCLES : Nat = 3_000_000_000_000;
    private stable var _admins : [Principal] = [initMsg.caller];
    let _root_canister = actor(Principal.toText(root_canister_id)) : Types.RootInterface;

    public shared (msg) func set_admins(admins : [Principal]) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_controller(msg.caller)){
            return #err(#NotController);
        };
        _admins := admins;
        return #ok(true);
    };

    public query func get_admins() : async Result.Result<[Principal], Text> {
        return #ok(_admins);
    };

    public shared (msg) func add_index_controller(canister_id: Principal,controller: Principal) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        let _ = await IC0Utils.update_settings_add_controller(canister_id, controller);
        return #ok(true);
    };

    public shared (msg) func remove_index_controller(canister_id: Principal,controller: Principal) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        let _ = await IC0Utils.update_settings_remove_controller(canister_id, controller);
        return #ok(true);
    };
}