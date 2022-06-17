//contracts to interact with
//returns contract abstractions which can be used within rest of deployment script
//uses names of contracts and not of source-files
// const ParticipantsLibrary = artifacts.require("ParticipantsLibrary");
const NodeContractArtifact = artifacts.require("NodeContract");
const UserContractArtifact = artifacts.require("UserContract");

//migrations export deployer-function
//deployer-obj is main interface for staging deployment tasks
//executes deployment in sequential order or statements
module.exports = async function(deployer, network, accounts) { 
  
  //deploy libraries
    // await deployer.deploy(ParticipantsLibrary);

  //link already-deployed library to contracts  
    // await deployer.link (ParticipantsLibrary, [UserContractArtifact, NodeContractArtifact]);

  //deploy linked contracts
    //Deploy NodeContract, then deploy UserContract, passing in NodeContract's newly deployed address
    await deployer.deploy(NodeContractArtifact);
    await deployer.deploy(UserContractArtifact, NodeContractArtifact.address);

};
