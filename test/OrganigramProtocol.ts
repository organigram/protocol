import { assert } from 'chai'
import { viem } from 'hardhat'
import { parseEventLogs } from 'viem'

import { deployProtocol, type ProtocolContracts } from '../src/deploy'

describe('Organigram protocol', function () {
  let testValues: ProtocolContracts & {
    signers: Array<`0x${string}`>
    publicClient: any
  }

  it('Deploy protocol', async function () {
    const {
      coreLibrary,
      organLibrary,
      procedureLibrary,
      organ,
      nominationProcedure,
      voteProcedure,
      erc20VoteProcedure,
      organigramClient,
      proceduresRegistry
    } = await deployProtocol()

    testValues = {
      coreLibrary,
      organLibrary,
      procedureLibrary,
      organ,
      nominationProcedure,
      voteProcedure,
      erc20VoteProcedure,
      organigramClient,
      proceduresRegistry,
      signers: await Promise.all(
        (await viem.getWalletClients()).map(
          async signer => (await signer.getAddresses())[0]
        )
      ),
      publicClient: await viem.getPublicClient()
    }
  })

  it('Create an organ', async function () {
    const metadataCid = 'QmQzqLQ8V3J4b4m5yQ4yQzqL'

    const receipt = await testValues.publicClient.getTransactionReceipt({
      hash: await testValues.organigramClient.write.createOrgan([
        testValues.signers[0],
        metadataCid
      ])
    })
    const logs = parseEventLogs({
      logs: receipt.logs,
      abi: testValues.organigramClient.abi
    })

    const deployedOrgan = await viem.getContractAt(
      'Organ',
      (logs[0].args as { organ: `0x${string}` }).organ
    )
    const [cid] = (await deployedOrgan.read.getOrgan()) as [string]
    const [admin, permission] = (await deployedOrgan.read.getProcedure([
      0
    ])) as [string, string]

    assert.equal(logs[0].eventName, 'organCreated')
    assert.equal(cid, metadataCid)
    assert.equal(admin, testValues.signers[0])
    assert.equal(Number(permission), 65535)
  })

  it('Create a nomination procedure', async function () {
    const proceduresRegistryAddress =
      await testValues.organigramClient.read.procedures()
    const proceduresRegistry = await viem.getContractAt(
      'Organ',
      proceduresRegistryAddress as `0x${string}`
    )
    const { addr: nominationAddress } = (await proceduresRegistry.read.getEntry(
      ['1']
    )) as { addr: string }

    const receipt = await testValues.publicClient.getTransactionReceipt({
      hash: await testValues.organigramClient.write.createProcedure([
        nominationAddress,
        '0x'
      ])
    })
    const logs = parseEventLogs({
      logs: receipt.logs,
      abi: testValues.organigramClient.abi
    })
    assert.equal(logs[0].eventName, 'procedureCreated')
  })
})
