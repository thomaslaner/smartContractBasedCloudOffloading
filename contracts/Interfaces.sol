// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ParticipantsLibrary.sol";

//internally-used interfaces

    //@descr - contains functions implemented in both contracts
    interface InternalParticipantInterface {

        //@descr - used to connect the userContract to the nodeContract
        function connector() external;
    }

    //@descr - contains functions of userContract which are called by nodeContract
    interface UserContractInternalInterface is InternalParticipantInterface {

        //@descr - reports assignment's completion to user, returns staking returned by the AssignmentContract to freeStaking and deducts amount of staking sent initially to AssignmentContract from user's lockedStaking. Deletes assignment out of user's activeAssignment's-array
        //@param - userAddress: address of user who initiated assignment
        //@param - initialStaking: initial staking sent to assignmentContract
        //@param - returnedStaking: amount of staking returned by contract (= initialStaking if no punishments were enacted by the AssignmentContract)
        function c_assignmentCompletion(address participantAddress, uint initialStaking, uint returnedStaking) external payable;

    }

    //@descr - contains functions of nodeContract which are called by userContract
    interface NodeContractInternalInterface is InternalParticipantInterface {
    
        //@descr - Searches schedule for node with an requestedResources-amount of resources available. If fitting node was found: initiates new assignment by changing that node's balance of free- & locked-Resources, creating a new AssignmentContract with the parameters given by the input, adding a new entry in node's assignment-entry and returning the address of the newly created AssignmentContract to the user. If no fitting node could be found - return address(0) in order to let user know that requested resources are currently not available
        //@param - userAddress: address of requesting user
        //@param - requestedResources: amount of resources user requested
        //@returns - createdAssignment: assignment which Node created (.partner entry has to be adjusted for user)
        function c_resourceRequest (address userAddress, uint requestedResources) external returns (address assignmentAddress);

        //@descr - reports assignment's completion to node, returns staking returned by the AssignmentContract to freeStaking and deducts amount of staking sent initially to AssignmentContract from node's lockedStaking. Deactivates lockedResources used by the contract (node can reactivate them afterwards to show readiness for new assignment if node has enough freeStaking available). Deletes assignment out of node's activeAssignment's-array
        //@param - nodeAddress: address of node which processed assignment
        //@param - initialStaking: initial staking sent to assignmentContract
        //@param - returnedStaking: amount of staking returned by contract (= initialStaking if no punishments were enacted by the AssignmentContract)
        function c_assignmentCompletion(address participantAddress, uint resources, uint initialStaking, uint returnedStaking) external payable;
    }

//externally-used interfaces

    //external-NodeContract Interface
    interface NodeContractExternalInterface {

        //node activation/deactivation functions

            //@desc - used to activate nodes if they are not already registered and if they specified a amount of resources (> 0) which does not require a greater amount of staking-ETH than the node provided in msg.value
            //@param - resources: amount of resources which nodes wants to activate
            function n_activate(uint resources) external payable;
            
            //@desc - used to deactivate nodes if it currently doesn't have active assignments
            function n_deactivate() external payable;

        //node update functions
        
            //@descr - Returns node's data
            //@returns - freeStaking: amount of node's currently unbound staking-ETH
            //@returns - boundStaking: amount of node's staking-ETH currently bound to provided resources 
            //@returns - lockedStaking: amount of node's staking-ETH currently bound in an active assignment
            //@returns - activeAssignments: array containing user's active AssignmentContract-addresses
            //@returns - freeResources: amount of nodes resources which are currently available for a new assignment
            //@returns - lockedResources: amount of nodes resources which are currently locked in an assignment
            function n_info() external view returns(uint freeStaking, uint boundStaking, uint lockedStaking, address[] memory activeAssignments, uint freeResources, uint lockedResources);

        //node staking-management functions

            //@descr - adds the ETH sent by a registered node to it's freeStaking balances if that amount is > 0, otherwise reverts the transaction
            function n_addStaking() external payable;

            //@descr - sends requested amount of nodes freeStaking back to node if available, amount > 0 and if afterwards the node still has at least some amount of some kind of staking, staked with the contract. Otherwise sends the available amount back to node's EOW or reverts the transaction if node called function with invalid inputs (amount = 0)
            //@param - amount: amount of ETH which node wants to withdraw from it's freeStaking
            function n_reduceStaking(uint amount) external payable;

        //node resource-management functions

            //@descr - used to activate additional resources if enough freeStaking is stored in node's account, revert otherwise with error insufficientFreeStaking()
            //@param - resourceAmount: amount of resources node wants to activate
            function n_addResources(uint resourceAmount) external;

            //@descr - used to deactivate resourceAmount of resources if possible. If not enough resources are currently listed in freeResources, as much as possible is deactivated or revert if no resources are available at all
            //@param - resourceAmount: amount of resources node wants to deactivate
            function n_reduceResources(uint resourceAmount) external;


    }

    //external-UserContract Interface
    interface UserContractExternalInterface {

        //user assignment creation functions

            //@descr - Registers user if not yet registered, adds sent funds to freeStaking, checks if freeStaking contains enough ETH for the requested amount of resources and if so, looks for a node with those resources available. If such a node is found, transfer necessary staking for the duration of the assignment to lockedStaking and initiate the assignment. Reports to user if not enough staking has been provided or not enough resources were available. If user was already registered, transaction can have msg.value = 0, otherwise that leads to a revert. User is already registered if user's freeStaking or lockedStaking are != 0.
            //@param - resources: amount of resources requested by the user
            function u_assignmentRequest(uint resources) external payable;

        //user update functions

            //@descr - Returns users's data
            //@returns - freeStaking: amount of user's currently unbound staking-ETH
            //@returns - lockedStaking: amount of user's staking-ETH currently bound in an active assignment
            //@returns - activeAssignments: array containing user's assignment's Contract-Addresses
            function u_info() external view returns(uint freeStaking, uint lockedStaking, address[] memory activeAssignments);

        //user staking-management functions

            //@descr - Adds the ETH (msg.value) sent by a registered user to it's freeStaking and notifies user
            function u_addStaking() external payable;

            //@descr - Sends requested amount of nodes freeStaking back to node if available and sends as much as possible (up to freeStaking = 0) otherwise
            //@param - amount: amount of ETH which node wants to withdraw from it's freeStaking
            function u_reduceStaking(uint amount) external payable;
    }

    //external

    interface AssignmentContractExternalInterface {
        //returns information about assignment to caller
        //@return - assignmentResources: resources used by assignment
        //@return - assignmentStaking: staking-ETH (in WEI)
        //@return - assignmentPayment: payment-ETH (in WEI)
        //@return - currentState: current state of assignment
        function info() external view returns(uint assignmentResources, uint assignmentStaking, uint assignmentPayment, ParticipantsLibrary.assignmentState currentState);
    }

    interface AssignmentContractExternalUserInterface is AssignmentContractExternalInterface {

    //user functions

        //@descr - changes state to PAYED if user called function with msg.value >= required amount of payment-ETH while state was PAYMENT_OUTSTANDING
        function u_assignmentPayment() external payable;

        //@descr - returns node's data-transfer-address if function is called by user and state is WAITING_FOR_DATA
        //@returns - dataTransferAddress: node's dataTransferAddress to which user shall sent data
        function u_assignmentDataTransferAddress() external view returns(string memory dataTransferAddress);

        //@descr - returns staking fully to participants and sends payment to node if user accepts node's output which user received over off-chain channel. Deducts staking by a certain amount of punishment-percentage which is then sent to a BENEFICIARY_ADDRESS specified in the contract's constants and sends payment-ETH back to user if user doesn't accept data. 
        //@param - outputCorrect: defines if user accepts node output or not (0: not accepted, 1: accepted, >1: invalid Input)
        function u_assignmentCompletion(uint8 outputCorrect) external;

    }
    
    interface AssignmentContractExternalNodeInterface is AssignmentContractExternalInterface {

        //@descr - changes state to WAITING_FOR_DATA is node sent a valid dataTransferAddress in the state PAYED
        //@param - dataTransferAddress: address used for sending off-chain data between the participants (user sends data to this address and node sends output back to address user sent it's data from)
        function n_waitingForData(string memory dataTransferAddress) external;

        //@descr - changes state to PROCESSING if node calls this function while state is WAITING_FOR_DATA. Used after node received user's input-data over off-chain mode-of-transfer
        function n_processing() external;

        //@descr - changes state to NODE_DONE if node calls this function while state is PROCESSING. Used when node is done processing user's input-data and after node sent output-data to back to the address user sent the input-data from
        function n_done() external;

    }
