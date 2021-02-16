var CID = require("cids")
var Organigram = artifacts.require("Organigram")
var Organ = artifacts.require("Organ")
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
  if (accounts.length === 1) {
    accounts = [
      from,
      "0xc3a7897616Ae683089C737076e2751ADC9ecE481",
      "0x6a0e35c6d4eCC16f821d198Dc7EeE3cEC1c45b75",
      "0xD3039751280B3a4bFd80d0bBD8C033A5E350AC00",
      "0xBa1e14454b7A17409B72a2314C8e2dde4537e84B",
      "0x386e805DD81Bb8b5Ad87a93C449687970389B921",
      "0x90B4C72567A1875cd83307C9FF874Ad7dc30A8BB",
      "0x0Af900493B6152AC30224b42A487543C45E5b699",
      "0x653292056173817feE247fce89A7164fB9275B46",
      "0xC93eE1256E568564007421a6A2f46eB0e8764843"
    ]
  }
  const organigram = await Organigram.deployed()
  const masterOrgan = await organigram.organ()
  const masterProcedures = await organigram.procedures()
  console.log("Organigram", organigram.address)
  console.log("Master Organ", masterOrgan)
  console.log("Master Procedures", masterProcedures)
  const procedures = await Organ.at(masterProcedures)
  const vote = await VoteProcedure.deployed()
  const nomination = await SimpleNominationProcedure.deployed()

  console.log("Index of Nomination", (await procedures.getEntryIndexForAddress(nomination.address)).toString())
  console.log("Index of Vote", (await procedures.getEntryIndexForAddress(vote.address)).toString())

  const admins = await Organ.at((await organigram.createOrgan(
    from,
    {
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    { from }
  )).logs[0].args.organ)
  console.log(`* admins:`, admins.address)

  const norms = await Organ.at((await organigram.createOrgan(
    from,
    {
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    { from }
  )).logs[0].args.organ)
  console.log(`* norms:`, norms.address)

  const _nominateAdmins = (await organigram.createProcedure(nomination.address, {from})).logs[0].args
  const nominateAdmins = await SimpleNominationProcedure.at(_nominateAdmins.procedure)
  await nominateAdmins.initialize(
    { // Metadata.
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    admins.address, // Proposers
    admins.address, // Moderators
    admins.address, // Deciders
    false,          // No moderation
    { from }
  )
  console.log(`- nominateAdmins: ${nominateAdmins.address}`)

  const _voteNorms = (await organigram.createProcedure(vote.address, {from})).logs[0].args.procedure
  const voteNorms = await VoteProcedure.at(_voteNorms)
  // Initialize function is overloaded in VoteProcedure.
  await voteNorms.methods['initialize((bytes32,uint8,uint8),address,address,address,bool,uint32,uint32,uint32)'](
    {
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    admins.address, // Proposers
    admins.address, // Moderators
    admins.address, // Deciders
    false,          // No moderation
    "1",            // Quorum size
    "8",            // Vote duration
    "1",            // Majority size
    { from }
  )
  console.log(`- voteNorms: ${voteNorms.address}`)

  const _updateSystem = (await organigram.createProcedure(nomination.address, {from})).logs[0].args.procedure
  const updateSystem = await SimpleNominationProcedure.at(_updateSystem)
  await updateSystem.initialize(
    { // Metadata.
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    admins.address, // Proposers
    admins.address, // Moderators
    admins.address, // Deciders
    false,          // No moderation
    { from }
  )
  console.log(`- updateSystem: ${updateSystem.address}`)

  // Configuring procedures on organs.
  // 0xC0 = 11000000 = can add and remove procedures.
  // 0x0C = 00001100 = can add and remove entries.
  await admins.addEntries([
    {
      addr: from,
      doc: { ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE }
    }
  ], { from })
  console.log(`admins.addEntries([ OrganLibrary.Entry(from, EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE) ])`)
  await admins.addProcedure(nominateAdmins.address, "0xffff", { from })
  console.log(`admins.addProcedure(nominateAdmins.address, "0xffff")`)
  await admins.replaceProcedure(from, updateSystem.address, "0xffff", { from })
  console.log(`admins.replaceProcedure(from, updateSystem.address, "0xffff")`)
  await norms.addProcedure(voteNorms.address, "0xffff", { from })
  console.log(`norms.addProcedure(voteNorms.address, "0xffff")`)
  await norms.replaceProcedure(from, updateSystem.address, "0xffff", { from })
  console.log(`norms.replaceProcedure(from, updateSystem.address, "0xffff")`)

  console.log("\n-- Admins entries --")
  for (var i = 1 ; String(i) !== (await admins.getEntriesLength()).toString() ; ++i) {
    console.log(`Entry ${i}`, "->", (await admins.getEntry(String(i))).addr)
  }
  console.log("\n-- Admins procedures --")
  for (var i = 0 ; String(i) !== (await admins.getProceduresLength()).toString() ; ++i) {
    console.log(`Procedure ${i}`, "->", (await admins.getProcedure(String(i)).then(p => [p.procedure, p.permissions])))
  }

  console.log("\nProcedure Nomination")
  const nominateAdminsProposal = (await nominateAdmins.propose(
    { // Metadata proposal
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    [ // Operations
      { // Operation 1 : addProcedure to organ.
        "index": "0",
        "organ": admins.address,
        "data":  (await admins.addProcedure.request(from, "0xffff", {value:0})).data,
        "value": "0",
        "processed": false
      }
    ],
    { from }
  )).logs[0].args.proposalKey.toString()
  console.log(`nominateAdmins.propose(metadata, operations)`, "->", nominateAdminsProposal)
  console.log(await nominateAdmins.proposal(nominateAdminsProposal).then(({
    creator, metadata, blockReason, presented, blocked, adopted, applied, operations
  }) => ({
    creator,
    metadata: { ipfsHash: metadata.ipfsHash, hashFunction: metadata.hashFunction, hashSize: metadata.hashSize },
    blockReason: { ipfsHash: blockReason.ipfsHash, hashFunction: blockReason.hashFunction, hashSize: blockReason.hashSize },
    presented, blocked, adopted, applied,
    operations: operations.map(({ organ, data, value }) => ({ organ, data, value }))
  })))
  await nominateAdmins.nominate(nominateAdminsProposal, { from })
  console.log(`nominateAdmins.nominate(nominateAdminsProposal)`)

  console.log("\nProcedure Vote")
  const voteNormsProposal = (await voteNorms.propose(
    { // Metadata proposal
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    [ // Operations
      { // Operation 1 : addEntries.
        "index": "0",
        "organ": norms.address,
        "data":  (await norms.addEntries.request([
          { // Put my address in entries.
            addr: from,
            doc: { ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE }
          }
        ], {value:0})).data,
        "value": "0",
        "processed": false
      }
    ],
    { from }
  )).logs[0].args.proposalKey.toString()
  console.log(`voteNorms.propose(metadata, operations)`, "->", voteNormsProposal)
  console.log(await voteNorms.proposal(voteNormsProposal).then(({
    creator, metadata, blockReason, presented, blocked, adopted, applied, operations
  }) => ({
    creator,
    metadata: { ipfsHash: metadata.ipfsHash, hashFunction: metadata.hashFunction, hashSize: metadata.hashSize },
    blockReason: { ipfsHash: blockReason.ipfsHash, hashFunction: blockReason.hashFunction, hashSize: blockReason.hashSize },
    presented, blocked, adopted, applied,
    operations: operations.map(({ organ, data, value }) => ({ organ, data, value }))
  })))
  await voteNorms.vote(voteNormsProposal, true, { from })
  console.log(`voteNorms.vote(voteNormsProposal, true)`)
  const ballot = await voteNorms.ballot(voteNormsProposal)
  console.log("Ballot start", ballot.start.toString())
  console.log("Vote duration", (await voteNorms.voteDuration()).toString())

  const waitBlock = async (height) => {
    console.log("Waiting for block", height.toString())
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timeout")), 30000)
      const checkBlock = async (height) => {
        const block = await web3.eth.getBlockNumber()
        console.log("Current block number", block.toString())
        if (height.toString() === block.toString()) {
          clearTimeout(timeout)
          return resolve(true)
        } else {
          await voteNorms.vote(voteNormsProposal, true, { from: accounts[i++] }).catch(() => {})
          setTimeout(() => checkBlock(height), 2000)
        }
      }
      checkBlock(height)
    })
  }
  await waitBlock(ballot.start.add(await voteNorms.voteDuration()))

  const voteNormsCount = await voteNorms.count(voteNormsProposal, { from })
  .catch(error => console.log(error.message))
  console.log(`voteNorms.count(voteNormsProposal)`, voteNormsCount)
  await voteNorms.adoptProposal(voteNormsProposal, { from })
  console.log(`voteNorms.adoptProposal(voteNormsProposal)`)

  // Logs.
  console.log("\n\nDemo deployed.\n\n")
  console.log({
    "admins": {
      "address": admins.address,
      "procedures": await getProcedures(admins),
      "entries": await getEntries(admins),
      "metadata": await admins.getMetadata().then(result => multihashToCid(result).ipfsio),
    },
    "norms": {
      "address": norms.address,
      "procedures": await getProcedures(norms),
      "entries": await getEntries(norms),
      "organData": await norms.getMetadata().then(result => multihashToCid(result).ipfsio),
    },
    "nominateAdmins": {
      "address": nominateAdmins.address,
      "procedure": await nominateAdmins.procedure().then(({ proposers, moderators, deciders }) => ({ proposers, moderators, deciders }))
    },
    "voteNorms": {
      "address": voteNorms.address,
      "procedure": await voteNorms.procedure().then(({ proposers, moderators, deciders }) => ({ proposers, moderators, deciders }))
    },
    "updateSystem": {
      "address": updateSystem.address,
      "procedure": await updateSystem.procedure().then(({ proposers, moderators, deciders }) => ({ proposers, moderators, deciders }))
    }
  })
}

const getProcedures = async organ => {
  const length = (await organ.getProceduresLength()).toString()
  if (length === "0")
    return {}

  var i = 0
  var proceduresPromises = []
  for (i ; String(i) != length ; i++) {
    proceduresPromises.push(
      organ.getProcedure(i)
      .catch(e => console.log("Error", e.message))
      .then(async result => {
        return {
          procedure: result.procedure,
          permissions: result.permissions.toString()
        }
      })
      .catch(e => console.error("Error", e.message))
    )
  }
  const _procedures = await Promise.all(proceduresPromises)
  var procedures = {}
  console.log(`getProcedures(${organ.address}):`)
  _procedures.filter(p => !!p).forEach(({ procedure, permissions }) => {
    procedures[procedure] = permissions
    console.log(`- ${procedure} -> ${permissions}`)
  })
  return procedures
}

const getEntries = async organ => {
  const length = (await organ.getEntriesLength()).toString()
  if (length === "0")
    return []

  var i = 1
  var promises = []
  for (i ; String(i) != length ; i++) {
    const index = `${i}`
    promises.push(
      organ.getEntry(index)
      .then(e => ({ ...e, index }))
      .catch(e => console.error("Error", e.message))
    )
  }
  console.log(`getEntries(${organ.address})`)
  return Promise.all(promises)
  .then(entries =>
    entries.map((entry, i) => `- ${entry.index} -> ${entry.addr}${entry.ipfsHash !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? "\n" + entry.ipfsHash : ""}`)
  )
}

function multihashToCid(result) {
  const { ipfsHash, hashFunction, hashSize } = result
  const multihash = `${hashSize.toString('hex')}${hashFunction.toString('hex')}${ipfsHash}`
  // console.log("multihash\n" + multihash)
  const cid = ""// new CID(multihash.toString('hex'))
  return {
    cid, ipfsio: `https://ipfs.io/ipfs/${cid}`
  }
}