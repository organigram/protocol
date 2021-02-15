var CID = require("cids")
var MetadataLibrary = artifacts.require("MetadataLibrary")
var Organigram = artifacts.require("Organigram")
var OrganLibrary = artifacts.require("OrganLibrary")
var ProcedureLibrary = artifacts.require("ProcedureLibrary")
var VotePropositionLibrary = artifacts.require("VotePropositionLibrary")
var Organigram = artifacts.require("Organigram")
var SimpleNominationProcedure = artifacts.require("SimpleNominationProcedure")
var VoteProcedure = artifacts.require("VoteProcedure")

// Multihash for CID QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH (empty file)
const EMPTY_FILE_HASH = "0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6"
const HASH_FUNCTION = "0x12"
const HASH_SIZE = "0x20"

module.exports = async (deployer, network, accounts) => {
  if (network !== "development" && network !== "develop" && network !== "rinkeby" && network !== "rinkeby-fork")
    return;

  const from = accounts[0]
  console.log("Current account", from)

  /**
   *  Linking libraries.
   */
  await Organigram.link(MetadataLibrary)
  await Organigram.link(OrganLibrary)
  await Organigram.link(OrganLibrary)
  await SimpleNominationProcedure.link(ProcedureLibrary)
  await VoteProcedure.link(ProcedureLibrary)
  await VoteProcedure.link(VotePropositionLibrary)

  /**
   *  Configure Organigram contract.
   */
  const organigram = await deployer.deploy(
    Organigram,
    {
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

  /**
   *  Deploy procedures as empty, locked factory master contracts.
   */
  const nomination = await deployer.deploy(
    SimpleNominationProcedure,
    {
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    from,
    { from }
  )
  console.log("Master Nomination", nomination.address)

  const vote = await deployer.deploy(
    VoteProcedure,
    {
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    from,
    from,
    from,
    { from }
  )
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
    entries.map(entry => {
      const index = registry.getEntryIndexForAddress(entry.addr)
      return { ...entry, inRegistry: index > 0 }
    })
  )).filter(e => e.inRegistry)
  if (entries.length > 0) {
    console.log("Adding procedures in registry:", entries)
    await organigram.registerProcedures(entries)
  }
  console.log("Added all procedures to registry.")
}