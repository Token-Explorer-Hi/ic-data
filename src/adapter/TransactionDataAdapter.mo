import Text "mo:base/Text";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Bool "mo:base/Bool";
import Error "mo:base/Error";

import Types "../DataTypes";
import Utils "../common/Utils";

actor class TransactionDataAdapter({governance_id: Principal;provider_id: Principal}) {

    public type TransactionData = {
        category : Text;
        source : ?Text;
        op : Text;
        source_canister : ?Text;
        from_owner : ?Text;
        from_subaccount : ?Text;
        from_account_id : ?Text;
        from_alias : ?Text;
        from_account_textual : ?Text;
        to_owner : ?Text;
        to_subaccount : ?Text;
        to_account_id : ?Text;
        to_alias : ?Text;
        to_account_textual : ?Text;
        spender_owner : ?Text;
        spender_subaccount : ?Text;
        spender_account_id : ?Text;
        spender_alias : ?Text;
        spender_account_textual : ?Text;
        token0_ledger_id : ?Text;
        token0_amount : ?Float;
        token0_decimal : ?Nat32;
        token0_fee : ?Float;
        token0_tx_memo : ?Text;
        token0_tx_hash : ?Text;
        token0_tx_index : ?Nat;
        token0_tx_time : Nat;
        token0_value : ?Float;
        token1_ledger_id : ?Text;
        token1_amount : ?Float;
        token1_decimal : ?Nat32;
        token1_fee : ?Float;
        token1_tx_memo : ?Text;
        token1_tx_hash : ?Text;
        token1_tx_index : ?Nat;
        token1_tx_time : ?Nat;
        token1_value : ?Float;
        upload_id : ?Nat;
    };

    public type TransactionDataArg = {
        txs : [TransactionData];
    };

    var governance : Types.GovernanceInterface = actor(Principal.toText(governance_id));
    
    public query func get_init_args() : async {governance_id: Principal;provider_id: Principal} {
        return {
            governance_id = governance_id;
            provider_id = provider_id;
        };
    };

    public composite query(msg) func get_storage_canister_id(month: Nat) : async Result.Result<Principal, Types.Error> {
        if(msg.caller != provider_id){
            return #err(#NotProvider);
        };
        return await governance.get_storage_canister_id(month);
    };

    private var message1 = "";
    private var message2 = "";

    public query func get_messages() : async {message1: Text;message2: Text;} {
        return {
            message1 = message1;
            message2 = message2;
        };
    };

    public shared(msg) func upload_transaction_data(txsArg : TransactionDataArg) : async Result.Result<Bool, Types.Error> {
        if(msg.caller != provider_id){
            return #err(#NotProvider);
        };
        if(txsArg.txs.size() == 0){
            return #err(#InternalError("No transaction data"));
        };
        if(txsArg.txs.size() > 2000){
            return #err(#InternalError("Too many transaction data"));
        };
        var month = 0;
        let buffer = Buffer.Buffer<Types.BlockArg>(txsArg.txs.size());
        try{
            for(tx in txsArg.txs.vals()){
                if(month == 0){
                    month := Utils.get_month(tx.token0_tx_time);
                };
                let block = tx_to_block(tx);
                buffer.add(block);
            };
        }catch(e){
            message1 := "Error1: " # debug_show (Error.message(e));
        };
        try{
            if(buffer.size() > 0){
                let storageResult = await governance.get_storage_canister_id(month);
                switch(storageResult){
                    case(#ok(storageCanisterId)){
                        let storageCanister = actor(Principal.toText(storageCanisterId)) : Types.StorageInterface;
                        let result = await storageCanister.append_blocks(Buffer.toArray(buffer));
                        return result;
                    };
                    case(#err(err)){
                        return #err(err);
                    };
                };
            };
            message2 := "Buffer size: " # debug_show(buffer.size());
        }catch(e){
            message2 := "Error2: " # Error.message(e);
        };
        return #ok(true);
    };


    private func tx_to_block(tx : TransactionData) : Types.BlockArg {

        let buffer = Buffer.Buffer<(Text,Types.Value)>(0);
        switch(tx.source){
            case(null){};
            case(?source){
                buffer.add(("source",#Text(source)));
            };
        };
        switch(tx.source_canister){
            case(null){};
            case(?source_canister){
                buffer.add(("source_canister",#Text(source_canister)));
            };
        };
        switch(tx.from_owner){
            case(null){};
            case(?from_owner){
                buffer.add(("from_owner",#Text(from_owner)));
            };
        };
        switch(tx.from_subaccount){
            case(null){};
            case(?from_subaccount){
                buffer.add(("from_subaccount",#Text(from_subaccount)));
            };
        };
        switch(tx.from_account_id){
            case(null){};
            case(?from_account_id){
                buffer.add(("from_account_id",#Text(from_account_id)));
            };
        };
        switch(tx.from_alias){
            case(null){};
            case(?from_alias){
                buffer.add(("from_alias",#Text(from_alias)));
            };
        };
        switch(tx.from_account_textual){
            case(null){};
            case(?from_account_textual){
                buffer.add(("from_account_textual",#Text(from_account_textual)));
            };
        };
        switch(tx.to_owner){
            case(null){};
            case(?to_owner){
                buffer.add(("to_owner",#Text(to_owner)));
            };
        };
        switch(tx.to_subaccount){
            case(null){};
            case(?to_subaccount){
                buffer.add(("to_subaccount",#Text(to_subaccount)));
            };
        };
        switch(tx.to_account_id){
            case(null){};
            case(?to_account_id){
                buffer.add(("to_account_id",#Text(to_account_id)));
            };
        };
        switch(tx.to_alias){
            case(null){};
            case(?to_alias){
                buffer.add(("to_alias",#Text(to_alias)));
            };
        };
        switch(tx.to_account_textual){
            case(null){};
            case(?to_account_textual){
                buffer.add(("to_account_textual",#Text(to_account_textual)));
            };
        };
        switch(tx.spender_owner){
            case(null){};
            case(?spender_owner){
                buffer.add(("spender_owner",#Text(spender_owner)));
            };
        };
        switch(tx.spender_subaccount){
            case(null){};
            case(?spender_subaccount){
                buffer.add(("spender_subaccount",#Text(spender_subaccount)));
            };
        };
        switch(tx.spender_account_id){
            case(null){};
            case(?spender_account_id){
                buffer.add(("spender_account_id",#Text(spender_account_id)));
            };
        };
        switch(tx.spender_alias){
            case(null){};
            case(?spender_alias){
                buffer.add(("spender_alias",#Text(spender_alias)));
            };
        };
        switch(tx.spender_account_textual){
            case(null){};
            case(?spender_account_textual){
                buffer.add(("spender_account_textual",#Text(spender_account_textual)));
            };
        };
        switch(tx.token0_ledger_id){
            case(null){};
            case(?token0_ledger_id){
                buffer.add(("token0_ledger_id",#Text(token0_ledger_id)));
            };
        };
        switch(tx.token0_amount){
            case(null){};
            case(?token0_amount){
                buffer.add(("token0_amount",#Float(token0_amount)));
            };
        };
        switch(tx.token0_decimal){
            case(null){};
            case(?token0_decimal){
                buffer.add(("token0_decimal",#Nat32(token0_decimal)));
            };
        };
        switch(tx.token0_fee){
            case(null){};
            case(?token0_fee){
                buffer.add(("token0_fee",#Float(token0_fee)));
            };
        };
        switch(tx.token0_tx_memo){
            case(null){};
            case(?token0_tx_memo){
                buffer.add(("token0_tx_memo",#Text(token0_tx_memo)));
            };
        };
        switch(tx.token0_tx_hash){
            case(null){};
            case(?token0_tx_hash){
                buffer.add(("token0_tx_hash",#Text(token0_tx_hash)));
            };
        };
        switch(tx.token0_tx_index){
            case(null){};
            case(?token0_tx_index){
                buffer.add(("token0_tx_index",#Nat(token0_tx_index)));
            };
        };
        buffer.add(("token0_tx_time",#Nat(tx.token0_tx_time)));
        switch(tx.token0_value){
            case(null){};
            case(?token0_value){
                buffer.add(("token0_value",#Float(token0_value)));
            };
        };
        switch(tx.token1_ledger_id){
            case(null){};
            case(?token1_ledger_id){
                buffer.add(("token1_ledger_id",#Text(token1_ledger_id)));
            };
        };
        switch(tx.token1_amount){
            case(null){};
            case(?token1_amount){
                buffer.add(("token1_amount",#Float(token1_amount)));
            };
        };
        switch(tx.token1_decimal){
            case(null){};
            case(?token1_decimal){
                buffer.add(("token1_decimal",#Nat32(token1_decimal)));
            };
        };
        switch(tx.token1_fee){
            case(null){};
            case(?token1_fee){
                buffer.add(("token1_fee",#Float(token1_fee)));
            };
        };
        switch(tx.token1_tx_memo){
            case(null){};
            case(?token1_tx_memo){
                buffer.add(("token1_tx_memo",#Text(token1_tx_memo)));
            };
        };
        switch(tx.token1_tx_hash){
            case(null){};
            case(?token1_tx_hash){
                buffer.add(("token1_tx_hash",#Text(token1_tx_hash)));
            };
        };
        switch(tx.token1_tx_index){
            case(null){};
            case(?token1_tx_index){
                buffer.add(("token1_tx_index",#Nat(token1_tx_index)));
            };
        };
        switch(tx.token1_tx_time){
            case(null){};
            case(?token1_tx_time){
                buffer.add(("token1_tx_time",#Nat(token1_tx_time)));
            };
        };
        switch(tx.token1_value){
            case(null){};
            case(?token1_value){
                buffer.add(("token1_value",#Float(token1_value)));
            };
        };
        switch(tx.upload_id){
            case(null){};
            case(?upload_id){
                buffer.add(("upload_id",#Nat(upload_id)));
            };
        };
        let block : Types.BlockArg = {
            category = tx.category;
            operation = tx.op;
            timestamp = tx.token0_tx_time;
            data = #Map(Buffer.toArray(buffer));
        };
        return block;
    };


}