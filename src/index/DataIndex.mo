import Types "../DataTypes";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Order "mo:base/Order";
import AccessUtils "../common/AccessUtils";
import IC0Utils "../common/IC0Utils";

import StableTrieMap "mo:StableTrieMap";
import Utils "../common/Utils";


shared (initMsg) actor class DataIndex({root_canister_id: Principal}) = this {

    private stable var _admins : [Principal] = [initMsg.caller];
    private stable var _index_map = StableTrieMap.new<Principal, Types.IndexInfo>();

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

    public shared (msg) func register_index(canister_id: Principal,name: Text) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        let is_controller = await IC0Utils.is_controller(canister_id, Principal.fromActor(this));
        if(not is_controller){
            return #err(#NotController);
        };
        let _add_root_controller_result = await IC0Utils.update_settings_add_controller(canister_id, root_canister_id);
        let _add_index_result = await _root_canister.add_index_canister(canister_id, name);
        StableTrieMap.put(_index_map, Principal.equal, Principal.hash, canister_id, {canister_id = canister_id; name = name});
        return _add_index_result;
    };

    public query func get_index(canister_id: Principal) : async Result.Result<Types.IndexInfo, Types.Error> {
        switch(StableTrieMap.get(_index_map, Principal.equal, Principal.hash, canister_id)){
            case null {
                return #err(#IndexNotFound);
            };
            case (?index) {
                return #ok(index);
            };
        };
    };

    public query func get_all_index() : async Result.Result<[Types.IndexInfo], Types.Error> {
        let buffer = Buffer.Buffer<Types.IndexInfo>(StableTrieMap.size(_index_map));
        for((canister_id, index) in StableTrieMap.entries(_index_map)){
            buffer.add(index);
        };
        if(buffer.size() == 0){
            return #ok([]);
        };
        let array = Buffer.toArray(buffer);
        let sortedArray = Utils.sort(array, func(a: Types.IndexInfo, b: Types.IndexInfo) : Order.Order {
            Principal.compare(a.canister_id, b.canister_id)
        });
        return #ok(sortedArray);
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