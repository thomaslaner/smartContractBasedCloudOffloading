//needed in order to use Migrations-feature

//contracts to interact with
//returns contract abstractions which can be used within rest of deployment script
//uses names of contracts and not of source-files
const Migrations = artifacts.require("Migrations");

module.exports = function (deployer) {
  //Deploy Migrations contract
  deployer.deploy(Migrations);
};
