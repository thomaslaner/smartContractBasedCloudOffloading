// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

//Imports
import "./Interfaces.sol";

//Contract
contract AssignmentContract is AssignmentContractExternalUserInterface, AssignmentContractExternalNodeInterface {

    //global definitions

        address private userContractAddress;                                //address of connected UserContract
        address private nodeContractAddress;                                //address of connected NodeContract

        NodeContractInternalInterface private NodeContractInstance;         //instance of connected NodeContract
        UserContractInternalInterface private UserContractInstance;         //instance of connected UserContract

        address private userAddress;                                        //address of the user which initiated the assignment
        address private nodeAddress;                                        //address of the node which processes the assignment

        string private nodeDataTransferAddress;                             //address to which the user shall sent the assignment's data (must be set in the state PAYED and can't be edited later)
        
        ParticipantsLibrary.assignmentState private state;                  //current state of assignment

        uint private resources;                                             //resources used by assignment
        uint private staking;                                               //staking-ETH (in WEI) to ensure both parties have successful completion of assignment in mind
        uint private payment;                                               //payment-ETH (in WEI) necessary for assignment
        
    //modifier definitions

        //onlyUser

            function onlyUserFunc() internal view {
                require(msg.sender == userAddress, "This function is restricted to the connected user");
            }

            modifier onlyUser() {
                onlyUserFunc();
                _;
            }

        //onlyNode

            function onlyNodeFunc() internal view {
                require(msg.sender == nodeAddress, "This function is restricted to the connected node");
            }

            modifier onlyNode() {
                onlyNodeFunc();
                _;
            }

    //contract functions

        //@descr - set's NodeContractInstance, UserContractInstance, userContractAddress, nodeContractAddress, userAddress, nodeAddress, state, resources, staking and payment according to passed input-values 
        //@param - connectedUser: address of user that initiated the assignment
        //@param - connectedNode: address of the node that processes the assignment
        //@param - connectedUserContract: UserContract in which connectedUser is stored
        //@param - connectedUserContract: NodeContract in which connectedNode is stored and which created the AssignmentContract
        //@param - assignmentResources: Resources used by the assignment
        constructor(address connectedUser, address connectedNode, address connectedUserContract, address connectedNodeContract, uint assignmentResources) { 

            NodeContractInstance = NodeContractInternalInterface(connectedNodeContract); 
            UserContractInstance = UserContractInternalInterface(connectedUserContract); 
            
            userContractAddress = connectedUserContract;
            nodeContractAddress = connectedNodeContract;

            userAddress = connectedUser;            
            nodeAddress = connectedNode;

            state = ParticipantsLibrary.assignmentState.PAYMENT_OUTSTANDING;

            resources = assignmentResources;
            staking = ParticipantsLibrary.resourcesToStaking(resources);
            payment = ParticipantsLibrary.resourcesToPayment(resources);
            
        }

    //user functions

        //returns information about assignment to caller
        //@return - assignmentResources: resources used by assignment
        //@return - assignmentStaking: staking-ETH (in WEI)
        //@return - assignmentPayment: payment-ETH (in WEI)
        //@return - currentState: current state of assignment
        function info() external override view returns(uint assignmentResources, uint assignmentStaking, uint assignmentPayment, ParticipantsLibrary.assignmentState currentState) {
            return(resources, staking, payment, state);
        }

        //@descr - changes state to PAYED if user called function with msg.value >= required amount of payment-ETH while state was PAYMENT_OUTSTANDING
        function u_assignmentPayment() external override onlyUser() payable {

            //check if assignment is in state PAYMENT_OUTSTANDING
            if (state == ParticipantsLibrary.assignmentState.PAYMENT_OUTSTANDING) {
                //assignment has correct state

                //check if transaction contained at least the required amount
                if (msg.value >= payment) {
                    //if amount >= required amount has been sent
                    
                    if (msg.value > payment) {
                        //sent rest back to user
                        payable(msg.sender).transfer(msg.value-payment);
                    }

                    //update state
                    c_updateState(ParticipantsLibrary.assignmentState.PAYED);

                } else {
                    //not enough ETH sent
                    revert ParticipantsLibrary.insufficientFundsSent(msg.value, payment); 
                }
            
            } else {
                //assignment has wrong state
                revert ParticipantsLibrary.assignmentHasDifferentState(state, ParticipantsLibrary.assignmentState.PAYMENT_OUTSTANDING);
            }
        }

        //@descr - returns node's data-transfer-address if function is called by user and state is WAITING_FOR_DATA
        //@returns - dataTransferAddress: node's dataTransferAddress to which user shall sent data
        function u_assignmentDataTransferAddress() external override view onlyUser() returns(string memory dataTransferAddress) {

            //check that assignment has state WAITING_FOR_DATA
            if (state == ParticipantsLibrary.assignmentState.WAITING_FOR_DATA) {
                //assignment has correct state
                
                //return nodes' data-transfer-address to user
                return nodeDataTransferAddress;
            } else {
                //assignment has wrong state
                revert ParticipantsLibrary.assignmentHasDifferentState(state, ParticipantsLibrary.assignmentState.WAITING_FOR_DATA);
            }
        }

        //@descr - returns staking fully to participants and sends payment to node if user accepts node's output which user received over off-chain channel. Deducts staking by a certain amount of punishment-percentage which is then sent to a BENEFICIARY_ADDRESS specified in the contract's constants and sends payment-ETH back to user if user doesn't accept data. 
        //@param - outputCorrect: defines if user accepts node output or not (0: not accepted, 1: accepted, >1: invalid Input)
        function u_assignmentCompletion(uint8 outputCorrect) external override onlyUser(){

            //check if assignment is in state NODE_DONE
            if (state == ParticipantsLibrary.assignmentState.NODE_DONE) {
                //assignment has correct state

                //check is user thinks that node's output was correct
                if (outputCorrect == 1) {
                    //user accepts output provided by node to user over external channel

                    //update state of assignment and notify participants
                    c_updateState(ParticipantsLibrary.assignmentState.SUCCESSFULLY_COMPLETED);

                    //sent user's payment to node
                    payable(nodeAddress).transfer(payment);

                    //return staking fully to the participants
                    UserContractInstance.c_assignmentCompletion(userAddress, staking, staking);
                    NodeContractInstance.c_assignmentCompletion(nodeAddress, resources, staking, staking);

                } else if (outputCorrect == 0) {
                    //user does not accept work done by node

                    //update state of assignment and notify participants
                    c_updateState(ParticipantsLibrary.assignmentState.UNSUCCESSFULLY_COMPLETED);

                    //return user's payment to user
                    payable(userAddress).transfer(payment);

                    //staking

                        //calculate amount of staking not deducted by punishment
                        uint remainingStaking =  c_remainingStakingCalculation(staking);

                        //return remaining staking to the participants and sent punishmentStaking to BENEFICIARY_ADDRESS
                        UserContractInstance.c_assignmentCompletion(userAddress, staking, remainingStaking);
                        NodeContractInstance.c_assignmentCompletion(nodeAddress, resources, staking, remainingStaking);

                } else {
                    //outputCorrect > 1 -> invalidInput
                    revert ParticipantsLibrary.invalidInput();
                }

                //contract deletion (ETH remaining with the contract (includes punishment-staking sent to BENEFICIARY_ADDRESS) is sent to BENEFICIARY_ADDRESS on destruction)
                selfdestruct(ParticipantsLibrary.BENEFICIARY_ADDRESS);

            } else {
                //assignment has wrong state
                revert ParticipantsLibrary.assignmentHasDifferentState(state, ParticipantsLibrary.assignmentState.NODE_DONE);
            }
            
        }

    //node functions

        //@descr - changes state to WAITING_FOR_DATA is node sent a valid dataTransferAddress in the state PAYED
        //@param - dataTransferAddress: address used for sending off-chain data between the participants (user sends data to this address and node sends output back to address user sent it's data from)
        function n_waitingForData(string memory dataTransferAddress) external override onlyNode() {
            
            //check if assignment has correct state
            if (state == ParticipantsLibrary.assignmentState.PAYED) {
                        
                        //check if node set valid dataTransferAddress
                        if (c_checkInputAddress(dataTransferAddress)) {

                            //set dataTransferAddress
                            nodeDataTransferAddress = dataTransferAddress;

                            //update state and notify participants
                            c_updateState(ParticipantsLibrary.assignmentState.WAITING_FOR_DATA);
                            
                        } else {
                            //invalid dataTransferAddress set by node
                            revert ParticipantsLibrary.invalidInput();
                        }
            } else {
                //assignment has wrong state
                revert ParticipantsLibrary.assignmentHasDifferentState(state, ParticipantsLibrary.assignmentState.PAYED);
            }     
        }

        //@descr - changes state to PROCESSING if node calls this function while state is WAITING_FOR_DATA. Used after node received user's input-data over off-chain mode-of-transfer
        function n_processing() external override onlyNode() {
            //check if current state if WAITING_FOR_DATA
            if (state == ParticipantsLibrary.assignmentState.WAITING_FOR_DATA) {
                //function called in correct state

                //update state and notify participants
                c_updateState(ParticipantsLibrary.assignmentState.PROCESSING);
            } else {
                //function called in incorrect state
                revert ParticipantsLibrary.assignmentHasDifferentState(state, ParticipantsLibrary.assignmentState.WAITING_FOR_DATA);
            }
        }

        //@descr - changes state to NODE_DONE if node calls this function while state is PROCESSING. Used when node is done processing user's input-data and after node sent output-data to back to the address user sent the input-data from
        function n_done() external override onlyNode() {
            //check if current state if PROCESSING
            if (state == ParticipantsLibrary.assignmentState.PROCESSING) {
                //function called in correct state

                //update state and notify participants
                c_updateState(ParticipantsLibrary.assignmentState.NODE_DONE);
            } else {
                //function called in incorrect state
                revert ParticipantsLibrary.assignmentHasDifferentState(state, ParticipantsLibrary.assignmentState.PROCESSING);
            }
        }

    //contract functions

        //@descr - changes state to newState and notifies participants
        //@param - newState: state which shall used to replace to old one
        function c_updateState(ParticipantsLibrary.assignmentState newState) internal {
                
            //change state
            state = newState;

            //notify participants of state-change
            emit ParticipantsLibrary.assignmentStateEvent(newState);

        }

        //@descr - checks if inputAddress if a valid dataTransferAddress
        //@param - inputAddress: address sent by node which has to be checked
        //@return - validAddress: true if address is valid or not
        function c_checkInputAddress(string memory inputAddress) internal pure returns (bool validAddress) {
            
            //checks if address passed by node is not empty
            return (bytes(inputAddress).length != 0);
        
        }

        //@descr - calculates amount of staking not deducted by enacted punishment
        //@param - initialStaking: initial amount of staking
        //@return - remainingStaking: remaining amount of staking after punishment-related deduction
        function c_remainingStakingCalculation(uint initialStaking) internal pure returns (uint remainingStaking){
            remainingStaking = initialStaking-((initialStaking * ParticipantsLibrary.PERCENTAGE_STAKING_PUNISHMENT)/100);
        }
}