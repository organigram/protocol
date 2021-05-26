var OrganLibrary = artifacts.require("OrganLibrary")
var Organ = artifacts.require("Organ")
// Multihash for CID QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH (empty file)
const EMPTY_FILE_HASH = "0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6"
const HASH_FUNCTION = "0x12"
const HASH_SIZE = "0x20"
const PROCEDURE_EVERYONE = "0x0000000000000000000000000000000000000000"
const PERMISSION_ADD_ENTRIES = "0x0004"

module.exports = async (deployer, network, accounts) => {
  if (network !== "development" && network !== "develop" && network !== "rinkeby" && network !== "rinkeby-fork")
    return;

  const from = accounts[0]
  console.log("Current account", from)

  await Organ.link(OrganLibrary)

  const keyserver = await Organ.new(from, EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE, { from })
  console.log(`* keyserver: ${keyserver.address}`)
  // Everyone can add keys to the keyserver.
  await keyserver.addProcedure(PROCEDURE_EVERYONE, PERMISSION_ADD_ENTRIES, { from })
    .then(data => console.log(`keyserver.addProcedure(PROCEDURE_EVERYONE, PERMISSION_ADD_ENTRIES)`))
  console.log("Permissions set on keyserver.")
}