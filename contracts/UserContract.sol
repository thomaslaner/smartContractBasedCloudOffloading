// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//Imports
import "./Interfaces.sol";

//Contract
contract UserContract is UserContractInternalInterface, UserContractExternalInterface {

    //global definitions

        //contract-related definitions
        address private issuer;                                     //issuer of the contract
        
        address private NodeContractAddress;                        //address of connected NodeContract
        NodeContractInternalInterface private NodeContractInstance; //instance of connected NodeContract
        
        //user-related definitions

            //Structure with which users and nodes are saved in their respective contracts
            struct user {
                uint freeStaking;                                               //# of staking-ETH in WEI which is not currently bound by an assignment
                uint lockedStaking;                                             //# of staking-ETH in WEI which is currently bound by an assignment
                
                address[] activeAssignments;                                    //array containing user's assignmentContract's addresses
            }

            mapping (address => user) private users;                            //mapping of addresses to user-struct's

    //modifier definitions

        //onlyIssuer

            function onlyIssuerFunc() internal view {
                require(msg.sender == issuer, "This function is restricted to the contracts issuer");
            }

            modifier onlyIssuer() {
                onlyIssuerFunc();
                _;
            }

        //onlyRegistered

            function onlyRegisteredFunc() internal view {
                require(((users[msg.sender].lockedStaking != 0) || (users[msg.sender].freeStaking != 0)) == true, "This function is restricted to registered Users");
            }
            
            modifier onlyRegistered() {
                onlyRegisteredFunc();
                _;
            }

        //onlyAssignmentContract 

            //checks if sender of message is listed in user "userAddress"'s assignments
            function onlyAssignmentContractFunc(address userAddress) internal view {

                uint8 found;

                for (uint256 i = 0; i < users[userAddress].activeAssignments.length; i++) {
                    if (msg.sender == users[userAddress].activeAssignments[i]) {
                        found = 1;
                    }
                }

                require((found == 1), "This function is restricted to user's assignmentContracts");
            }
            
            modifier onlyAssignmentContract(address userAddress) {
                onlyAssignmentContractFunc(userAddress);
                _;
            }        

    //contract creation functions

        //@descr - defines issuer & nodeContractAddress & nodeContractInstance from given parameters
        //@param - passedNodeContractAddress: address of deployed NodeContract which will be used by the connector-function
        constructor(address passedNodeContractAddress) { 
            issuer = msg.sender;
            NodeContractAddress = passedNodeContractAddress;
            NodeContractInstance = NodeContractInternalInterface(NodeContractAddress); 
        }

        //@descr - connects the contract to the NodeContract-Instance guided to by nodeAddress
        //@return - success: if successful connection has been established
        function connector() override external onlyIssuer() {
            
            NodeContractInstance.connector();
            emit ParticipantsLibrary.contractEvent(ParticipantsLibrary.SUCCESSFUL_CONNECTION);
        }

    //internal functions

        //assignment creation functions

            //@descr - Checks User's freeStaking if enough is available for requested amount of resources (if enough available temporarily add them to locked staking)
            //@param - userAddress: address of requesting user
            //@param - resources: amount of resources requested by user
            //@return - enoughFreeStaking: if user has enough free Staking-ETH available or not
            function i_assignmentCheckStaking(address userAddress, uint resources) internal returns (bool enoughFreeStakingETH) {

                uint256 requiredStaking =  ParticipantsLibrary.resourcesToStaking(resources);

                //check if user has enough free Staking ETH for the requested amount of resources
                if (users[userAddress].freeStaking >= requiredStaking) {
                    //user has enough free staking available

                    //report that user has enough staking-ETH stored with the contract
                    emit ParticipantsLibrary.participantEvent(userAddress, ParticipantsLibrary.SUFFICIENT_STAKING);
                    //locking of staking-ETH is not yet reported since the availability of requested resources has not yet been checked 

                    //transfer the needed amount from user's free- to locked-staking
                    users[userAddress].freeStaking -= requiredStaking;
                    users[userAddress].lockedStaking += requiredStaking;

                    //report transfer of staking to user
                    emit ParticipantsLibrary.stakingEvent(userAddress, ParticipantsLibrary.concatenateTransfer(ParticipantsLibrary.X_LOCKED_STAKING_ADD, requiredStaking, ParticipantsLibrary.X_FREE_STAKING_SUB, requiredStaking));
                    
                    //return that enough free staking was available
                    return true;

                } else {
                    //report that user has not enough staking-ETH stored with the contract
                    emit ParticipantsLibrary.participantEvent(userAddress, ParticipantsLibrary.INSUFFICIENT_STAKING);
                    
                    //return that not enough free staking has been available
                    return false;
                }

            }
            
            //@descr - Checks if a node has the requested resources available and, if so, creates new assignmentContract. Otherwise returns necessary amount of staking-funds back to freeStaking 
            //@param - userAddress: address of requesting user
            //@param - resources: amount of resources requested by user
            function i_assignmentCheckResources(address userAddress, uint resources) internal {
                
                //Searches schedule for a node with a resources amount of resources available. If a fitting node was found: initiate a new assignment by changing that node's balance of free- & locked-Resources and adding a new entry in node's assignment entry.
                address activeAssignments = NodeContractInstance.c_resourceRequest(userAddress, resources);

                //handle output of resourceRequest
                if (activeAssignments != address(0)) {
                    //if node could be found
                    
                    //report that resources are available
                    emit ParticipantsLibrary.participantEvent(userAddress,ParticipantsLibrary.RESOURCES_AVAILABLE);

                    //add returned assignmentID to user's assignmentIndexes
                    users[userAddress].activeAssignments.push(activeAssignments);

                    emit ParticipantsLibrary.assignmentEvent(userAddress, activeAssignments, ParticipantsLibrary.ASSIGNMENT_CREATION);

                } else {
                    //if no node could be found
                    
                    //let user know that resources were not available
                    emit ParticipantsLibrary.participantEvent(userAddress, ParticipantsLibrary.RESOURCES_NOT_AVAILABLE);

                    //returns assignment's lockedStaking to freeStaking and notifies user of the transfer
                    i_assignmentReturnStaking(userAddress, ParticipantsLibrary.resourcesToStaking(resources), ParticipantsLibrary.resourcesToStaking(resources));
                    
                }
            }

        //assignment completion functions

            //@descr - returns specified amount freeStakingAdd which was returned by contract back to user's freeStaking specified by userAddress on completion of assignment and subtracts specified amount of staking defined by lockedStakingSub from user's lockedStaking and reports transfers to user
            //@param - userAddress: address of concerned User
            //@param - freeStakingAdd: amount of Staking added to user's freeStaking (= amount of staking not deducted as punishment if one was enacted by contract)
            //@param - lockedStakingSub: amount of Staking subtracted from user's lockedStaking (= initial amount of staking locked by assignment)
            function i_assignmentReturnStaking(address userAddress, uint freeStakingAdd, uint lockedStakingSub) internal {
                    
                    //transfer staking
                    users[userAddress].freeStaking += freeStakingAdd;
                    users[userAddress].lockedStaking -= lockedStakingSub;

                    //report transfer of staking to user
                    emit ParticipantsLibrary.stakingEvent(userAddress, ParticipantsLibrary.concatenateTransfer(ParticipantsLibrary.X_FREE_STAKING_ADD, freeStakingAdd, ParticipantsLibrary.X_LOCKED_STAKING_SUB, lockedStakingSub));
            }

            //@descr - deletes assignment out of activeAssignments in userAddress' user-struct 
            //@param - userAddress: address of concerned User
            //@param - assignmentID: address of assignment which shall be deleted
            function i_assignmentDeletion(address userAddress, address assignmentAddress) internal {
                //delete assignment's entry out of user's storage

                    //loop through activeAssignments-array and overwrite entry with passed assignmentAddress by last assignment in array - pop last element 
                    for (uint256 i = 0; i < users[userAddress].activeAssignments.length; i++) {
                        if (users[userAddress].activeAssignments[i] == assignmentAddress) {
                            
                            //overwrite assignment and pop last element in array with, which assignment has been overwritten with, out of the array
                            users[userAddress].activeAssignments[i] = users[userAddress].activeAssignments[users[userAddress].activeAssignments.length-1];
                            users[userAddress].activeAssignments.pop();
                            
                            break; //skip rest of loop since assignment has been found and was overwritten
                        }
                    }
            }

    //user functions

        //@descr - Registers user if not yet registered, adds sent funds to freeStaking, checks if freeStaking contains enough ETH for the requested amount of resources and if so, looks for a node with those resources available. If such a node is found, transfer necessary staking for the duration of the assignment to lockedStaking and initiate the assignment. Reports to user if not enough staking has been provided or not enough resources were available. If user was already registered, transaction can have msg.value = 0, otherwise that leads to a revert. User is already registered if user's freeStaking or lockedStaking are != 0.
        //@param - resources: amount of resources requested by the user
        function u_assignmentRequest(uint resources) external override payable {

            if (resources == 0) {
                revert ParticipantsLibrary.invalidInput();
            }

            //check is user already registered and registers him if not
            if ((users[msg.sender].freeStaking != 0) || (users[msg.sender].lockedStaking != 0)) {
                //user already registered

                //add funds if some have been sent with transaction to free staking
                users[msg.sender].freeStaking += msg.value;

            } else {
                //user not yet registered

                 //check if user actually sent ETH with the request                
                if (msg.value == 0) {
                    revert ParticipantsLibrary.insufficientFundsSent(msg.value, 1);
                }

                //use amount of ETH sent with assignmentRequest to top up user's amount of staked ETH
                users[msg.sender].freeStaking = msg.value;  

                //report user registration
                emit ParticipantsLibrary.participantEvent(msg.sender,ParticipantsLibrary.SUCCESSFUL_ACCOUNT_CREATION);
                
            }

            //report how much of amount user sent and how much has been added to staking (staking += msg.value - gas) if msg.value > 0
            if (msg.value > 0) {
                emit ParticipantsLibrary.stakingEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(msg.value),ParticipantsLibrary.X_FREE_STAKING_ADD));
            }

            //checks if user has necessary free staking funds for requested assignment, transfers them temporarily to lockedStaking
            if (i_assignmentCheckStaking(msg.sender, resources)) {
                //enough free staking-ETH has been available
                
                //check if resources are available on a node, start assignment and keep staking locked
                i_assignmentCheckResources(msg.sender, resources);

            }
        }

        //@descr - Returns users's data
        //@returns - freeStaking: amount of user's currently unbound staking-ETH
        //@returns - lockedStaking: amount of user's staking-ETH currently bound in an active assignment
        //@returns - activeAssignments: array containing user's assignment's Contract-Addresses
        function u_info() external override view onlyRegistered() returns(uint freeStaking, uint lockedStaking, address[] memory activeAssignments) {

            //set outputs
            return (users[msg.sender].freeStaking,users[msg.sender].lockedStaking, users[msg.sender].activeAssignments);

        }

        //@descr - Adds the ETH (msg.value) sent by a registered user to it's freeStaking and notifies user
        function u_addStaking() external override payable onlyRegistered() {
            //check if transaction contains ETH
            if (msg.value > 0) {
                //transaction contains ETH

                //add sent amount of ETH to users freeStaking            
                users[msg.sender].freeStaking += msg.value;
                
                //notify user of added staking
                emit ParticipantsLibrary.stakingEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(msg.value),ParticipantsLibrary.X_FREE_STAKING_ADD));
            } else {
                //transaction doesn't contain ETH
                revert ParticipantsLibrary.insufficientFundsSent(msg.value,1);
            }
        }

        //@descr - Sends requested amount of nodes freeStaking back to node if available and sends as much as possible (up to freeStaking = 0) otherwise
        //@param - amount: amount of ETH which node wants to withdraw from it's freeStaking
        function u_reduceStaking(uint amount) external override payable onlyRegistered() {
            
            if (amount == 0) {
                //user requested to reduce staking by 0 Wei -> revert to save user gas
                revert ParticipantsLibrary.invalidInput();
            } else if (users[msg.sender].freeStaking < amount) {
                //user does not have to requested amount of freeStaking available
                revert ParticipantsLibrary.insufficientFreeStaking(users[msg.sender].freeStaking, amount);
            } else {
                //available and amount > 0

                users[msg.sender].freeStaking -= amount;                                                                                                                //decrease users' freeStaking by the requested amount
                payable(msg.sender).transfer(amount);                                                                                                                   //sent the requested amount to node's address
                emit ParticipantsLibrary.stakingEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(amount),ParticipantsLibrary.X_FREE_STAKING_SUB));    //notifies user of decrease in freeStaking

                // check if user has any staking left with the contract and closes user's account otherwise
                if ((users[msg.sender].freeStaking == 0) && (users[msg.sender].lockedStaking == 0)) {                             
                    delete users[msg.sender];                                                                                   //delete users' entry since user has no active assignments and no staking
                    emit ParticipantsLibrary.participantEvent(msg.sender, ParticipantsLibrary.SUCCESSFUL_ACCOUNT_DELETION);     //notify user of account's closure
                }
            }
        }

    //assignmentContract functions

        //@descr - reports assignment's completion to user, returns remainingStaking to freeStaking and sends deductedStaking to the BENEFICIARY_ADDRESS. Deletes assignment out of user's activeAssignment's-array
        //@param - userAddress: address of user who initiated assignment
        //@param - initialStaking: initial staking sent to assignmentContract
        //@param - returnedStaking: amount of staking returned by contract (= initialStaking if no punishments were enacted by the AssignmentContract)
        function c_assignmentCompletion(address userAddress, uint initialStaking, uint returnedStaking) external override payable onlyAssignmentContract(userAddress) {

            //reports to user that assignment has been completed
            emit ParticipantsLibrary.assignmentEvent(userAddress, msg.sender, ParticipantsLibrary.ASSIGNMENT_COMPLETION);

            //sent staking that user has to pay as punishment to the BENEFICIARY_ADDRESS
            payable(ParticipantsLibrary.BENEFICIARY_ADDRESS).transfer(initialStaking-returnedStaking);

            //returns given amount of staking to user
            i_assignmentReturnStaking(userAddress, returnedStaking, initialStaking);

            //deletes assignment out of user's activeAssignments-Array
            i_assignmentDeletion(userAddress, msg.sender);

        }

}

