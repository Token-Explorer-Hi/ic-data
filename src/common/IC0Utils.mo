import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";

import Types "../DataTypes";

module {

    public type CanisterId = {
        canister_id: Principal;
    };
    type user_id = Principal;
    type wasm_module = Blob;
    type canister_settings = { controllers : [Principal] };

    public type ICActor = actor {
        canister_status: query (canister_id: CanisterId) -> async Types.CanisterStatusResult;
        deposit_cycles : shared (canister_id : CanisterId) -> ();
    };

    let ic00 = actor "aaaaa-aa" : actor {
        create_canister : shared (settings : Types.CreateCanisterParams) -> async {
            canister_id : Principal;
        };
        stop_canister : Principal -> async ();
        delete_canister : Principal -> async ();
        canister_status: query (canister_id: CanisterId) -> async Types.CanisterStatusResult;
        deposit_cycles : shared (canister_id : CanisterId) -> ();
        update_settings : {
            canister_id : Principal;
            settings : canister_settings;
        } -> ();
        install_code : shared {
            mode : { #install; #reinstall; #upgrade };
            canister_id : Principal;
            wasm_module : Blob;
            arg : Blob;
        } -> async ();
    };

    public func install_code({
        mode : { #install; #reinstall; #upgrade };
        canister_id : Principal;
        wasm_module : Blob;
        arg : Blob;
    }) : async () {

        await ic00.install_code({
            mode = mode;
            canister_id = canister_id;
            wasm_module = wasm_module;
            arg = arg;
        });
    };

    public func update_settings_add_controller(cid : Principal, controller : Principal) : async () {
        var result = await ic00.canister_status({ canister_id = cid });
        var settings = result.settings;
        var controllers : [Principal] = settings.controllers;
        var controllerList = List.append(List.fromArray([controller]), List.fromArray(controllers));
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = List.toArray(controllerList) };
        });
    };

    public func update_settings_remove_controller(cid : Principal, controller : Principal) : async () {
        var result = await ic00.canister_status({ canister_id = cid });
        var settings = result.settings;
        var controllers : [Principal] = settings.controllers;
        var controllerList = List.filter(List.fromArray(controllers), func(a : Principal) : Bool { return not Principal.equal(a, controller) });
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = List.toArray(controllerList) };
        });
    };

    public func update_settings_add_controllers(cid : Principal, addControllers : [Principal]) : async () {
        var result = await ic00.canister_status({ canister_id = cid });
        var settings = result.settings;
        var controllers : [Principal] = settings.controllers;
        var controllerBuffer = Buffer.fromArray<Principal>(controllers);
        for (controller in addControllers.vals()) {
            if (not Buffer.contains(controllerBuffer, controller, func(a : Principal, b : Principal) : Bool { return Principal.equal(a, b) })) {
                controllerBuffer.add(controller);
            };
        };
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = Buffer.toArray(controllerBuffer) };
        });
    };

    public func update_settings_controllers(cid : Principal, controllers : [Principal]) : async () {
        ic00.update_settings({
            canister_id = cid;
            settings = { controllers = controllers };
        });
    };

    public func stop_canister(cid : Principal) : async () {
        ignore ic00.stop_canister(cid);
    };

    public func delete_canister(cid : Principal) : async () {
        ignore ic00.delete_canister(cid);
    };

    public func create_canister(params : Types.CreateCanisterParams) : async Principal {
        return (await ic00.create_canister(params)).canister_id;
    };

    public func canister_status(cid : Principal) : async Types.CanisterStatusResult {
        return await ic00.canister_status({ canister_id = cid });
    };

    public func get_controllers(cid : Principal) : async [Principal] {
        let status = await ic00.canister_status({ canister_id = cid });
        return status.settings.controllers;
    };

    public func is_controller(caller : Principal, principal : Principal) : async Bool {
        var controllerLists = await get_controllers(caller);
        return switch (Array.find<Principal>(controllerLists, func(a : Principal) : Bool { return Principal.equal(principal, a) })) {
            case (?_data) { return true };
            case (_) { throw Error.reject("permission_denied") };
        };
    };
};
