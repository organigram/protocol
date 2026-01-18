import { GetContractReturnType } from '@nomicfoundation/hardhat-viem/types'
import { viem, network, ignition } from 'hardhat'

import CoreLibrary from '../ignition/modules/CoreLibrary'
import OrganLibrary from '../ignition/modules/OrganLibrary'
import ProcedureLibrary from '../ignition/modules/ProcedureLibrary'
import Organ from '../ignition/modules/Organ'
import Procedures from '../ignition/modules/Procedures'
import Organigram from '../ignition/modules/Organigram'

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

export type ManagerContracts = {
  coreLibrary: GetContractReturnType
  organLibrary: GetContractReturnType
  procedureLibrary: GetContractReturnType
  organ: GetContractReturnType
  nominationProcedure: GetContractReturnType
  voteProcedure: GetContractReturnType
  erc20VoteProcedure: GetContractReturnType
  organigram: GetContractReturnType
  proceduresRegistry: GetContractReturnType
}

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

export const deployManager = async (): Promise<ManagerContracts> => {
  console.info('Network:', network.name)

  const coreLibrary = await deployAndLoadContract(CoreLibrary)
  const organLibrary = await deployAndLoadContract(OrganLibrary)
  const procedureLibrary = await deployAndLoadContract(ProcedureLibrary)

  /*
   * Deploying the master Organ
   */
  const organ = await deployAndLoadContract(Organ)

  /*
   * Deploying the procedures
   */
  const { nominationProcedure, voteProcedure, erc20VoteProcedure } =
    await deployAndLoadContract(Procedures)

  /*
   * Deploying the Organigram DAO
   */
  const { organigram } = await deployAndLoadContract(Organigram, {
    parameters: {
      Organigram: {
        nominationProcedureAddress: nominationProcedure.address,
        voteProcedureAddress: voteProcedure.address,
        erc20VoteProcedureAddress: erc20VoteProcedure.address
      }
    }
  })

  /*
   * Adding procedures to the procedures registry
   */
  // @ts-ignore (Property 'getSigners' does not exist on type 'ethers')
  const signers = await viem.getWalletClients()
  const proceduresRegistryAddress = await organigram.read.procedures()
  const proceduresRegistry = await viem.getContractAt(
    'Organ',
    proceduresRegistryAddress as `0x${string}`
  )
  console.info(`Procedures registry deployed at: ${proceduresRegistryAddress}`)

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

  // const artifacts = [
  //   { name: 'CoreLibrary', address: await coreLibrary.address },
  //   { name: 'OrganLibrary', address: await organLibrary.address },
  //   { name: 'ProcedureLibrary', address: await procedureLibrary.address },
  //   { name: 'Organ', address: await organ.address },
  //   { name: 'Procedures', address: await organ.address },
  //   { name: 'Organigram', address: await organigram.address }
  // ]
  // await tenderly.persistArtifacts(...artifacts)

  console.info()
  console.info('Organigram DAO deployed successfully! ✅🚀')
  console.info()

  return {
    coreLibrary,
    organLibrary,
    procedureLibrary,
    organ,
    nominationProcedure,
    voteProcedure,
    erc20VoteProcedure,
    organigram,
    proceduresRegistry
  }
}
