# Smart-Contract-based-Cloud-offloading
In this repository the implementation of a ethereum-based smart contract which implements a resource allocation method for cloud offloading and the related thesis can be found.

## Abstract
Due to the ever-increasing demand of applications for computing resources, cloud comput- ing and especially offloading has become one of the most important topics in computing. Cloud computing has a number of essential advantages over traditional local computing: it offers external computing resources that can be more powerful, faster and cheaper than their local counterpart. However, today’s form of cloud computing also has some draw- backs. These consist of the need to trust an external party, a high degree of centralisation in a few parties and high entry costs for providers.
In the following bachelor thesis, we have addressed this problem and tried to solve it with a smart contract running on the Ethereum blockchain. Thereby, the contract takes on the role of a resource trader and thus tries to solve the problems mentioned above.
When analysing the practical results of the work, we found that our proof-of-concept was successful, but that there are still some open questions that need to be solved before the solution is ready for real market application.

## Contents of the repository:
/Contracts: This folder contains the .sol files of the implemented interfaces, libraries and contracts.

/Migrations: This order contains .sol files for the migration to an ethereum-blockchain by using the Truffle Suite.

/testcases.txt: This file contains the inputs and outputs of the test cases used to test the contract.

/thesis.pdf: This file contains the thesis describing the implementation and the research work behind it.

## Tools

**necessary**:  
*openZeppelin Contracts*: This library is required, since it is used in the file /Contracts/ParticipantsLibrary.sol.

**optional**:  
*Truffle Suite*: was used by us to compile and migrate the contract. The necessary migration files can be found in the /Migrations folder. If a tool other than truffle is used to deploy the contract, the dependency of the contracts on each other must be taken into account (see /thesis.pdf section 5.2). 

**note**:  
in case a reader does not want to use the truffle suite or the migration files used, the following must be considered: the contract *nodeContract* must be deployed before the contract *userContract*, which must be deployed with the address of the deployed *nodeContract* in the constructor.
Then the function *connector* must be called in the *userContract* to connect the two contracts with each other.
Both contracts and the function must be deployed and called from the same issuer.
