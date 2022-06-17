//This migration is used to connect the two contracts (UserContract & NodeContract)
//automatically, simplifying the contracts migration. 
//If the issuer prefers to not have the two contracts connect automatically, is suffices
//to delete this file and call UserContracts's function connector() from the issuers address
//after migration

//contracts to interact with
var UserContractArtifact = artifacts.require("UserContract");

//used to establish the connection between UserContract & NodeContract at contract creation
module.exports = function(deployer, network, accounts) { 
  deployer.then(async () => {

    //connect NodeContract with UserContract
    const UserContractInstance = await UserContractArtifact.deployed();
    var connectorExecution = await UserContractInstance.connector({from: accounts[0]});

  });
    
};