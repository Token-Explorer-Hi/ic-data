import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Bool "mo:base/Bool";

module {

    public type CycleInfo = {
        balance : Nat;
        available : Nat;
    };

    public type CanisterSettings = {
        controllers : ?[Principal];
        compute_allocation : ?Nat;
        memory_allocation : ?Nat;
        freezing_threshold : ?Nat;
    };
    public type CreateCanisterParams = {
        settings : ?CanisterSettings;
    };

    public type DefiniteCanisterSettings = {
        controllers : [Principal];
        compute_allocation : ?Nat;
        memory_allocation : ?Nat;
        freezing_threshold : ?Nat;
        reserved_cycles_limit : ?Nat;
        wasm_memory_limit : ?Nat;
    };

    public type CanisterStatusResult = {
        status : { #stopped; #stopping; #running };
        memory_size : Nat;
        cycles : Nat;
        reserved_cycles : ?Nat;
        settings : DefiniteCanisterSettings;
        module_hash : ?Blob;
    };

    public type Error = {
        #CommonError;
        #InsufficientFunds;
        #InternalError : Text;
        #NotController;
        #NotAdmin;
        #NotProvider;
        #NotGovernance;
        #NotIndex;
        #NotInWhitelist;
        #StorageNotFound;
        #DataSourceNotFound;
        #BlockNotFound;
        #IndexNotFound;
        #InvalidRequest;
    };

    public type BlockArg = {
        category : Text;
        operation : Text;
        timestamp : Nat;
        data : Value;
    };

    public type Block = {
        index : Nat;
        category : Text;
        operation : Text;
        timestamp : Nat;
        data : Value;
    };

    public type DataSource = {
        identity : Principal;
        accept : Bool;
        metadata : Value;
    };

    public type Value = {
        #Array : [Value];
        #Blob : Blob;
        #Bool : Bool;
        #Float : Float;
        #Int : Int;
        #Int8 : Int8;
        #Int16 : Int16;
        #Int32 : Int32;
        #Int64 : Int64;
        #Map : [(Text, Value)];
        #Nat : Nat;
        #Nat8 : Nat8;
        #Nat16 : Nat16;
        #Nat32 : Nat32;
        #Nat64 : Nat64;
        #Principal : Principal;
        #Text : Text;
    };

    public type BlockRequest = {
        start : Nat;
        length : Nat;
    };

    public type BlockResponse = {
        length : Nat;
        first_index : Nat;
        blocks : [Block];
        archived_blocks : [StorageBlock];
    };

    public type BlockRange = {
        blocks : [Block];
    };

    public type QueryArchivedBlockFn = shared query (BlockRequest) -> async BlockRange;

    public type StorageBlock = {
        start : Nat;
        length : Nat;
        callback : QueryArchivedBlockFn;
    };

    public type StorageInfo = {
        canister_id : Principal;
        month : Nat;
    };

    public type IndexInfo = {
        canister_id : Principal;
        name : Text;
    };
    
    public type IndexDetails = {
        canister_id : Principal;
        name : Text;
        value : Value;
    };

    public type IndexStatusInfo = {
        canister_id : Principal;
        name : Text;
        status : CanisterStatusResult;
    };

    public type StorageStatusInfo = {
        canister_id : Principal;
        month : Nat;
        status : CanisterStatusResult;
    };

    public type StorageInterface = actor {
        append_blocks : shared ([BlockArg]) -> async Result.Result<Bool, Error>;
        total_blocks : query () -> async Result.Result<Nat, Error>;
        get_block : query (Nat) -> async Result.Result<?Block, Error>;
        get_blocks : query (BlockRequest) -> async Result.Result<BlockRange, Error>;
        remaining_capacity : query () -> async Result.Result<Nat, Error>;
        update_accept_status : shared (Principal, Bool) -> async Result.Result<Bool, Error>;
    };

    public type IndexInterface = actor {
        register_index : shared (Text) -> async Result.Result<Bool, Error>;
    };

    public type GovernanceInterface = actor {
        get_storage_canister_id : query (month: Nat) -> async Result.Result<Principal, Error>; 
        get_all_storage : query () -> async Result.Result<[(Nat, StorageInfo)], Error>;
    };

    public type RootInterface = actor {
        add_storage_canister : shared (canister_id: Principal, month: Nat) -> async Result.Result<Bool, Error>;
        add_index_canister : shared (canister_id: Principal, name: Text) -> async Result.Result<Bool, Error>;
    };
    
}