# IC-Data

## Project Overview

ic-data is a decentralized data storage and sharing platform deployed on the Internet Computer (IC) blockchain. Developed using the Motoko programming language, this project aims to establish a trusted data ecosystem.

Key Features:
- Ensures data quality and credibility through rigorous data provider verification
- Leverages IC blockchain's distributed storage capabilities for permanent and highly available data storage
- Provides consensus-verified, high-value data access services to all users
- Specifically designed to support on-chain AI applications with reliable data infrastructure

### Purpose
The project serves as a foundation for valuable data consensus, where verified data providers can contribute trusted content that is accessible to all visitors. By utilizing blockchain technology, it ensures data integrity and availability while creating a robust data foundation particularly suited for on-chain AI applications.


## Running the project
1. sh deploy-root.sh

    Deploys the root canister.

2. sh deploy-governance.sh

    Takes the root canister ID as an argument.

    Calls the init_storage method on the governance canister, passing the month and year arguments to initialize all the necessary storage.

3. sh deploy-index.sh

    Takes the root canister ID as an argument to deploy the index canister.

4. sh update-root.sh

    Calls the root canister's set_governance_canister and set_index_canister methods to set the governance and index canister IDs.

5. sh deploy-adapter-tx.sh

    Deploys the adapter canister using the governance canister ID and the data provider’s principal ID as arguments.

6. sh add-whitelist.sh

    Adds the adapter canister ID to the governance canister's whitelist.