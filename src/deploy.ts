import { viem, network, ignition } from 'hardhat'
import { GetContractReturnType } from '@nomicfoundation/hardhat-viem/types'

import Asset from '../ignition/modules/Asset'
import CoreLibrary from '../ignition/modules/CoreLibrary'
import OrganLibrary from '../ignition/modules/OrganLibrary'
import ProcedureLibrary from '../ignition/modules/ProcedureLibrary'
import Organ from '../ignition/modules/Organ'
import Procedures from '../ignition/modules/Procedures'
import OrganigramClient from '../ignition/modules/OrganigramClient'
import MetaGasStation from '../ignition/modules/MetaGasStation'

export type ProtocolContracts = {
  asset: GetContractReturnType
  coreLibrary: GetContractReturnType
  organLibrary: GetContractReturnType
  procedureLibrary: GetContractReturnType
  organ: GetContractReturnType
  nominationProcedure: GetContractReturnType
  voteProcedure: GetContractReturnType
  erc20VoteProcedure: GetContractReturnType
  organigramClient: GetContractReturnType
  proceduresRegistry: GetContractReturnType
}

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

export const deployAndLoadContract = async (module: any, parameters?: any) => {
  const contractAddresses = await ignition.deploy(module, parameters)
  return Object.fromEntries(
    await Promise.all(
      Object.entries(contractAddresses).map(async ([name, { address }]) => {
        const label = capitalize(name).replace('Erc', 'ERC')
        console.info(`${label} deployed at: ${address}`)
        const contract = await viem.getContractAt(label, address)
        return [name, contract]
      })
    )
  )
}

export const deployProtocol = async (): Promise<ProtocolContracts> => {
  console.info('Network:', network.name)

  /*
   * Deploying libraries
   */
  const coreLibrary = await deployAndLoadContract(CoreLibrary)
  const organLibrary = await deployAndLoadContract(OrganLibrary)
  const procedureLibrary = await deployAndLoadContract(ProcedureLibrary)

  /*
   * Deploying the main protocol contracts
   */
  const asset = await deployAndLoadContract(Asset)
  const organ = await deployAndLoadContract(Organ)
  const { nominationProcedure, voteProcedure, erc20VoteProcedure } =
    await deployAndLoadContract(Procedures)

  /*
   * Deploying the MetaGasStation forwarder & ERC2771Recipient
   */
  const { metaGasStation } = await deployAndLoadContract(MetaGasStation)

  /*
   * Deploying the Organigram client
   */
  const { organigramClient } = await deployAndLoadContract(OrganigramClient, {
    parameters: {
      OrganigramClientModule: {
        metaGasStationAddress: metaGasStation.address,
        cloneableOrgan: organ.address
      }
    }
  })

  /*
   * Adding procedures to the procedures registry
   */
  const signers = await viem.getWalletClients()
  const proceduresRegistryAddress =
    await organigramClient.read.proceduresRegistry()
  const proceduresRegistry = await viem.getContractAt(
    'Organ',
    proceduresRegistryAddress as `0x${string}`
  )
  console.info(`Procedures registry deployed at: ${proceduresRegistryAddress}`)

  const cloneableOrganAddress = await organigramClient.read.organ()
  const cloneableAssetAddress = await organigramClient.read.asset()

  console.info(`Cloneable Organ deployed at: ${cloneableOrganAddress}`)
  console.info(`Cloneable Asset deployed at: ${cloneableAssetAddress}`)

  let entries: Array<{ addr: string; cid: string; inRegistry?: boolean }> = [
    {
      addr: nominationProcedure.address,
      cid: 'nomination',
      inRegistry: false
    },
    {
      addr: voteProcedure.address,
      cid: 'vote'
    },
    {
      addr: erc20VoteProcedure.address,
      cid: 'erc20Vote'
    }
  ]
  entries = (
    await Promise.all(
      entries.map(entry =>
        proceduresRegistry.read
          .getEntryIndexForAddress([entry.addr])
          .catch(error => {
            console.warn(error.message)
            return '0'
          })
          .then(index => ({
            ...entry,
            inRegistry: parseInt((index as string).toString()) > 0
          }))
      )
    )
  ).filter(e => !e.inRegistry)

  if (entries.length > 0) {
    await proceduresRegistry.write
      .addEntries([entries], { from: (await signers[0].getAddresses())[0] })
      .catch(error => console.error(error.message))
    const organData = (await proceduresRegistry.read.getOrgan()) as [
      string,
      BigInt,
      BigInt,
      BigInt
    ]
    console.info(organData[3].toString(), 'procedures registered.')
  }

  console.info()
  console.info('Organigram Protocol deployed successfully! ✅🚀')
  console.info()

  return {
    asset,
    coreLibrary,
    organLibrary,
    procedureLibrary,
    organ,
    nominationProcedure,
    voteProcedure,
    erc20VoteProcedure,
    organigramClient,
    proceduresRegistry
  }
}
