var Migrations = artifacts.require("Migrations")
var MetadataLibrary = artifacts.require("MetadataLibrary")
var OrganLibrary = artifacts.require("OrganLibrary")
var ProcedureLibrary = artifacts.require("ProcedureLibrary")

module.exports = async (deployer) => {
  // Deploy the Migrations contract as our only task
  await deployer.deploy(Migrations)
  await deployer.deploy(MetadataLibrary)
  await deployer.deploy(OrganLibrary)
  await deployer.deploy(ProcedureLibrary)
}
