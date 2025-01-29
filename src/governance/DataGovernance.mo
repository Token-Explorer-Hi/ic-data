import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import Iter "mo:base/Iter";
import Cycles "mo:base/ExperimentalCycles";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Order "mo:base/Order";
import Timer "mo:base/Timer";

import StableTrieMap "mo:StableTrieMap";

import Storage "../storage/Storage";
import Types "../DataTypes";
import Utils "../common/Utils";
import IC0Utils "../common/IC0Utils";
import AccessUtils "../common/AccessUtils";

shared (initMsg) actor class DataGovernance({root_canister_id: Principal}) {

    private let _INIT_CYCLES : Nat = 3_000_000_000_000;

    private stable var _storage_map = StableTrieMap.new<Nat, Types.StorageInfo>();

    private stable var _whitelist = StableTrieMap.new<Principal, Types.DataSource>();

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

    public shared (msg) func add_storage_controller(canister_id: Principal,controller: Principal) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        let _ = await IC0Utils.update_settings_add_controller(canister_id, controller);
        return #ok(true);
    };

    public shared (msg) func remove_storage_controller(canister_id: Principal,controller: Principal) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        let _ = await IC0Utils.update_settings_remove_controller(canister_id, controller);
        return #ok(true);
    };

    public shared(msg) func add_whitelist(data_source_identity: Principal, data_source_name: Text,accept: Bool) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        let data_source = {
            identity = data_source_identity;
            accept = accept;
            metadata = #Map([("name", #Text(data_source_name))]);
        };
        StableTrieMap.put(_whitelist, Principal.equal, Principal.hash, data_source_identity, data_source);
        for((month, storage) in StableTrieMap.entries(_storage_map)){
            let storageInterface = _get_storage_interface(month);
            switch(storageInterface){
                case null {
                    return #err(#StorageNotFound);
                };
                case (?storageInterface) {
                    let _result = await storageInterface.update_accept_status(data_source_identity, accept);
                };
            };
        };
        return #ok(true);
    };

    public shared(msg) func remove_whitelist(data_source_identity: Principal) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        switch(StableTrieMap.get(_whitelist, Principal.equal, Principal.hash, data_source_identity)){
            case null {
                return #err(#DataSourceNotFound);
            };
            case (?_data_source) {
                let storages =  StableTrieMap.entries(_storage_map);
                StableTrieMap.delete(_whitelist, Principal.equal, Principal.hash, data_source_identity);
                for((month, storage) in storages){
                    let storageInterface = _get_storage_interface(month);
                    switch(storageInterface){
                        case null {
                            return #err(#StorageNotFound);
                        };
                        case (?storageInterface) {
                            let _result = await storageInterface.update_accept_status(data_source_identity, false);
                        };
                    };
                };
            };
        };
        return #ok(true);
    };

    public shared(msg) func update_accept_status(data_source_identity: Principal, accept: Bool) : async Result.Result<Bool, Types.Error> {
        if(not AccessUtils.is_admin(msg.caller, _admins)){
            return #err(#NotAdmin);
        };
        switch(StableTrieMap.get(_whitelist, Principal.equal, Principal.hash, data_source_identity)){
            case null {
                return #err(#DataSourceNotFound);
            };
            case (?data_source) {
                StableTrieMap.put(_whitelist, Principal.equal, Principal.hash, data_source_identity, {
                    identity = data_source_identity;
                    accept = accept;
                    metadata = data_source.metadata;
                });
                for((month, storage) in StableTrieMap.entries(_storage_map)){
                    let storageInterface = _get_storage_interface(month);
                    switch(storageInterface){
                        case null {
                            return #err(#StorageNotFound);
                        };
                        case (?storageInterface) {
                            let result = await storageInterface.update_accept_status(data_source_identity, accept);
                            switch(result){
                                case (#err(err)){
                                    return #err(#InternalError(debug_show(err)));
                                };
                                case (#ok(_ok)){};
                            };
                        };
                    };
                };
            };
        };
        return #ok(true);
    };

    public query func get_whitelist() : async Result.Result<[(Principal, Types.DataSource)], Types.Error> {
        return #ok(Iter.toArray(StableTrieMap.entries(_whitelist)));
    };

    private func _data_source_allowed(data_source_identity: Principal) : Bool {
        switch(StableTrieMap.get(_whitelist, Principal.equal, Principal.hash, data_source_identity)){
            case null {
                return false;
            };
            case (?data_source) {
                return data_source.accept;
            };
        };
    };

    public query func get_all_storage() : async Result.Result<[(Nat, Types.StorageInfo)], Types.Error> {
        var array = Iter.toArray(StableTrieMap.entries(_storage_map));
        let sortedArray = Utils.sort(array, func(a: (Nat, Types.StorageInfo), b: (Nat, Types.StorageInfo)) : Order.Order {
            let (month1, _) = a;
            let (month2, _) = b;
            Nat.compare(month1, month2)
        });
        return #ok(sortedArray);
    };

    public query(msg) func get_storage_canister_id(month: Nat) : async Result.Result<Principal, Types.Error> {
        if (not _validate_month(month)) {
            return #err(#InternalError("Invalid month format"));
        };
        if(not _data_source_allowed(msg.caller)){
            return #err(#NotInWhitelist);
        };

        switch(StableTrieMap.get(_storage_map, Nat.equal, Utils.hash, month)){
            case null {
                return #err(#StorageNotFound);
            };
            case (?storageInfo) {
                return #ok(storageInfo.canister_id);
            };
        };
    };

    func _create_storage(month: Nat) : async Types.StorageInfo {
        assert(StableTrieMap.get(_storage_map, Nat.equal, Utils.hash, month) == null);
        Cycles.add<system>(_INIT_CYCLES);
        let storageCanister = await Storage.Storage(month);
        let storageInfo = {
            canister_id = Principal.fromActor(storageCanister);
            month = month;
        };
        let _ = await IC0Utils.update_settings_add_controller(Principal.fromActor(storageCanister), root_canister_id);
        StableTrieMap.put(_storage_map, Nat.equal, Utils.hash, month, storageInfo);
        let _ = await _root_canister.add_storage_canister(Principal.fromActor(storageCanister), month);
        return storageInfo;
    };

    func _get_storage_interface(month: Nat) : ?Types.StorageInterface {
        switch(StableTrieMap.get(_storage_map, Nat.equal, Utils.hash, month)){
            case null {
                return null;
            };
            case (?storageInfo) {
                let poolCanister = actor(Principal.toText(storageInfo.canister_id)) : Types.StorageInterface;
                return ?poolCanister;
            };
        };
    };

    func _create_storage_if_not_exist() : async () {
        let now = Time.now();
        let month = Utils.get_month(Int.abs(now)/1_000_000);
        if(month <= 202501 or month >= 202512){
            return;
        };
        let _storageInfo = await _create_storage(month);
    };

    // public shared(msg) func init_storage():async Result.Result<Nat, Types.Error>{
    //     if(not AccessUtils.is_admin(msg.caller,_admins)){
    //         return #err(#NotAdmin);
    //     };
    //     var year = 2022;
    //     var month = 2;
    //     var count = 0;
    //     var monthStorage = 202202;
    //     while(monthStorage <= 202501){
    //         ignore await _create_storage(monthStorage);
    //         month += 1;
    //         if(month > 12){
    //             month := 1;
    //             year += 1;
    //         };
    //         monthStorage := year * 100 + month;
    //         count += 1;
    //     };
    //     return #ok(count);
    // };

    ignore Timer.recurringTimer<system>(#seconds(60 * 10), _create_storage_if_not_exist);

    private func _validate_month(month: Nat) : Bool {
        let year = month / 100;
        let m = month % 100;
        return year >= 1970 and m >= 1 and m <= 12;
    };

}