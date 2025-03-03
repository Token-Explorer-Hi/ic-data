import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Blob "mo:base/Blob";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import SHA224 "mo:sha224/SHA224";
import CRC32 "/CRC32";

module{
    public type BlockIndex = Nat64;
    public type Cycles = Nat;
    public type TimeStamp = { timestamp_nanos : Nat64 };
    public type Tokens = { e8s : Nat64 };
    public type TransferArgs = {
        to : Blob;
        fee : Tokens;
        memo : Nat64;
        from_subaccount : ?Blob;
        created_at_time : ?TimeStamp;
        amount : Tokens;
    };
    public type TransferError = {
        #TxTooOld : { allowed_window_nanos : Nat64 };
      #BadFee : { expected_fee : Tokens };
        #TxDuplicate : { duplicate_of : Nat64 };
        #TxCreatedInFuture;
        #InsufficientFunds : { balance : Tokens };
    };
    public type NotifyTopUpArg = {
        block_index : BlockIndex;
        canister_id : Principal;
    };
    public type NotifyError = {
        #Refunded : { block_index : ?BlockIndex; reason : Text };
        #InvalidTransaction : Text;
        #Other : { error_message : Text; error_code : Nat64 };
        #Processing;
        #TransactionTooOld : BlockIndex;
    };
    public type NotifyTopUpResult = { #Ok : Cycles; #Err : NotifyError };
    public type IcpXdrConversionRate = {
        xdr_permyriad_per_icp : Nat64;
        timestamp_seconds : Nat64;
    };
    public type IcpXdrConversionRateResponse = {
        certificate : Blob;
        data : IcpXdrConversionRate;
        hash_tree : Blob;
    };

    public func mint_cycle(mint_to_canister_id : Principal, mint_cycle_amount : Nat):async NotifyTopUpResult{
        let icpLedger = actor ("ryjl3-tyaaa-aaaaa-aaaba-cai") : actor {
            transfer : shared TransferArgs -> async { #Ok : Nat64; #Err : TransferError };
        };
        let cycleMintingCanister = actor ("rkp4c-7iaaa-aaaaa-aaaca-cai") : actor {
            get_icp_xdr_conversion_rate : shared query () -> async IcpXdrConversionRateResponse;
            notify_top_up : shared NotifyTopUpArg -> async NotifyTopUpResult;
        };

        var xdr_permyriad_per_icp = 0;
        try{
            let xdr_conversion_rate_response = await cycleMintingCanister.get_icp_xdr_conversion_rate();
            xdr_permyriad_per_icp := Nat64.toNat(xdr_conversion_rate_response.data.xdr_permyriad_per_icp);
        }catch(_e){
            throw Error.reject("Get icp xdr conversion rate error : " # Error.message(_e));
        };
            
        let cycles_per_xdr = 1_000_000_000_000;
        let cycles_per_icp = xdr_permyriad_per_icp * cycles_per_xdr / 10_000;
        let burn_icp_amount = Float.div(Float.fromInt(mint_cycle_amount),Float.fromInt(cycles_per_icp));
        let icp_e8s = Nat64.fromNat(Int.abs(Float.toInt(burn_icp_amount * 100_000_000)));

        let sub_account : [Nat8] = Blob.toArray(_principal_to_blob(mint_to_canister_id));
        let to_account = _to_account_id(Principal.fromText("rkp4c-7iaaa-aaaaa-aaaca-cai"), sub_account);
        let transfer_result = await icpLedger.transfer({
            to = Blob.fromArray(to_account); 
            amount = {e8s = icp_e8s};
            fee = {e8s = 10_000};
            memo = 0x50555054;
            from_subaccount = null;
            created_at_time = null;
        });
        switch (transfer_result) {
            case (#Ok(_block_height)) {
                await cycleMintingCanister.notify_top_up({block_index = _block_height; canister_id = mint_to_canister_id});
            };
            case (#Err(_error)) {
                throw Error.reject("Transfer error : " # debug_show(_error));
            };
        };
    };

    private func _principal_to_blob(p : Principal) : Blob {
        var arr : [Nat8] = Blob.toArray(Principal.toBlob(p));
        var defaultArr : [var Nat8] = Array.init<Nat8>(32, 0);
        defaultArr[0] := Nat8.fromNat(arr.size());
        var ind : Nat = 0;
        while (ind < arr.size() and ind < 32) {
            defaultArr[ind + 1] := arr[ind];
            ind := ind + 1;
        };
        return Blob.fromArray(Array.freeze(defaultArr));
    };

    private func _to_account_id(p: Principal,sub_account : [Nat8]) : [Nat8] {
        let digest = SHA224.Digest();
        digest.write([10, 97, 99, 99, 111, 117, 110, 116, 45, 105, 100]:[Nat8]);
        let blob = Principal.toBlob(p);
        digest.write(Blob.toArray(blob));
        digest.write(sub_account);
        let hash_bytes : [Nat8] = digest.sum();
        let crc : [Nat8] = CRC32.crc32(hash_bytes);
        let aid_bytes = _add_all<Nat8>(crc, hash_bytes);
        return aid_bytes;
    };

     private func _add_all<T>(a : [T], b : [T]) : [T] {
        var result : Buffer.Buffer<T> = Buffer.Buffer<T>(0);
        for (t : T in a.vals()) {
            result.add(t);
        };
        for (t : T in b.vals()) {
            result.add(t);
        };
        return Buffer.toArray(result);
    };
}