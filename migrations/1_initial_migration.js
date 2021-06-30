var Migrations = artifacts.require("Migrations")
var CoreLibrary = artifacts.require("CoreLibrary")
var OrganLibrary = artifacts.require("OrganLibrary")
var ProcedureLibrary = artifacts.require("ProcedureLibrary")

module.exports = async (deployer) => {
  // Deploy the Migrations contract as our only task
  console.log("Deploying Migrations.")
  await deployer.deploy(Migrations)
  console.log("Deploying CoreLibrary.")
  await deployer.deploy(CoreLibrary)
  console.log("Deploying OrganLibrary.")
  await deployer.deploy(OrganLibrary)
  console.log("Deploying ProcedureLibrary.")
  await deployer.deploy(ProcedureLibrary)
}
