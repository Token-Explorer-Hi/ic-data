import Nat "mo:base/Nat";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Cycles "mo:base/ExperimentalCycles";
import Region "mo:base/Region";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Itertools "mo:itertools/Iter";
import StableTrieMap "mo:StableTrieMap";
import Types "../DataTypes";
import Utils "../common/Utils";
import AccessUtils "../common/AccessUtils";

shared (initMsg) actor class Storage(storageId : Nat) : async Types.StorageInterface = this {
    type MemoryBlock = {
        offset : Nat64;
        size : Nat;
    };

    stable let KiB = 1024;
    stable let GiB = KiB ** 3;
    stable let MEMORY_PER_PAGE : Nat64 = Nat64.fromNat(64 * KiB);
    stable let MIN_PAGES : Nat64 = 32; // 2MiB == 32 * 64KiB
    stable var PAGES_TO_GROW : Nat64 = 2048; // 64MiB
    stable let MAX_MEMORY = 64 * GiB;

    stable let BUCKET_SIZE = 1000;
    stable let MAX_TRANSACTIONS_PER_REQUEST = 5000;

    stable var block_region : Region = Region.new();
    stable var memory_pages : Nat64 = Region.size(block_region);
    stable var total_memory_used : Nat64 = 0;

    stable var filled_buckets = 0;
    stable var trailing_blocks = 0;
    stable let block_store = StableTrieMap.new<Nat, [MemoryBlock]>();

    stable var accept_status = StableTrieMap.new<Principal, Bool>();

    stable var block_index = 0;

    private func _check_accept_status(data_source_identity: Principal) : Bool {
        switch (StableTrieMap.get(accept_status, Principal.equal, Principal.hash, data_source_identity)) {
            case null {
                return false;
            };
            case (?accept) {
                return accept;
            };
        };
    };

    public shared ({ caller }) func update_accept_status(data_source_identity: Principal, accept: Bool) : async Result.Result<Bool, Types.Error> {
        if (not AccessUtils.is_controller(caller)) {
            return #err(#InternalError("Unauthorized Access: Only the controller can access this function"));
        };
        StableTrieMap.put(accept_status, Principal.equal, Principal.hash, data_source_identity, accept);
        return #ok(true);
    };

    public query func get_accept_status(data_source_identity: Principal) : async Result.Result<Bool, Types.Error> {
        return #ok(_check_accept_status(data_source_identity));
    };

    public shared ({ caller }) func append_blocks(blockArgs : [Types.BlockArg]) : async Result.Result<Bool, Types.Error> {
        if (not _check_accept_status(caller)) {
            return #err(#InternalError("Unauthorized Access: Can not access this storage canister"));
        };
        if(blockArgs.size() == 0) return #ok(true);
        let buffer = Buffer.Buffer<Types.Block>(blockArgs.size());
        for(blockArg in blockArgs.vals()){
            let block = {blockArg with 
                index = Nat.mul(storageId,10_000_000) + block_index;
            };
            buffer.add(block);
            block_index += 1;
        };

        let blocks = Buffer.toArray(buffer);
        var blocks_iter = blocks.vals();

        if (trailing_blocks > 0) {
            let last_bucket = StableTrieMap.get(
                block_store,
                Nat.equal,
                Utils.hash,
                filled_buckets,
            );

            switch (last_bucket) {
                case (?last_bucket) {
                    let new_bucket = Iter.toArray(
                        Itertools.take(
                            Itertools.chain(
                                last_bucket.vals(),
                                Iter.map(blocks.vals(), _store_data),
                            ),
                            BUCKET_SIZE,
                        )
                    );

                    if (new_bucket.size() == BUCKET_SIZE) {
                        let offset = (BUCKET_SIZE - last_bucket.size()) : Nat;

                        blocks_iter := Itertools.fromArraySlice(blocks, offset, blocks.size());
                    } else {
                        blocks_iter := Itertools.empty();
                    };

                    _store_bucket(new_bucket);
                };
                case (_) {};
            };
        };

        for (chunk in Itertools.chunks(blocks_iter, BUCKET_SIZE)) {
            _store_bucket(Array.map(chunk, _store_data));
        };

        #ok(true);
    };

    public query func total_blocks() : async Result.Result<Nat, Types.Error> {
        return #ok(_total_blocks());
    };

    private func _total_blocks() : Nat {
        (filled_buckets * BUCKET_SIZE) + trailing_blocks;
    };

    public query func get_block(block_index : Nat) : async Result.Result<?Types.Block, Types.Error> {
        if(block_index < Nat.mul(storageId,10_000_000)){
            return #err(#InternalError("Block index is out of range, the first block index is " # Nat.toText(Nat.mul(storageId,10_000_000))));
        };
        let index = Nat.sub(block_index, Nat.mul(storageId,10_000_000));
        let block = _get_block(index);
        switch(block){
            case(null){
                return #err(#BlockNotFound);
            };
            case(?block){
                return #ok(?block);
            };
        };
    };

    private func _get_block(block_index : Nat) : ?Types.Block {
        let bucket_key = block_index / BUCKET_SIZE;

        let opt_bucket = StableTrieMap.get(
            block_store,
            Nat.equal,
            Utils.hash,
            bucket_key,
        );

        switch (opt_bucket) {
            case (?bucket) {
                let i = block_index % BUCKET_SIZE;
                if (i < bucket.size()) {
                    ?_get_data(bucket[block_index % BUCKET_SIZE]);
                } else {
                    null;
                };
            };
            case (_) {
                null;
            };
        };
    };

    public query func get_blocks(req : Types.BlockRequest) : async Result.Result<Types.BlockRange, Types.Error> {
        if(req.start < Nat.mul(storageId,10_000_000)){
            return #err(#InternalError("Block index is out of range, the first block index is " # Nat.toText(Nat.mul(storageId,10_000_000))));
        };
        let index = Nat.sub(req.start, Nat.mul(storageId,10_000_000));
        let blocks = _get_blocks(index, req.length);
        return #ok(blocks);
    };

    private func _get_blocks(start : Nat, length : Nat) : Types.BlockRange {
        var iter = Itertools.empty<MemoryBlock>();

        let end = start + length;
        let start_bucket = start / BUCKET_SIZE;
        let end_bucket = (Nat.min(end, _total_blocks()) / BUCKET_SIZE) + 1;

        label _loop for (i in Itertools.range(start_bucket, end_bucket)) {
            let opt_bucket = StableTrieMap.get(
                block_store,
                Nat.equal,
                Utils.hash,
                i,
            );

            switch (opt_bucket) {
                case (?bucket) {
                    if (i == start_bucket) {
                        iter := Itertools.fromArraySlice(bucket, start % BUCKET_SIZE, Nat.min(bucket.size(), (start % BUCKET_SIZE) +length));
                    } else if (i + 1 == end_bucket) {
                        let bucket_iter = Itertools.fromArraySlice(bucket, 0, end % BUCKET_SIZE);
                        iter := Itertools.chain(iter, bucket_iter);
                    } else {
                        iter := Itertools.chain(iter, bucket.vals());
                    };
                };
                case (_) { break _loop };
            };
        };

        let blocks = Iter.toArray(
            Iter.map(
                Itertools.take(iter, MAX_TRANSACTIONS_PER_REQUEST),
                _get_data,
            )
        );

        { blocks };
    };

    public query func remaining_capacity() : async Result.Result<Nat, Types.Error> {
        return #ok(MAX_MEMORY - Nat64.toNat(total_memory_used));
    };

    public query func get_cycle_balance() : async Result.Result<Nat, Types.Error> {
        return #ok(Cycles.balance());
    };

    private func _to_blob(tx : Types.Block) : Blob {
        to_candid (tx);
    };

    private func _from_blob(tx : Blob) : Types.Block {
        switch (from_candid (tx) : ?Types.Block) {
            case (?tx) tx;
            case (_) Debug.trap("Could not decode tx blob");
        };
    };

    private func _store_data(tx : Types.Block) : MemoryBlock {
        let blob = _to_blob(tx);

        if ((memory_pages * MEMORY_PER_PAGE) - total_memory_used < (MIN_PAGES * MEMORY_PER_PAGE)) {
            ignore Region.grow(block_region, PAGES_TO_GROW);
            memory_pages += PAGES_TO_GROW;
        };

        let offset = total_memory_used;

        Region.storeBlob(
            block_region,
            offset,
            blob,
        );

        let mem_block = {
            offset;
            size = blob.size();
        };

        total_memory_used += Nat64.fromNat(blob.size());
        mem_block;
    };

    private func _get_data({ offset; size } : MemoryBlock) : Types.Block {
        let blob = Region.loadBlob(block_region, offset, size);

        _from_blob(blob);
    };

    private func _store_bucket(bucket : [MemoryBlock]) {

        StableTrieMap.put(
            block_store,
            Nat.equal,
            Utils.hash,
            filled_buckets,
            bucket,
        );

        if (bucket.size() == BUCKET_SIZE) {
            filled_buckets += 1;
            trailing_blocks := 0;
        } else {
            trailing_blocks := bucket.size();
        };
    };
};