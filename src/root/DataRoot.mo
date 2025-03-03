import StableTrieMap "mo:StableTrieMap";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Cycles "mo:base/ExperimentalCycles";
import Bool "mo:base/Bool";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Timer "mo:base/Timer";

import Types "../DataTypes";
import Utils "../common/Utils";
import IC0Utils "../common/IC0Utils";
import AccessUtils "../common/AccessUtils";
import CycleMintHelper "../common/CycleMintHelper";
actor class DataRoot() = this {

    private stable var _governance_canister_id : Principal = Principal.fromText("aaaaa-aa");
    private stable var _index_canister_id : Principal = Principal.fromText("aaaaa-aa");
    private let _ic : IC0Utils.ICActor = actor ("aaaaa-aa");
    private let MIN_TOPUP_AMOUNT = 500_000_000_000;//0.5T
    private let MAX_CYCLES = 3_000_000_000_000;//3T
    private let MIN_CYCLES = 2_000_000_000_000;//2T
    private let MIN_ROOT_CYCLES = 100_000_000_000_000;//100T
    private let MAX_ROOT_CYCLES = 200_000_000_000_000_000;//200T

    private stable var _storage_canister_map = StableTrieMap.new<Nat, Types.StorageInfo>();

    private stable var _index_canister_map = StableTrieMap.new<Text, Types.IndexInfo>();

    private stable var _admins : [Principal] = [];

    private stable var _canister_status_map = StableTrieMap.new<Principal, Types.CanisterStatusResult>();

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

    public query func get_storage_canisters_status() : async Result.Result<[Types.StorageStatusInfo], Types.Error> {
        let storageInfos = StableTrieMap.vals(_storage_canister_map);
        let buffer = Buffer.Buffer<Types.StorageStatusInfo>(StableTrieMap.size(_storage_canister_map));
        for(storageInfo in storageInfos) {
            let status = _get_canister_status(storageInfo.canister_id);
            switch (status) {
                case (null) {};
                case (?status) {
                    buffer.add({
                        canister_id = storageInfo.canister_id;
                        month = storageInfo.month;
                        status = status;
                    });
                };
            };
        };
        return #ok(Buffer.toArray(buffer));
    };

    public query func get_storage_canister_status(month: Nat) : async Result.Result<Types.StorageStatusInfo, Types.Error> {
        let storageInfo = StableTrieMap.get(_storage_canister_map, Nat.equal, Utils.hash, month);
        switch (storageInfo) {
            case (null) {
                return #err(#StorageNotFound);
            };
            case (?storageInfo) {
                let status = _get_canister_status(storageInfo.canister_id);
                switch (status) {
                    case (null) {
                        return #err(#StorageNotFound);
                    };
                    case (?status) {
                        return #ok({
                            canister_id = storageInfo.canister_id;
                            month = storageInfo.month;
                            status = status;
                        });
                    };
                };
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

    public query func get_index_canisters_status() : async Result.Result<[Types.IndexStatusInfo], Types.Error> {
        let indexInfos = StableTrieMap.vals(_index_canister_map);
        let buffer = Buffer.Buffer<Types.IndexStatusInfo>(StableTrieMap.size(_index_canister_map));
        for(indexInfo in indexInfos) {
            let status = _get_canister_status(indexInfo.canister_id);
            switch (status) {
                case (null) {};
                case (?status) {
                    buffer.add({
                        canister_id = indexInfo.canister_id;
                        name = indexInfo.name;
                        status = status;
                    });
                };
            };
        };
        return #ok(Buffer.toArray(buffer));
    };

    public query func get_index_canister_status(name: Text) : async Result.Result<Types.IndexStatusInfo, Types.Error> {
        let indexInfo = StableTrieMap.get(_index_canister_map, Text.equal, Text.hash, name);
        switch (indexInfo) {
            case (null) {
                return #err(#IndexNotFound);
            };
            case (?indexInfo) {
                let status = _get_canister_status(indexInfo.canister_id);
                switch (status) {
                    case (null) {
                        return #err(#IndexNotFound);
                    };
                    case (?status) {
                        return #ok({
                            canister_id = indexInfo.canister_id;
                            name = indexInfo.name;
                            status = status;
                        });
                    };
                };
            };
        };
    };

    private func _update_canisters_status() : async () {
        for(storageInfo in StableTrieMap.vals(_storage_canister_map)) {
            try {
                let status = await IC0Utils.canister_status(storageInfo.canister_id);
                StableTrieMap.put(_canister_status_map, Principal.equal, Principal.hash, storageInfo.canister_id, status);
            } catch (e) {
                Debug.print("Error updating canister status: " # debug_show(Error.message(e)));
            };
        };
        for(indexInfo in StableTrieMap.vals(_index_canister_map)) {
            try {
                let status = await IC0Utils.canister_status(indexInfo.canister_id);
                StableTrieMap.put(_canister_status_map, Principal.equal, Principal.hash, indexInfo.canister_id, status);
            } catch (e) {
                Debug.print("Error updating canister status: " # debug_show(Error.message(e)));
            };
        };
    };

    private func _monitor_canister_cycle() : async () {
        for((canister_id, canister_status) in StableTrieMap.entries(_canister_status_map)) {
            if(canister_status.cycles < MIN_CYCLES) {
                let amount = Nat.sub(MAX_CYCLES, canister_status.cycles);
                Cycles.add<system>(amount);
                _ic.deposit_cycles({ canister_id = canister_id });
            };
        };
    };

    private func _monitor_root_cycle() : async () {
        let status = await IC0Utils.canister_status(_governance_canister_id);
        if(status.cycles < MIN_ROOT_CYCLES) {
            let amount = Nat.sub(MAX_ROOT_CYCLES, status.cycles);
            let result = await CycleMintHelper.mint_cycle(Principal.fromActor(this), amount);
            switch (result) {
                case (#Ok(_)) {};
                case (#Err(_)) {};
            };
        };
    };

    private func _get_canister_status(canister_id: Principal) : ?Types.CanisterStatusResult {
        return StableTrieMap.get(_canister_status_map, Principal.equal, Principal.hash, canister_id);
    };


    ignore Timer.recurringTimer<system>(#seconds(60 * 10), _update_canisters_status);
    ignore Timer.recurringTimer<system>(#seconds(60 * 60 * 3), _monitor_root_cycle);
    ignore Timer.recurringTimer<system>(#seconds(60 * 60 * 6), _monitor_canister_cycle);
}
