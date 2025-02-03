import Types "../DataTypes";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import StableTrieMap "mo:StableTrieMap";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Utils "../common/Utils";

shared (initMsg) actor class Index({name: Text; governance_canister_id: Principal}) : async Types.IndexInterface = this {

    private stable var _index_details : Types.IndexDetails = {canister_id = Principal.fromActor(this); name = name; value = #Map([])};

    // key is the index name, value is the list of block numbers
    private stable var _index = StableTrieMap.new<Text, [Nat]>();

    // sync index from storage canister, key is storage canister id,value is the storage last block number
    private stable var _storage_index = StableTrieMap.new<Principal, Nat>();

    private stable var _storage_map = StableTrieMap.new<Nat, Types.StorageInfo>();

    let _governance_canister = actor(Principal.toText(governance_canister_id)) : Types.GovernanceInterface;

    public query func get_index_details() : async Result.Result<Types.IndexDetails, Types.Error> {
        return #ok(_index_details);
    };

    public shared(msg) func update_index_details(details: Types.IndexDetails) : async Result.Result<Bool, Types.Error> {
        if(msg.caller != Principal.fromActor(this)){
            return #err(#NotController);
        };
        _index_details := {
            canister_id = Principal.fromActor(this);
            name = details.name;
            value = details.value;
        };
        return #ok(true);
    };

    public shared(msg) func build_index() : async Result.Result<Bool, Types.Error> {
        if(msg.caller != Principal.fromActor(this)){
            return #err(#NotController);
        };
        return await _sync_index();
    };

    public query func get_principal_block_indexes(principal: Principal,block_request: Types.BlockRequest) : async Result.Result<[Nat], Types.Error> {
        let index_list = StableTrieMap.get(_index, Text.equal, Text.hash, Principal.toText(principal));
        let block_index_buffer = Buffer.Buffer<Nat>(0);
        switch(index_list){
            case(null){
                return #ok([]);
            };
            case(?index_list){
                var start = block_request.start;
                for(index in index_list.vals()){
                    if(index >= start and block_index_buffer.size() < block_request.length){
                        block_index_buffer.add(index);
                    };
                };
                if(block_index_buffer.size() == 0){
                    return #ok([]);
                };
                return #ok(Buffer.toArray(block_index_buffer));
            };
        };
    };

    public composite query func get_principal_blocks(principal: Principal,block_request: Types.BlockRequest) : async Result.Result<[Types.Block], Types.Error> {
        let index_list = StableTrieMap.get(_index, Text.equal, Text.hash, Principal.toText(principal));
        let block_buffer = Buffer.Buffer<Types.Block>(0);
        switch(index_list){
            case(null){
                return #ok([]);
            };
            case(?index_list){
                var start = block_request.start;
                let index_buffer = Buffer.Buffer<Nat>(0);
                for(index in index_list.vals()){
                    if(index >= start and index_buffer.size() < block_request.length){
                        index_buffer.add(index);
                    };
                };
                if(index_buffer.size() == 0){
                    return #ok([]);
                };
                for(index in index_buffer.vals()){
                    let block = await _get_block(index);
                    switch(block){
                        case(null){};
                        case(?block){
                            block_buffer.add(block);
                        };
                    };
                };
                return #ok(Buffer.toArray(block_buffer));
            };
        };
    };

    private composite query func _get_block(block_index: Nat) : async ?Types.Block {
        let month = block_index / 10_000_000;
        let storage_info = StableTrieMap.get(_storage_map, Nat.equal, Utils.hash, month);
        switch(storage_info){
            case(null){
                return null;
            };
            case(?storage_info){    
                let storage_canister = actor(Principal.toText(storage_info.canister_id)) : Types.StorageInterface;
                let block_response = await storage_canister.get_block(block_index);
                switch(block_response){
                    case(#err(_err)){
                        return null;
                    };
                    case(#ok(block)){
                        return block;
                    };
                };
            };
        };
    };

    private func _sync_index() : async Result.Result<Bool, Types.Error> {
        // sync storage list from governance canister
        let storage_list = await _governance_canister.get_all_storage();
        switch(storage_list){   
            case(#err(_err)){
                return #err(#InternalError("Failed to get storage list from governance canister"));
            };
            case(#ok(storage_list)){
                for((month, storage_info) in storage_list.vals()){
                    StableTrieMap.put(_storage_map, Nat.equal, Utils.hash, month, storage_info);
                    let storage_canister = actor(Principal.toText(storage_info.canister_id)) : Types.StorageInterface;
                    var last_block_number : Nat = 0;
                    switch(StableTrieMap.get(_storage_index, Principal.equal, Principal.hash, storage_info.canister_id)){
                        case(null){
                            last_block_number := 0;
                        };
                        case(?storage_last_block_number){
                            last_block_number := storage_last_block_number;
                        };
                    };
                    let block_response = await storage_canister.get_blocks({start = last_block_number; length = 1000});
                    switch(block_response){
                        case(#err(err)){
                            return #err(err);
                        };
                        case(#ok(block_response)){
                            if(block_response.blocks.size() > 0){
                                let _update_result = _update_index(storage_info.canister_id, block_response);
                            };
                        };
                    };
                };
            };
        };
        return #ok(true);
    };

    private func _update_index(storage_canister_id : Principal, block_response: Types.BlockRange) : Result.Result<Bool, Types.Error> {
        let map_tmp = HashMap.HashMap<Text, Buffer.Buffer<Nat>>(0, Text.equal, Text.hash);
        var last_block_number = 0;
        for(block in block_response.blocks.vals()){
            let data = block.data;
            switch(data){
                case(#Map(map)){
                    for((key, value) in map.vals()){
                        if(key == "from_owner"){
                            let from_owner = switch(value){
                                case(#Principal(owner_principal)){
                                    Principal.toText(owner_principal);
                                };
                                case(#Text(owner_text)){
                                    owner_text;
                                };
                                case(_){""};
                            };
                            if(from_owner != ""){
                                switch(map_tmp.get(from_owner)){
                                    case(null){
                                        let buffer = Buffer.Buffer<Nat>(1);
                                        buffer.add(block.index);
                                        map_tmp.put(from_owner, buffer);
                                    };
                                    case(?buffer){
                                        if(not Buffer.contains<Nat>(buffer, block.index, Nat.equal)){
                                            buffer.add(block.index);
                                            map_tmp.put(from_owner, buffer);
                                        };
                                    };
                                };
                            };
                        };
                        if(key == "to_owner"){
                            let to_owner = switch(value){
                                case(#Principal(owner_principal)){
                                    Principal.toText(owner_principal);
                                };
                                case(#Text(owner_text)){
                                    owner_text;
                                };
                                case(_){""};
                            };
                            if(to_owner != ""){
                                switch(map_tmp.get(to_owner)){
                                    case(null){
                                        let buffer = Buffer.Buffer<Nat>(1);
                                        buffer.add(block.index);
                                        map_tmp.put(to_owner, buffer);
                                    };
                                    case(?buffer){
                                        if(not Buffer.contains<Nat>(buffer, block.index, Nat.equal)){
                                            buffer.add(block.index);
                                            map_tmp.put(to_owner, buffer);
                                        };
                                    };
                                };
                            };  
                        };
                        if(key == "spender_owner"){
                            let spender_owner = switch(value){
                                case(#Principal(owner_principal)){
                                    Principal.toText(owner_principal);
                                };
                                case(#Text(owner_text)){
                                    owner_text;
                                };
                                case(_){""};
                            };
                            if(spender_owner != ""){
                                switch(map_tmp.get(spender_owner)){
                                    case(null){
                                        let buffer = Buffer.Buffer<Nat>(1);
                                        buffer.add(block.index);
                                        map_tmp.put(spender_owner, buffer);
                                    };
                                    case(?buffer){
                                        if(not Buffer.contains<Nat>(buffer, block.index, Nat.equal)){
                                            buffer.add(block.index);
                                            map_tmp.put(spender_owner, buffer);
                                        };
                                    };
                                };
                            };  
                        };
                    };
                };
                case(_){};
            };
            last_block_number := block.index;
        };

        for((key, buffer) in map_tmp.entries()){
            let index_list = Buffer.toArray(buffer);
            switch(StableTrieMap.get(_index, Text.equal, Text.hash, key)){
                case(null){
                    StableTrieMap.put(_index, Text.equal, Text.hash, key, index_list);
                };
                case(?index_list){
                    var new_index_list = Buffer.fromArray<Nat>(index_list);
                    new_index_list.append(buffer);
                    StableTrieMap.put(_index, Text.equal, Text.hash, key, Buffer.toArray(new_index_list));
                };
            };
        };

        StableTrieMap.put(_storage_index, Principal.equal, Principal.hash, storage_canister_id, last_block_number);
        return #ok(true);
    };
    
}