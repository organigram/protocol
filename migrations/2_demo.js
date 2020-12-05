var ipfsClient = require("ipfs-http-client")
var CID = require("cids")
var OrganLibrary = artifacts.require("OrganLibrary")
var ProcedureLibrary = artifacts.require("ProcedureLibrary")
var VotePropositionLibrary = artifacts.require("VotePropositionLibrary")
var Organ = artifacts.require("Organ")
var SimpleNominationProcedure = artifacts.require("SimpleNominationProcedure")
var VoteProcedure = artifacts.require("VoteProcedure")

const EMPTY_FILE_HASH = "0xbfccda787baba32b59c78450ac3d20b633360b43992c77289f9ed46d843561e6"
const HASH_FUNCTION = "0x12"
const HASH_SIZE = "0x20"

module.exports = async (deployer, network, accounts) => {
  if (network !== "development" && network !== "develop")
    return;

  const from = accounts[0]
  console.log("Current account", from)

  // Connect to IPFS Daemon API Server running locally.
  ipfs = await ipfsClient('http://localhost:5002')
  if (!ipfs)
    throw new Error("Run `yarn ipfs` to start an IPFS node locally.")

  await Organ.link(OrganLibrary)
  await SimpleNominationProcedure.link(ProcedureLibrary)
  await VoteProcedure.link(ProcedureLibrary)
  await VoteProcedure.link(VotePropositionLibrary)

  // Deploying organs and procedures.
  const admins = await Organ.new(from, EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE, { from })
  console.log(`* admins: ${admins.address}`)
  const norms = await Organ.new(from, EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE, { from })
  console.log(`* norms: ${norms.address}`)
  const nominateAdmins = await SimpleNominationProcedure.new(EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE, admins.address)
  console.log(`- nominateAdmins: ${nominateAdmins.address}`)
  const voteNorms = await VoteProcedure.new(
    EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE,   // Metadata.
    admins.address,         // Voters.
    admins.address,         // Vetoers.
    admins.address          // Enactors.
  )
  console.log(`- voteNorms: ${voteNorms.address}`)
  const updateSystem = await SimpleNominationProcedure.new(EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE, admins.address)
  console.log(`- updateSystem: ${updateSystem.address}`)

  // Configuring procedures on organs.
  // 0xC0 = 11000000 = can add and remove procedures.
  // 0x0C = 00001100 = can add and remove entries.
  await admins.addEntries([
    { addr: from, ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[1], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[2], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[3], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[4], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[5], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[6], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[7], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[8], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE },
    { addr: accounts[9], ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE }
  ])
  .then(data => console.log(`admins.addEntries([ OrganLibrary.Entry(from, EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE) ])`))
  await admins.addProcedure(nominateAdmins.address, "0xffff")
  .then(data => console.log(`admins.addProcedure(nominateAdmins.address, "0xffff")`))
  await admins.replaceProcedure(from, updateSystem.address, "0xffff")
  .then(data => console.log(`admins.replaceProcedure(from, updateSystem.address, "0xffff")`))
  await norms.addProcedure(voteNorms.address, "0xffff")
  .then(data => console.log(`norms.addProcedure(voteNorms.address, "0xffff")`))
  await norms.replaceProcedure(from, updateSystem.address, "0xffff")
  .then(data => console.log(`norms.replaceProcedure(from, updateSystem.address, "0xffff")`))

  // DEBUG.
  await nominateAdmins.createMove(EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE)
  .then(() => console.log(`nominateAdmins.createMove(EMPTY_FILE_HASH, HASH_FUNCTION, HASH_SIZE)`))
  await nominateAdmins.moveAddProcedure("0", admins.address, from, "0xffff", false)
  .then(() => console.log(`nominateAdmins.moveAddProcedure(moveKey, admins.address, from, 0xffff, false)`))
  await nominateAdmins.moveAddEntries("0", admins.address, [
    { addr: from, ipfsHash: EMPTY_FILE_HASH, hashFunction: HASH_FUNCTION, hashSize: HASH_SIZE }
  ], true)
  .then(() => console.log(`nominateAdmins.moveAddEntries("0", admins.address, [{ addr: from, ... }], true)`))
  await nominateAdmins.nominate("0", { from: accounts[1] })
  .then(() => console.log(`nominateAdmins.nominate("0", { from: accounts[1] })`))

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
      "nominatersOrgan": await nominateAdmins.nominatersOrgan()
    },
    "voteNorms": {
      "address": voteNorms.address,
      "votersOrgan": await voteNorms.votersOrgan(),
      "vetoersOrgan": await voteNorms.vetoersOrgan(),
      "enactorsOrgan": await voteNorms.enactorsOrgan()
    },
    "updateSystem": {
      "address": updateSystem.address,
      "nominatersOrgan": await updateSystem.nominatersOrgan()
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
    promises.push(
      organ.getEntry(i)
      .catch(e => console.error("Error", e.message))
    )
  }
  console.log(`getEntries(${organ.address})`)
  return Promise.all(promises)
  .then(entries =>
    entries.map((entry, i) => `- ${i} -> ${entry.addr}${entry.ipfsHash !== "0x0000000000000000000000000000000000000000000000000000000000000000" ? "\n" + entry.ipfsHash : ""}`)
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