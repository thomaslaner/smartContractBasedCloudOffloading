// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol"; //contains toString

library ParticipantsLibrary {

    //Enumerations
    enum assignmentState {PAYMENT_OUTSTANDING, PAYED, WAITING_FOR_DATA, PROCESSING, NODE_DONE, SUCCESSFULLY_COMPLETED, UNSUCCESSFULLY_COMPLETED}

    //Events
        event contractEvent(string message);                                                                                    //used to send contract's issuer notification that contracts were successfully connected
        event participantEvent(address indexed concernedAddress, string message);                                               //used to sent participant information about it's "account" within the contract
        event stakingEvent(address indexed concernedAddress, string message);                                                   //used to let participant know of changes of their staking balances
        event resourceEvent(address indexed concernedAddress, string message);                                                  //used to let participant know of changes of their resource balances
        event assignmentEvent(address indexed concernedAddress, address assignmentContractAddress, string message);
        event assignmentStateEvent(assignmentState);                                                                            //used to send information of an assignment's state-change to assignment's parties

    //Constants

        address payable constant BENEFICIARY_ADDRESS = payable(address(0));                                                      //used to define address that receives staking-ETH kept by contract when punishments were enacted
        
        //economy (ETH-amounts given in WEI) 

            uint160 constant PERCENTAGE_RESOURCES_TO_PAYMENT = 300;                                                             //factor used to calculate necessary payment-ETH for given amount of resources
            uint160 constant PERCENTAGE_RESOURCES_TO_STAKING = 2*PERCENTAGE_RESOURCES_TO_PAYMENT;                               //factor used to calculate necessary staking-ETH for given amount of resources

            uint8 constant PERCENTAGE_STAKING_PUNISHMENT = 50;                                                                  //percentage of both participant's staking which is deducted for not agreeing on if assignment has been completed successfully or not 

        //event message definitions
        
            //contract events
            string constant SUCCESSFUL_CONNECTION = "connection successfully established";

            string constant ASSIGNMENT_CREATION = "assignment created";
            string constant ASSIGNMENT_COMPLETION = "assignment completed";

            //participant events
            string constant SUCCESSFUL_ACCOUNT_CREATION = "successfully registered";
            string constant SUCCESSFUL_ACCOUNT_DELETION = "successfully closed account";
            
            string constant SUFFICIENT_STAKING = "sufficient amount of staking-ETH provided";
            string constant INSUFFICIENT_STAKING = "insufficient amount of staking-ETH provided";
            
            string constant RESOURCES_NOT_AVAILABLE = "demanded amount of resources currently not available";
            string constant RESOURCES_AVAILABLE = "demanded amount of resources available";
            
            //staking events
            string constant X_FREE_STAKING_ADD = " added to freeStaking";
            string constant X_FREE_STAKING_SUB = " deducted from freeStaking";
            string constant X_LOCKED_STAKING_ADD = " added to lockedStaking";
            string constant X_LOCKED_STAKING_SUB = " deducted from lockedStaking";
            string constant X_BOUND_STAKING_ADD = " added to boundStaking";
            string constant X_BOUND_STAKING_SUB = " deducted from boundStaking";
            
            //resource events
            string constant X_FREE_RESOURCES_ADD = " added to freeResources";
            string constant X_FREE_RESOURCES_SUB = " deducted from freeResources";
            string constant X_LOCKED_RESOURCES_ADD = " added to lockedResources";
            string constant X_LOCKED_RESOURCES_SUB = " deducted from lockedResources";
            string constant X_RESOURCES_ACTIVATED = " resources activated"; 
            string constant X_RESOURCES_DEACTIVATED = " resources deactivated"; 

    //Custom error definitions

        //issuer errors
        error connectionEstablishmentFailed();                                                              //connection with userInstance has already been established

        //participantContract's errors
        error insufficientFreeStaking(uint freeStaking, uint requestedAmount);                              //requested amount "requestedAmount" is greater than available amount "freeStaking" of freeStaking ETH
        error insufficientFundsSent(uint providedValue, uint requiredValue);                                //funds "providedValue" which were sent with transaction were lower than "requiredValue"
        error alreadyRegistered(address node);                                                              //node "node" is already registered
        error deactivateActiveAssignments();                                                                //node has active events and can't be deactivated
        error scheduleDeleteEntryAddressNotContained(address input);                                        //given address is not contained in resourceSchedule
        error noFreeResourcesAvailable();                                                                   //no freeResources are currently available for an assignment
        error invalidInput();                                                                               //given input is invalid
        error assignmentHasDifferentState(assignmentState currentState, assignmentState requiredState);     //assignment has state "currentState" while state "requiredState" would have been required for this transaction
                                                               

    //Functions

        //@desc - conversion from resources to staking
        //@param - resources: amount of resources to be converted into amount of staking
        //@return - staking: derived amount of staking by conversion from resources
        function resourcesToStaking(uint resources) internal pure returns (uint staking) {
            return (resources * ParticipantsLibrary.PERCENTAGE_RESOURCES_TO_STAKING)/100;
        }

        //@desc - conversion from resources to payment
        //@param - resources: amount of resources to be converted into amount of payment
        //@return - payment: derived amount of payment by conversion from resources
        function resourcesToPayment(uint resources) internal pure returns (uint payment) {
            return (resources * ParticipantsLibrary.PERCENTAGE_RESOURCES_TO_PAYMENT)/100;
        }

        //@descr - concatenates two strings
        //@param - a: first string
        //@param - b: second string
        //@return - concatenated string
        function concatenate(string memory a, string memory b) internal pure returns (string memory) {
            return string(abi.encodePacked(a,b));
        }

        //@desc - concatenates a passed number with a passed string and concatenates this with another passed number concatenated with a passed string
        //@param - txt1: first String
        //@param - num1: first number
        //@param - txt2: second string
        //@param - num2: second number
        //@return - output: string which contains num1 concatenated with txt1, which are concatenated with the concatenation of num2 and txt2
        function concatenateTransfer(string memory txt1, uint256 num1, string memory txt2, uint256 num2) internal pure returns (string memory output ) {
            return concatenate(concatenate(concatenate(Strings.toString(num1) ,txt1), ", "), concatenate(Strings.toString(num2) ,txt2));
        }

}