import StableTrieMap "mo:StableTrieMap";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";

import Types "../DataTypes";
import Utils "../common/Utils";
import IC0Utils "../common/IC0Utils";
import AccessUtils "../common/AccessUtils";
actor class DataRoot() = this {

    private stable var _governance_canister_id : Principal = Principal.fromText("aaaaa-aa");
    private stable var _index_canister_id : Principal = Principal.fromText("aaaaa-aa");
    private let _ic : IC0Utils.ICActor = actor ("aaaaa-aa");
    private let MIN_TOPUP_AMOUNT = 500_000_000_000;//0.5T

    private stable var _storage_canister_map = StableTrieMap.new<Nat, Types.StorageInfo>();

    private stable var _index_canister_map = StableTrieMap.new<Text, Types.IndexInfo>();

    private stable var _admins : [Principal] = [];

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

    public shared(msg) func set_governance_canister(canister_id: Principal) : async Result.Result<Bool, Types.Error> {
       if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        _governance_canister_id := canister_id;
        return #ok(true);
    };

    public shared(msg) func set_index_canister(canister_id: Principal) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        _index_canister_id := canister_id;
        return #ok(true);
    };

    public shared(msg) func topup(canister_id: Principal, amount: Nat) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        if(not (await IC0Utils.is_controller(canister_id,Principal.fromActor(this)))){
            return #err(#NotController);
        };
        if(amount > 100*1_000_000_000_000 or amount < MIN_TOPUP_AMOUNT){
            return #err(#InvalidRequest);
        };
        Cycles.add<system>(amount);
        _ic.deposit_cycles({ canister_id = canister_id });
        return #ok(true);
    };

    public query func get_canister_ids() : async Result.Result<{governance_canister_id: Principal; index_canister_id: Principal}, Types.Error> {
        return #ok({
            governance_canister_id = _governance_canister_id;
            index_canister_id = _index_canister_id;
        });
    };

    public shared(msg) func add_storage_canister(canister_id: Principal, month: Nat) : async Result.Result<Bool, Types.Error> {
        if(msg.caller != _governance_canister_id){
            return #err(#NotGovernance);
        };
        let storageInfo = {
            canister_id = canister_id;
            month = month;
        };
        StableTrieMap.put(_storage_canister_map, Nat.equal, Utils.hash, month, storageInfo);
        return #ok(true);
    };

    public shared func get_storage_canisters_status() : async Result.Result<[Types.StorageStatusInfo], Types.Error> {
        let storageInfos = StableTrieMap.vals(_storage_canister_map);
        let buffer = Buffer.Buffer<Types.StorageStatusInfo>(StableTrieMap.size(_storage_canister_map));
        for(storageInfo in storageInfos) {
            let status = await IC0Utils.canister_status(storageInfo.canister_id);
            buffer.add({
                canister_id = storageInfo.canister_id;
                month = storageInfo.month;
                status = status;
            });
        };
        return #ok(Buffer.toArray(buffer));
    };

    public shared func get_storage_canister_status(month: Nat) : async Result.Result<Types.StorageStatusInfo, Types.Error> {
        let storageInfo = StableTrieMap.get(_storage_canister_map, Nat.equal, Utils.hash, month);
        switch (storageInfo) {
            case (null) {
                return #err(#StorageNotFound);
            };
            case (?storageInfo) {
                let status = await IC0Utils.canister_status(storageInfo.canister_id);
                return #ok({
                    canister_id = storageInfo.canister_id;
                    month = storageInfo.month;
                    status = status;
                });
            };
        };
    };

    public shared(msg) func add_index_canister(canister_id: Principal, name: Text) : async Result.Result<Bool, Types.Error> {
        if(msg.caller != _index_canister_id){
            return #err(#NotIndex);
        };
        let indexInfo = {
            canister_id = canister_id;
            name = name;
        };
        StableTrieMap.put(_index_canister_map, Text.equal, Text.hash, name, indexInfo);
        return #ok(true);
    };

    public shared func get_index_canisters_status() : async Result.Result<[Types.IndexStatusInfo], Types.Error> {
        let indexInfos = StableTrieMap.vals(_index_canister_map);
        let buffer = Buffer.Buffer<Types.IndexStatusInfo>(StableTrieMap.size(_index_canister_map));
        for(indexInfo in indexInfos) {
            let status = await IC0Utils.canister_status(indexInfo.canister_id);
            buffer.add({
                canister_id = indexInfo.canister_id;
                name = indexInfo.name;
                status = status;
            });
        };
        return #ok(Buffer.toArray(buffer));
    };

    public shared func get_index_canister_status(name: Text) : async Result.Result<Types.IndexStatusInfo, Types.Error> {
        let indexInfo = StableTrieMap.get(_index_canister_map, Text.equal, Text.hash, name);
        switch (indexInfo) {
            case (null) {
                return #err(#IndexNotFound);
            };
            case (?indexInfo) {
                let status = await IC0Utils.canister_status(indexInfo.canister_id);
                return #ok({
                    canister_id = indexInfo.canister_id;
                    name = indexInfo.name;
                    status = status;
                });
            };
        };
    };


}
