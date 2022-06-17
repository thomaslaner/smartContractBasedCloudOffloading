// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//Imports
import "./Interfaces.sol";
import "./AssignmentContract.sol";

//Contract
contract NodeContract is NodeContractInternalInterface, NodeContractExternalInterface {
    
    //global definitions

        //contract-related definitions
            address private issuer;                                             //issuer of the contract
            
            address private UserContractAddress;                                //address of connected UserContract
            UserContractInternalInterface private UserContractInstance;         //instance of connected UserContract
            
        //node-related definitions

             struct node {
                uint freeStaking;                                               //# of staking-ETH in WEI which is not currently bound by an assignment
                uint boundStaking;                                              //# of staking-ETH in WEI which is currently bound by resources node provides to contract (not used by the user)
                uint lockedStaking;                                             //# of staking-ETH in WEI which is currently bound by an assignment
                
                address[] activeAssignments;                                    //array containing node's AssignmentContract's addresses
                
                uint freeResources;                                             //# of resources currently not part of an assignment
                uint lockedResources;                                           //# of resources currently part of an assignment
            }

            mapping (address => node) private nodes;                            //mapping of addresses to node-entries representing nodes
            address[] private resourceSchedule;                                 //used for queuing node-addresses for assignment-scheduling

    //modifier definitions

        //onlyIssuer

            function onlyIssuerFunc() internal view {
                require(((msg.sender == issuer) ||(tx.origin == issuer)), "This function is restricted to the contracts issuer");
            }

            modifier onlyIssuer() {
                onlyIssuerFunc();
                _;
            }

        //onlyUserContract

            function onlyUserContractFunc() internal view {
                require(msg.sender == UserContractAddress, "This function is restricted to the connected UserContract");
            }

            modifier onlyUserContract() {
                onlyUserContractFunc();
                _;
            }

        //onlyRegistered

            function onlyRegisteredFunc() internal view {
                require(((nodes[msg.sender].freeStaking != 0) || (nodes[msg.sender].boundStaking != 0) || (nodes[msg.sender].lockedStaking != 0)) == true , "This function is restricted to registered Nodes");
            }
            
            modifier onlyRegistered() {
                onlyRegisteredFunc();
                _;
            }

        //onlyAssignmentContract 

            function onlyAssignmentContractFunc(address nodeAddress) internal view {

                uint8 found;

                for (uint256 i = 0; i < nodes[nodeAddress].activeAssignments.length; i++) {
                    if (msg.sender == nodes[nodeAddress].activeAssignments[i]) {
                        found = 1;
                    }
                }

                require((found == 1), "This function is restricted to node's assignmentContracts");
            }
            
            modifier onlyAssignmentContract(address nodeAddress) {
                onlyAssignmentContractFunc(nodeAddress);
                _;
            } 
        
    //contract creation functions
        
        //@descr - defines issuer
        constructor() {
            issuer = msg.sender;    //define issuer's address   
        }

        //@descr - accepts connection requests by UserContract if not already connected and if contract issuer if the same as transaction issuer
        function connector() external override onlyIssuer() {
            
            if (UserContractAddress != address(0)) {
                revert ParticipantsLibrary.connectionEstablishmentFailed();
            } else {
                //connect the contracts and return true
                UserContractAddress = msg.sender;
                UserContractInstance = UserContractInternalInterface(msg.sender);
            }
        }

    //internal functions

        //resourceSchedule functions

            //@desc - deletes node specified by nodeAddress or index from resourceSchedule. Iterates through resourceSchedule, looks for fitting entry, overwrites that entry when found by shifting the following entries to the left
            //@param - nodeAddress: address of node which should be deleted
            //@param - index: index on which entry can be found (0 if location in array in unknown)
            function i_scheduleDeleteEntry(address nodeAddress, uint256 index) internal {

                //used to store from when on entries have to be shifted to the left (before: 0, afterwards: 1)
                uint8 replace; 
                
                //goes through array - looks for given input and deletes it by shifting every entry from input on to the left - pops last entry in the end
                for (uint256 i = index; i < resourceSchedule.length; i++) {
                    if (resourceSchedule[i] == nodeAddress) {
                        replace = 1;
                    } else if (replace == 1) {
                        resourceSchedule[i-1] = resourceSchedule[i];
                    }
                }
                
                if (replace == 0) {
                    //failsafe
                    revert ParticipantsLibrary.scheduleDeleteEntryAddressNotContained(nodeAddress);
                }

                resourceSchedule.pop(); //delete last entry in array
            
            }

            //@desc - looks for entry with available amount of resources requestedResources
            //@param - requestedResources: requested amount of resources
            //@return - found: indicates if such an entry was found
            //@return - index: index in schedule of entry with requested amount of resources (can be used for quick deletion by i_scheduleDeleteEntry)
            //@return - nodeAddress: address of entry with requested amount of resources  
            function i_scheduleLookForAvailableNode(uint requestedResources) internal view returns(bool found, uint256 index, address nodeAddress) {

                    //go through schedule and look if node has enough freeResources available - if so return node's index in array
                    for (uint256 i = 0; i < resourceSchedule.length; i++) {
                        if (nodes[resourceSchedule[i]].freeResources >= requestedResources) {
                            //return index on which first entry with fitting amount of free resources can be found and return that such an entry has been found
                            return (true, i, resourceSchedule[i]);   
                        }
                    }

                //if no entry with the requested amount of resources can be found
                return (false,0, address(0));
            }

        //assignment completion/BreakOff functions

            //@descr - transfers specified amount of nodeAddress' staking to boundStaking, freeStaking or lockedStaking and takes if from boundStaking, freeStaking or lockedStaking. Reports transfer to node
            //@param - nodeAddress: address of concerned Node
            //@param - amountFrom: amount of Staking to be deducted from one kind of staking
            //@param - amountTo: amount of Staking to be added to another kind of staking
            //@param - operation:
                                //  0: freeStaking -> boundStaking
                                //  1: boundStaking -> lockedStaking
                                //  2: lockedStaking -> freeStaking
                                //  3: boundStaking -> freeStaking
            function i_stakingManagement(address nodeAddress, uint amountFrom, uint amountTo, uint8 operation) internal {

                string memory txt1;
                string memory txt2;

                if (operation == 0) {
                    //freeStaking -> boundStaking

                    //reduce the specified amount of freeStaking and set txt1
                    nodes[nodeAddress].freeStaking -= amountFrom;
                    txt1 = ParticipantsLibrary.X_FREE_STAKING_SUB;

                    //add the specified amount to boundStaking and set txt2
                    nodes[nodeAddress].boundStaking += amountTo;
                    txt2 = ParticipantsLibrary.X_BOUND_STAKING_ADD;

                } else if (operation == 1) {
                    //boundStaking -> lockedStaking 
                    
                    //reduce the specified amount of boundStaking and set txt1
                    nodes[nodeAddress].boundStaking -= amountFrom;
                    txt1 = ParticipantsLibrary.X_BOUND_STAKING_SUB;

                    //add the specified amount to lockedStaking and set txt2
                    nodes[nodeAddress].lockedStaking += amountTo;
                    txt2 = ParticipantsLibrary.X_LOCKED_STAKING_ADD;

                } else if (operation == 2) {
                    //lockedStaking -> freeStaking

                    //reduce the specified amount of lockedStaking and set txt1
                    nodes[nodeAddress].lockedStaking -= amountFrom;
                    txt1 = ParticipantsLibrary.X_LOCKED_STAKING_SUB;

                    //add the specified amount to freeStaking and set txt2
                    nodes[nodeAddress].freeStaking += amountTo;
                    txt2 = ParticipantsLibrary.X_FREE_STAKING_ADD;

                } else if (operation == 3){
                    //boundStaking -> freeStaking

                    //reduce the specified amount of boundStaking and set txt1
                    nodes[nodeAddress].boundStaking -= amountFrom;
                    txt1 = ParticipantsLibrary.X_BOUND_STAKING_SUB;

                    //add the specified amount to freeStaking and set txt2
                    nodes[nodeAddress].freeStaking += amountTo;
                    txt2 = ParticipantsLibrary.X_FREE_STAKING_ADD;

                } else {
                    revert ParticipantsLibrary.invalidInput();
                }         

                //report transfer of staking to user
                emit ParticipantsLibrary.stakingEvent(nodeAddress, ParticipantsLibrary.concatenateTransfer(txt1, amountFrom, txt2, amountTo));
                        
            }

            //@descr - increases or decreased locked resources and does the opposite to free resources depending on the input in operation. 
            //@param - nodeAddress: address of concerned Node
            //@param - resourceAmount: amount of resources to be transferred
            //@param - operation:
                                //  0: ACTIVATION -> freeResources
                                //  1: freeResources -> lockedResources
                                //  2: lockedResources -> DEACTIVATION
            function i_resourceManagement(address nodeAddress, uint256 resourceAmount, uint8 operation) internal  {
            
                //check which operation shall be executed
                if (operation == 0) {
                    //ACTIVATION -> freeResources

                    //add resourceAmount of resources to freeResources
                    nodes[msg.sender].freeResources += resourceAmount;

                    //report increase of freeResources to node
                    emit ParticipantsLibrary.participantEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(resourceAmount), ParticipantsLibrary.X_RESOURCES_ACTIVATED));


                } else if (operation == 1) {
                    //freeResources -> lockedResources

                    //edit balances
                    nodes[nodeAddress].lockedResources += resourceAmount;
                    nodes[nodeAddress].freeResources -= resourceAmount;

                    //report transfer of resources to node
                    emit ParticipantsLibrary.resourceEvent(nodeAddress, ParticipantsLibrary.concatenateTransfer(ParticipantsLibrary.X_LOCKED_RESOURCES_ADD, resourceAmount, ParticipantsLibrary.X_FREE_RESOURCES_SUB, resourceAmount));

                } else if (operation == 2) {
                    //lockedResources -> DEACTIVATION

                    //deactivate resources
                    nodes[nodeAddress].lockedResources -= resourceAmount;

                    //report decrease of freeResources to node
                    emit ParticipantsLibrary.participantEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(resourceAmount), ParticipantsLibrary.X_RESOURCES_DEACTIVATED));


                }
            }

            //@descr - deletes assignment out of activeAssignments 
            //@param - nodeAddress: address of concerned Node
            //@param - assignmentAddress: address of assignment which shall be deleted out of node's activeAssignments-array
            function i_assignmentDeletion(address nodeAddress, address assignmentAddress) internal {
                //delete assignment's entry out of user's storage

                //loop through activeAssignments-array and overwrite entry with passed assignmentAddress by last assignment in array - pop last element 
                for (uint256 i = 0; i < nodes[nodeAddress].activeAssignments.length; i++) {
                    if (nodes[nodeAddress].activeAssignments[i] == assignmentAddress) {
                        
                        //overwrite assignment and pop last element in array with, which assignment has been overwritten with, out of the array
                        nodes[nodeAddress].activeAssignments[i] = nodes[nodeAddress].activeAssignments[nodes[nodeAddress].activeAssignments.length-1];
                        nodes[nodeAddress].activeAssignments.pop();
                        
                        break; //skip rest of loop since assignment has been found and was overwritten
                    }
                }
            }

    //node functions

        //node activation/deactivation functions

            //@desc - used to activate nodes if they are not already registered and if they specified a amount of resources (> 0) which does not require a greater amount of staking-ETH than the node provided in msg.value
            //@param - resources: amount of resources which nodes wants to activate
            function n_activate(uint resources) external override payable {

                //request validation

                    //check that node is not already registered by checking if it has ETH staked with contract in some way
                    if (((nodes[msg.sender].freeStaking != 0) || (nodes[msg.sender].boundStaking != 0) || (nodes[msg.sender].lockedStaking != 0))) {
                        revert ParticipantsLibrary.alreadyRegistered(msg.sender);
                    }

                    uint requiredStaking = ParticipantsLibrary.resourcesToStaking(resources);

                    //check that node passed correct inputs
                    if (resources == 0) {
                        //if node specified 0 as amount of resources it wants to provide
                        revert ParticipantsLibrary.invalidInput();
                    } else if (msg.value < requiredStaking) {
                        //if node didn't sent enough staking-ETH for amount of resources it wants to provide to the network
                        revert ParticipantsLibrary.insufficientFundsSent(msg.value,requiredStaking);
                    }

                //node creation

                    //report node registration
                    emit ParticipantsLibrary.participantEvent(msg.sender,ParticipantsLibrary.SUCCESSFUL_ACCOUNT_CREATION);

                    //staking

                        nodes[msg.sender].boundStaking = requiredStaking;               //add #ETH required to cover staking of resources
                        nodes[msg.sender].freeStaking = msg.value - requiredStaking;    //add #ETH not required to cover staking

                        //report how much ETH has been added to free- & bound-Staking
                        emit ParticipantsLibrary.stakingEvent(msg.sender, ParticipantsLibrary.concatenateTransfer(ParticipantsLibrary.X_BOUND_STAKING_ADD, requiredStaking, ParticipantsLibrary.X_FREE_STAKING_ADD, (msg.value-requiredStaking)));

                    //resources

                        //activates the given amount of resources and notifies node
                        i_resourceManagement(msg.sender, resources, 0);

                    //resourceSchedule

                        //push node's address onto scheduling-array
                        resourceSchedule.push(msg.sender);
                        
            }
            
            //@desc - used to deactivate nodes if it currently doesn't have active assignments
            function n_deactivate() onlyRegistered() external override payable {
                
                if (nodes[msg.sender].lockedResources == 0) {
                    //node doesn't have active assignment and can be deleted
                        
                        i_scheduleDeleteEntry(msg.sender, 0);                                                           //delete node from queue
                        payable(msg.sender).transfer(nodes[msg.sender].freeStaking + nodes[msg.sender].boundStaking);   //send total amount of nodes staked ETH back to it (lockedStaking has to be 0 since no current assignments)
                        delete nodes[msg.sender];                                                                       //delete node's entry in mapping
                        
                        //report node's successful deletion
                        emit ParticipantsLibrary.participantEvent(msg.sender, ParticipantsLibrary.SUCCESSFUL_ACCOUNT_DELETION);

                } else {
                    //node has active assignments and can't be deleted
                    revert ParticipantsLibrary.deactivateActiveAssignments();
                }
            }

        //node update functions
        
            //@descr - Returns node's data
            //@returns - freeStaking: amount of node's currently unbound staking-ETH
            //@returns - boundStaking: amount of node's staking-ETH currently bound to provided resources 
            //@returns - lockedStaking: amount of node's staking-ETH currently bound in an active assignment
            //@returns - activeAssignments: array containing user's active AssignmentContract-addresses
            //@returns - freeResources: amount of nodes resources which are currently available for a new assignment
            //@returns - lockedResources: amount of nodes resources which are currently locked in an assignment
            function n_info() external override view onlyRegistered() returns(uint freeStaking, uint boundStaking, uint lockedStaking, address[] memory activeAssignments, uint freeResources, uint lockedResources) {
                
                //set outputs
                return (nodes[msg.sender].freeStaking,nodes[msg.sender].boundStaking, nodes[msg.sender].lockedStaking, nodes[msg.sender].activeAssignments, nodes[msg.sender].freeResources, nodes[msg.sender].lockedResources);

            }

        //node staking-management functions

            //@descr - adds the ETH sent by a registered node to it's freeStaking balances if that amount is > 0, otherwise reverts the transaction
            function n_addStaking() external override payable onlyRegistered() {

                //check if transaction contains ETH
                if (msg.value > 0) {
                    //transaction contains ETH

                    //add sent amount of ETH to users freeStaking            
                    nodes[msg.sender].freeStaking += msg.value;
                    
                    //notify user of added staking
                    emit ParticipantsLibrary.stakingEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(msg.value),ParticipantsLibrary.X_FREE_STAKING_ADD));
                
                } else {
                    //transaction doesn't contain ETH
                    revert ParticipantsLibrary.insufficientFundsSent(msg.value,1);
                }

            }

            //@descr - sends requested amount of nodes freeStaking back to node if available, amount > 0 and if afterwards the node still has at least some amount of some kind of staking, staked with the contract. Otherwise sends the available amount back to node's EOW or reverts the transaction if node called function with invalid inputs (amount = 0)
            //@param - amount: amount of ETH which node wants to withdraw from it's freeStaking
            function n_reduceStaking(uint amount) external override payable onlyRegistered() {
                
                //check if requested amount > 0 and if requested amount is available in node's freeStaking
                if (amount == 0) {
                    //node requested to reduce staking by 0 Wei -> revert to save node gas
                    revert ParticipantsLibrary.invalidInput();
                } else if (nodes[msg.sender].freeStaking < amount) {
                    //node does not have to requested amount of resources available as freeStaking
                    revert ParticipantsLibrary.insufficientFreeStaking(nodes[msg.sender].freeStaking, amount);
                } else if ((amount == nodes[msg.sender].freeStaking) && (nodes[msg.sender].lockedStaking == 0) && (nodes[msg.sender].boundStaking == 0)) {
                    //request would delete node's entry which is only possible by n_deactivate
                    revert ParticipantsLibrary.invalidInput();
                } else {
                    //valid request
                    nodes[msg.sender].freeStaking -= amount;    //decrease nodes' freeStaking by the requested amount
                    payable(msg.sender).transfer(amount);       //sent the requested amount to node's address
                    emit ParticipantsLibrary.stakingEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(amount),ParticipantsLibrary.X_FREE_STAKING_SUB));
                }
            }

        //node resource-management functions

            //@descr - used to activate additional resources if enough freeStaking is stored in node's account, revert otherwise with error insufficientFreeStaking()
            //@param - resourceAmount: amount of resources node wants to activate
            function n_addResources(uint resourceAmount) external override onlyRegistered() {

                if (resourceAmount == 0) {
                    revert ParticipantsLibrary.invalidInput();
                }

                uint requiredStaking = ParticipantsLibrary.resourcesToStaking(resourceAmount);

                //check if node has enough freeStaking staked with account
                if (nodes[msg.sender].freeStaking >= requiredStaking) {
                    //enough freeStaking available

                    //transfers specified amount of nodeAddress' staking to boundStaking from freeStaking. Reports transfer to node
                    i_stakingManagement(msg.sender, requiredStaking, requiredStaking, 0);

                    i_resourceManagement(msg.sender, resourceAmount, 0);

                } else {
                    //not enough freeStaking available
                    revert ParticipantsLibrary.insufficientFreeStaking(nodes[msg.sender].freeStaking, requiredStaking);
                }

            }

            //@descr - used to deactivate resourceAmount of resources if possible. If not enough resources are currently listed in freeResources, as much as possible is deactivated or revert if no resources are available at all
            //@param - resourceAmount: amount of resources node wants to deactivate
            function n_reduceResources(uint resourceAmount) external override onlyRegistered() {

                //check if input and node's freeResources are > 0
                if (resourceAmount == 0) {
                    revert ParticipantsLibrary.invalidInput();
                } else if (nodes[msg.sender].freeResources == 0) {
                    //node doesn't have free Resources which could be deactivated
                    revert ParticipantsLibrary.noFreeResourcesAvailable();
                } else {
                    //node has freeResources which can be deactivated

                    uint deactivatedResourceAmount;

                    //resource management
                        if (nodes[msg.sender].freeResources >= resourceAmount) {
                            //node has enough free Resources
                            deactivatedResourceAmount = resourceAmount;
                            nodes[msg.sender].freeResources -= resourceAmount;
                        } else {
                            //node doesn't have enough free Resources - deactivate what is currently available
                            deactivatedResourceAmount = nodes[msg.sender].freeResources;
                            nodes[msg.sender].freeResources = 0;
                        }

                        //report decrease of freeResources to node
                        emit ParticipantsLibrary.participantEvent(msg.sender, ParticipantsLibrary.concatenate(Strings.toString(deactivatedResourceAmount), ParticipantsLibrary.X_RESOURCES_DEACTIVATED));

                    //staking management

                        //transfers specified amount of nodeAddress' staking to freeStaking from boundStaking. Reports transfer to node
                        uint stakingOfDeactivatedResources = ParticipantsLibrary.resourcesToStaking(deactivatedResourceAmount);
                        i_stakingManagement(msg.sender, stakingOfDeactivatedResources, stakingOfDeactivatedResources, 3);
                }
            }

    //UserContract functions

        //@descr - Searches schedule for node with an requestedResources-amount of resources available. If fitting node was found: initiates new assignment by changing that node's balance of free- & locked-Resources, creating a new AssignmentContract with the parameters given by the input, adding a new entry in node's assignment-entry and returning the address of the newly created AssignmentContract to the user. If no fitting node could be found - return address(0) in order to let user know that requested resources are currently not available
        //@param - userAddress: address of requesting user
        //@param - requestedResources: amount of resources user requested
        //@returns - createdAssignment: assignment which Node created (.partner entry has to be adjusted for user)
        function c_resourceRequest (address userAddress, uint requestedResources) external override onlyUserContract() returns (address newAssignmentContractAddress)  {

            //variables
            bool found;             //indicates if requested amount of resource could be found
            uint256 indexFound;     //index of entry
            address nodeAddress;    //address of entry 

            //check if requested amount of resources are available
            (found,indexFound,nodeAddress) = i_scheduleLookForAvailableNode(requestedResources);

            if (found == true) {
                //if node with enough resources has been found

                //update node's scheduling-entry & resources

                    //delete node from old scheduling position
                    i_scheduleDeleteEntry(nodeAddress, indexFound);
                    
                    //transfers specified amount of nodeAddress' staking to lockedStaking from boundStaking and notifies node
                    uint stakingOfRequestedResources = ParticipantsLibrary.resourcesToStaking(requestedResources);
                    i_stakingManagement(nodeAddress, stakingOfRequestedResources, stakingOfRequestedResources, 1);

                    //transfer assignment's freeResources to lockedResources and notifies node
                    i_resourceManagement(nodeAddress, requestedResources, 1);

                    //adds node to new scheduling position at tail of queue
                    resourceSchedule.push(nodeAddress);

                // create newAssignment & add it to new assignment to nodes' assignments-array

                        //create new contract
                        AssignmentContract newAssignmentContract = new AssignmentContract(userAddress, nodeAddress, UserContractAddress, address(this), requestedResources);
                        address assignmentContractAddress = address(newAssignmentContract);

                        //add new Assignment to the assignmentIndexes-Array
                        nodes[nodeAddress].activeAssignments.push(assignmentContractAddress);

                //outputs

                    //notifies node of newly created AssignmentContract
                    emit ParticipantsLibrary.assignmentEvent(nodeAddress, assignmentContractAddress, ParticipantsLibrary.ASSIGNMENT_CREATION);
                    
                    //returns address of newly created AssignmentContract
                    return (assignmentContractAddress);

            } else {
                //if no node with enough resources could be found

                //returns address 0 as a sign that requested resources are currently not available
                return address(0);

            }
        }

    //AssignmentContract functions


    //@descr - reports assignment's completion to node, returns remainingStaking to freeStaking and sends deductedStaking to the BENEFICIARY_ADDRESS. Deactivates lockedResources used by the contract (node can reactivate them afterwards to show readiness for new assignment if node has enough freeStaking available). Deletes assignment out of node's activeAssignment's-array
    //@param - nodeAddress: address of node which processed assignment
    //@param - initialStaking: initial staking sent to assignmentContract
    //@param - returnedStaking: amount of staking returned by contract (= initialStaking if no punishments were enacted by the AssignmentContract)
    function c_assignmentCompletion(address nodeAddress, uint resources, uint initialStaking, uint returnedStaking) external override payable onlyAssignmentContract(nodeAddress) {

        //reports to node that assignment has been completed
        emit ParticipantsLibrary.assignmentEvent(nodeAddress, msg.sender, ParticipantsLibrary.ASSIGNMENT_COMPLETION);

        //sent staking that node has to pay as punishment to the BENEFICIARY_ADDRESS
        payable(ParticipantsLibrary.BENEFICIARY_ADDRESS).transfer(initialStaking-returnedStaking);

        //returns amount of staking which has been returned by assignment to freeStaking and deletes the initial amount of the assignment's staking out of lockedStaking
        i_stakingManagement(nodeAddress, initialStaking, returnedStaking, 2);

        //deactivates node's resources (have to be reactivated from node if node wants to provide them again)
        i_resourceManagement(nodeAddress,resources,2);

        //deletes the assignment out of node's activeAssignments-array
        i_assignmentDeletion(nodeAddress, msg.sender);

    }

        
}