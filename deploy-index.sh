
dfx identity use ai-data

dfx deploy --network=ic index --argument '(record {root_canister_id = principal "sf467-nyaaa-aaaae-qajpq-cai"})' --subnet=ejbmu-grnam-gk6ol-6irwa-htwoj-7ihfl-goimw-hlnvh-abms4-47v2e-zqe


dfx deploy --network=ic tx_pid_index --argument '(record {name = "tx_pid_index"; governance_canister_id = principal "xzhe2-gqaaa-aaaae-qajqa-cai"; index_canister_id = principal "x6gco-liaaa-aaaae-qajqq-cai"})' --subnet=ejbmu-grnam-gk6ol-6irwa-htwoj-7ihfl-goimw-hlnvh-abms4-47v2e-zqe
dfx canister --network=ic call tx_pid_index register