var CID = require("cids")
var CoreLibrary = artifacts.require("CoreLibrary")
var Organigram = artifacts.require("Organigram")
var OrganLibrary = artifacts.require("OrganLibrary")
var ProcedureLibrary = artifacts.require("ProcedureLibrary")
var Organigram = artifacts.require("Organigram")
var Organ = artifacts.require("Organ")
var NominationProcedure = artifacts.require("NominationProcedure")
var VoteProcedure = artifacts.require("VoteProcedure")

// Multihash for CID QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH (empty file)
const EMPTY_FILE_HASH = "0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6"
const HASH_FUNCTION = "0x12"
const HASH_SIZE = "0x20"

module.exports = async (deployer, network, accounts) => {
  if (network !== "dev" && network !== "develop" && network !== "rinkeby" && network !== "rinkeby-fork" && network !== "ganache")
    return;

  const from = accounts[0]
  console.log("Current account", from)

  /**
   *  Linking libraries.
   */
  await Organigram.link(CoreLibrary)
  await Organigram.link(OrganLibrary)
  await Organ.link(CoreLibrary)
  await Organ.link(OrganLibrary)
  await NominationProcedure.link(CoreLibrary)
  await NominationProcedure.link(ProcedureLibrary)
  await VoteProcedure.link(CoreLibrary)
  await VoteProcedure.link(ProcedureLibrary)

  /**
   *  Configure Organigram contract.
   */
  const organigram = await deployer.deploy(
    Organigram,
    { // Metadata of procedures registry.
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    { from }
  )
  console.log("Organigram contract", organigram.address)
  // organ is an empty, locked factory master organ.
  const organ = await organigram.organ()
  console.log("Master organ", organ)
  // procedures is an organ, the procedures registry.
  const procedures = await organigram.procedures()
  console.log("Procedures registry", procedures)
  const proceduresRegistry = await Organ.at(procedures)

  /**
   *  Deploy procedures as empty, locked factory master contracts.
   */
  const nomination = await deployer.deploy(NominationProcedure, { from })
  console.log("Master Nomination", nomination.address)

  const vote = await deployer.deploy(VoteProcedure, { from })
  console.log("Master Vote", vote.address)

  /**
   *  Registering procedures in registry.
   */
  let entries = [
    {
      addr: nomination.address,
      doc: {
        ipfsHash: EMPTY_FILE_HASH,
        hashFunction: HASH_FUNCTION,
        hashSize: HASH_SIZE
      }
    },
    {
      addr: vote.address,
      doc: {
        ipfsHash: EMPTY_FILE_HASH,
        hashFunction: HASH_FUNCTION,
        hashSize: HASH_SIZE
      }
    },
  ]
  // Check if entries' addresses already exist.
  entries = (await Promise.all(
    entries.map(entry =>
      proceduresRegistry.getEntryIndexForAddress(entry.addr)
      .catch(error => {
        console.warn(error.message)
        return "0"
      })
      .then(index => ({ ...entry, inRegistry: parseInt(index.toString()) > 0 }))
    )
  )).filter(e => !e.inRegistry)
  if (entries.length > 0) {
    console.log("Adding procedures in registry:", entries)
    await proceduresRegistry.addEntries(entries, { from })
    .catch(error => console.error(error.message))
    console.log("Entries in registry:", (await proceduresRegistry.getOrgan()).entriesCount.toString())
  }
  console.log("Added all procedures to registry.")
}