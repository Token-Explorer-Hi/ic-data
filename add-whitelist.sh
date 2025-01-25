

dfx identity use ai-data

dfx canister --network=ic call governance add_whitelist '(principal "wpm4r-taaaa-aaaae-qajva-cai","Transaction data provider",true)'

dfx canister --network=ic call governance add_whitelist '(principal "n3u3y-eiaaa-aaaad-qgf2q-cai","Transaction data provider 2",true)'