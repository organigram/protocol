var CID = require("cids")
var Organigram = artifacts.require("Organigram")
var Organ = artifacts.require("Organ")
var NominationProcedure = artifacts.require("NominationProcedure")
var VoteProcedure = artifacts.require("VoteProcedure")

// Multihash for CID QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH (empty file)
const EMPTY_FILE_HASH = "0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6"
const HASH_FUNCTION = "0x12"
const HASH_SIZE = "0x20"

module.exports = async (deployer, network, accounts) => {
  if (network !== "development" && network !== "develop" && network !== "rinkeby" && network !== "rinkeby-fork" && network !== "pichain")
    return;

  const EMPTY_CID = multihashToCid({
    ipfsHash: EMPTY_FILE_HASH,
    hashFunction: parseInt(HASH_FUNCTION, 16),
    hashSize: parseInt(HASH_SIZE, 16)
  })

  const from = accounts[0]
  console.log("Current account", from)
  accounts.forEach((acc, index) => index > 1 && console.log("Account accessible", acc))

  const organigram = await Organigram.deployed()
  const masterOrgan = await organigram.organ()
  const masterProcedures = await organigram.procedures()
  console.log("Organigram", organigram.address)
  console.log("Master Organ", masterOrgan)
  console.log("Master Procedures", masterProcedures)
  const procedures = await Organ.at(masterProcedures)
  const vote = await VoteProcedure.deployed()
  const nomination = await NominationProcedure.deployed()

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
  const nominateAdmins = await NominationProcedure.at(_nominateAdmins.procedure)
  await nominateAdmins.initialize(
    { // Metadata.
      ipfsHash: EMPTY_FILE_HASH,
      hashFunction: HASH_FUNCTION,
      hashSize: HASH_SIZE
    },
    admins.address, // Proposers
    admins.address, // Moderators
    admins.address, // Deciders
    true,           // With moderation
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
  const updateSystem = await NominationProcedure.at(_updateSystem)
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

  const adminsData = await admins.getOrgan()
  console.log("\n-- Admins entries --")
  for (var i = 1 ; String(i) !== adminsData.entriesLength.toString() ; ++i) {
    console.log(`Entry ${i}`, "->", (await admins.getEntry(String(i))).addr)
  }
  console.log("\n-- Admins procedures --")
  for (var i = 0 ; String(i) !== adminsData.proceduresLength.toString() ; ++i) {
    console.log(`Procedure ${i}`, "->", (await admins.getProcedure(String(i)).then(p => [p.addr, p.perms])))
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
  console.log(await nominateAdmins.getProposal(nominateAdminsProposal).then(({
    creator, metadata, blockReason, presented, blocked, adopted, applied, operations
  }) => ({
    creator,
    metadata: { ipfsHash: metadata.ipfsHash, hashFunction: metadata.hashFunction, hashSize: metadata.hashSize },
    blockReason: { ipfsHash: blockReason.ipfsHash, hashFunction: blockReason.hashFunction, hashSize: blockReason.hashSize },
    presented, blocked, adopted, applied,
    operations: operations.map(({ organ, data, value }) => ({ organ, data, value }))
  })))
  // Moderation: A moderator must present the proposal.
  await nominateAdmins.presentProposal(nominateAdminsProposal, { from })
  console.log(`nominateAdmins.presentProposal(nominateAdminsProposal)`)
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
  console.log(await voteNorms.getProposal(voteNormsProposal).then(({
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
  const ballot = await voteNorms.getBallot(voteNormsProposal)
  console.log("Ballot start", ballot.start.toString())
  console.log("Vote duration", (await voteNorms.voteDuration()).toString())

  const waitBlock = async (height) => {
    console.log("Waiting for block", height.toString())
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error("Timeout")), 60000)
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
      "organ": await admins.getOrgan().then(data => ({
        metadata: multihashToCid(data.metadata).uri,
        proceduresLength: data.proceduresLength.toString(),
        entriesLength: data.entriesLength.toString(),
        entriesCount: data.entriesCount.toString(),
      })),
    },
    "norms": {
      "address": norms.address,
      "procedures": await getProcedures(norms),
      "entries": await getEntries(norms),
      "organ": await norms.getOrgan().then(data => ({
        metadata: multihashToCid(data.metadata).uri,
        proceduresLength: data.proceduresLength.toString(),
        entriesLength: data.entriesLength.toString(),
        entriesCount: data.entriesCount.toString(),
      })),
    },
    "nominateAdmins": {
      "address": nominateAdmins.address,
      "procedure": await nominateAdmins.getProcedure().then(
        ({ metadata, proposers, moderators, deciders, proposalsLength }) =>
          ({
            metadata: multihashToCid(metadata).uri,
            proposers, moderators, deciders,
            proposalsLength: proposalsLength.toString()
          })
      )
    },
    "voteNorms": {
      "address": voteNorms.address,
      "procedure": await voteNorms.getProcedure().then(
        ({ metadata, proposers, moderators, deciders, proposalsLength }) =>
        ({
          metadata: multihashToCid(metadata).uri,
          proposers, moderators, deciders,
          proposalsLength: proposalsLength.toString()
        })
      )
    },
    "updateSystem": {
      "address": updateSystem.address,
      "procedure": await updateSystem.getProcedure().then(
        ({ metadata, proposers, moderators, deciders, proposalsLength }) =>
        ({
          metadata: multihashToCid(metadata).uri,
          proposers, moderators, deciders,
          proposalsLength: proposalsLength.toString()
        })
      )
    }
  })
}

const getProcedures = async organ => {
  const length = (await organ.getOrgan()).proceduresLength.toString()
  if (length === "0")
    return {}

  var i = 0
  var proceduresPromises = []
  for (i ; String(i) != length ; i++) {
    const index = `${i}`
    proceduresPromises.push(
      organ.getProcedure(index)
      .catch(e => console.log("Error", e.message))
      .then(async result => ({
        addr: result.addr,
        perms: result.perms.toString()
      }))
      .catch(e => console.error("Error", e.message))
    )
  }
  const _procedures = await Promise.all(proceduresPromises)
  var procedures = {}
  console.log(`getProcedures(${organ.address}):`)
  _procedures.filter(p => !!p).forEach(({ addr, perms }) => {
    procedures[addr] = perms
    console.log(`- ${addr} -> ${perms}`)
  })
  return procedures
}

const getEntries = async organ => {
  const length = (await organ.getOrgan()).entriesLength.toString()
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
    entries.map((entry, i) => {
      const doc = multihashToCid(entry.doc)
      return `- ${entry.index} -> ${entry.addr}${doc.cid ? `\n${doc.cid}` : ""}`
    })
  )
}

function multihashToCid(result) {
  const { ipfsHash, hashFunction, hashSize } = result
  const multihash = `${hashFunction.toString(16).padStart(2, "0")}${hashSize.toString(16).padStart(2, "0")}${ipfsHash.substring(2)}`
  try {
    const cid = new CID(1, hashFunction, Buffer.from(`${multihash}`))
    return {
      cid: cid.toV0(), ipfsio: `https://ipfs.io/ipfs/${cid}`, uri: `ipfs://${cid}`
    }
  }
  catch (error) {
    return { cid: "", ipfsio: "", uri: "" }
  }
}